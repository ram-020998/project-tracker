package com.appian.research.lcpapis.handlers;

import java.io.ByteArrayInputStream;
import java.util.Map;

import javax.servlet.http.HttpServletResponse;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.w3c.dom.Document;
import org.w3c.dom.Node;

import com.appian.research.lcpapis.model.common.ObjectCategory;
import com.appian.research.lcpapis.routing.HttpRequest;
import com.appian.research.lcpapis.routing.HttpResponse;
import com.appian.research.lcpapis.routing.ServiceBundle;

import com.appiancorp.common.config.ApplicationContextHolder;
import com.appiancorp.ix.data.ContentHaul;
import com.appiancorp.ix.data.ProcessModelHaul;
import com.appiancorp.ix.data.RecordTypeHaul;
import com.appiancorp.ix.data.SiteHaul;
import com.appiancorp.ix.xml.HaulMarshaller;
import com.appiancorp.services.ServiceContextProvider;
import com.appiancorp.suiteapi.content.Content;
import com.appiancorp.suiteapi.content.ContentConstants;

/**
 * PROTOTYPE — POST /objects/from-export-xml
 *
 * <p>Converts a single object's IX export XML (one {@code [uuid].xml} entry from a normal
 * Appian export package) into the SAME plugin JSON a live read produces — entirely in memory,
 * with NO import. This gives you "the exported object in the same format as a live object", so
 * a diff is just plugin-JSON vs plugin-JSON from the one renderer.</p>
 *
 * <h2>Pipeline (all internal Appian/plugin functions)</h2>
 * <pre>
 *   IX XML  --HaulMarshaller + XmlContext-->  Haul
 *           --Haul domain getter-->           Content / RecordTypeDefinition / ProcessModel / Site
 *           --ObjectRenderer (the live GET's own renderer)--> plugin JSON
 * </pre>
 *
 * <p>Why this works: {@code ContentHaul.getIxObject()} returns the concrete content object
 * ({@code Interface}, {@code FreeformRule}, {@code Constant}, {@code Document}, … — all
 * {@code Content}); {@code RecordTypeHaul.getRecordType()} returns a {@code RecordTypeDefinition};
 * {@code ProcessModelHaul.getProcessModel()} returns a {@code ProcessModel}. Those are exactly the
 * domain objects the live handlers hand to {@link ObjectRenderer}. {@code HaulMarshaller} is
 * deliberately "broken out so ... other clients ... can use it" (its javadoc) over the shared
 * {@code XmlContext} that knows every Haul type.</p>
 *
 * <h2>Request / response</h2>
 * <pre>
 *   POST /objects/from-export-xml
 *   Content-Type: application/xml   (body = the object's [uuid].xml)
 *   200 → the plugin JSON for that object (same shape as GET /interfaces/{uuid}, etc.)
 * </pre>
 *
 * <h2>Expected differences from a live read (correct, and useful for a diff)</h2>
 * Server-assigned fields absent on an unimported object — numeric id, {@code versionId} — come
 * through null/empty. That is accurate: the object does not exist on this environment yet. For a
 * design-content diff that is exactly what you want to see.
 *
 * <h2>// VERIFY points</h2>
 * ServiceContextProvider acquisition, {@code categorizeContent} (mirror of
 * {@code ObjectResolver}'s private content-subtype switch), and the Haul root-element unmarshal.
 */
public final class ConvertExportHandler {

    private static final Logger LOG = LoggerFactory.getLogger(ConvertExportHandler.class);

    private ConvertExportHandler() {}

    public static HttpResponse fromExportXml(HttpRequest req, Map<String, String> pathParams,
            ServiceBundle svc) {
        String xml = req.getBody();
        if (xml == null || xml.trim().isEmpty()) {
            return HttpResponse.error(HttpServletResponse.SC_BAD_REQUEST,
                "Request body must be the object's IX export XML ([uuid].xml from an export package).");
        }

        final Object haul;
        try {
            haul = unmarshalHaul(xml);
        } catch (Exception e) {
            LOG.debug("Could not unmarshal IX XML: {}", e.getMessage());
            return HttpResponse.error(HttpServletResponse.SC_BAD_REQUEST,
                "Could not parse the IX XML into a Haul: " + e.getMessage());
        }

        try {
            // No server versionId for an unimported object; the renderer accepts null.
            final String versionId = null;
            String json;

            if (haul instanceof ContentHaul ch) {
                Object ix = ch.getIxObject();
                if (!(ix instanceof Content content)) {
                    return HttpResponse.error(HttpServletResponse.SC_UNPROCESSABLE_ENTITY,
                        "ContentHaul carried no Content object (ixObject was "
                        + (ix == null ? "null" : ix.getClass().getSimpleName()) + ").");
                }
                ObjectCategory category = categorizeContent(content); // VERIFY: mirror ObjectResolver
                json = ObjectRenderer.renderContent(category, content, versionId, svc);

            } else if (haul instanceof RecordTypeHaul rh) {
                json = ObjectRenderer.renderRecordType(rh.getRecordType(), versionId, svc);

            } else if (haul instanceof ProcessModelHaul ph) {
                json = ObjectRenderer.renderProcessModel(ph.getProcessModel(), versionId, svc);

            } else if (haul instanceof SiteHaul sh) {
                // SiteHaul's domain getter name may differ (getSite()); wire to renderSite.
                json = ObjectRenderer.renderSite(sh.getSite(), versionId); // VERIFY getter name

            } else {
                return HttpResponse.error(HttpServletResponse.SC_NOT_IMPLEMENTED,
                    "No converter wired for " + haul.getClass().getSimpleName()
                    + " yet. Content, record types, process models and sites are supported; "
                    + "add a branch that pulls this haul's domain object and calls its ObjectRenderer method.");
            }

            if (json == null) {
                return HttpResponse.error(HttpServletResponse.SC_UNPROCESSABLE_ENTITY,
                    "The renderer could not map this object.");
            }
            return HttpResponse.ok(json);

        } catch (Exception e) {
            LOG.error("Failed to render converted object", e);
            return HttpResponse.error(HttpServletResponse.SC_INTERNAL_SERVER_ERROR,
                "Could not render the converted object: " + e.getMessage());
        }
    }

    /**
     * IX XML → Haul, using the shared marshaller and JAXB context the real IX import uses.
     * The export entry's root element is the haul itself (ContentHaul etc. are @XmlRootElement),
     * so unmarshalling the root yields the typed Haul.
     */
    private static Object unmarshalHaul(String xml) throws Exception {
        ServiceContextProvider scProvider =
            ApplicationContextHolder.getBean(ServiceContextProvider.class); // VERIFY bean
        HaulMarshaller<?, ?, ?> marshaller = new HaulMarshaller<>(scProvider);

        DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
        dbf.setNamespaceAware(true);
        // Harden the parser (no external entities) — this XML is caller-supplied.
        dbf.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
        DocumentBuilder db = dbf.newDocumentBuilder();
        Document dom = db.parse(new ByteArrayInputStream(
            xml.getBytes(java.nio.charset.StandardCharsets.UTF_8)));
        Node root = dom.getDocumentElement();

        return marshaller.createUnmarshallerAndUnmarshall(root);
    }

    /**
     * Content subtype → ObjectCategory. Mirrors ObjectResolver's private categorizeContent:
     * SUBTYPE_RULE_CONSTANT → CONSTANT, SUBTYPE_RULE_FREEFORM → EXPRESSION_RULE,
     * SUBTYPE_RULE_INTERFACE → INTERFACE, document → DOCUMENT, folder → FOLDER, etc.
     * Prefer exposing/reusing the existing method over duplicating it. // VERIFY
     */
    private static ObjectCategory categorizeContent(Content content) {
        Integer subtype = content.getSubtype();
        if (subtype != null) {
            switch (subtype) {
                case ContentConstants.SUBTYPE_RULE_CONSTANT:  return ObjectCategory.CONSTANT;
                case ContentConstants.SUBTYPE_RULE_FREEFORM:  return ObjectCategory.EXPRESSION_RULE;
                case ContentConstants.SUBTYPE_RULE_INTERFACE: return ObjectCategory.INTERFACE;
                default: break;
            }
        }
        if (content instanceof com.appiancorp.suiteapi.content.Document) {
            return ObjectCategory.DOCUMENT;
        }
        // Folders and other content subtypes: extend as needed.
        return ObjectCategory.DOCUMENT;
    }
}
