package com.appian.research.lcpapis.handlers;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.util.Map;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

import javax.servlet.http.HttpServletResponse;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.appian.research.lcpapis.PluginFunctionUtils;
import com.appian.research.lcpapis.model.common.ResolvedObject;
import com.appian.research.lcpapis.model.enums.DesignObjectType;
import com.appian.research.lcpapis.routing.HttpRequest;
import com.appian.research.lcpapis.routing.HttpResponse;
import com.appian.research.lcpapis.routing.ServiceBundle;

import com.appiancorp.common.config.ApplicationContextHolder;
import com.appiancorp.ix.ExportFacade;
import com.appiancorp.ix.ExportResult;
import com.appiancorp.ix.LocalIdMap;
import com.appiancorp.ix.Type;
import com.appiancorp.security.auth.SecurityEscalator;
import com.appiancorp.suiteapi.content.ContentConstants;
import com.appiancorp.suiteapi.content.ContentService;
import com.appiancorp.suiteapi.content.Document;
import com.appiancorp.jsonrpc.JSONObject;

/**
 * PROTOTYPE — GET /objects/{uuid}/export-xml
 *
 * <p>Returns the IX (import/export) XML for a single LIVE design object — the SAME
 * representation Appian writes into an export package. This is the "live side" of a
 * diff whose "unimported side" is the {uuid}.xml already sitting inside an export .zip.
 * Putting both sides in IX-XML form is the robust way to diff an unimported object
 * against the environment, because it is exactly the representation Appian's own
 * conflict detection ({@code Haul.generateDiffHash} / {@code ConflictDetectionHaul})
 * operates on.</p>
 *
 * <h2>How it works</h2>
 * <ol>
 *   <li>Resolve the uuid to its object ({@link ObjectResolver}) → category + local id.</li>
 *   <li>Map the category to an ix {@link Type} via {@link PluginFunctionUtils#toIxType}.</li>
 *   <li>Build a one-entry {@link LocalIdMap} and run {@link ExportFacade#export} (admin-
 *       escalated, exactly as {@code DeploymentHandler} does for patch packages). This writes
 *       a zip {@link Document} into the IX system folder.</li>
 *   <li>Read the zip back, pull out the {@code [typeKey]/[uuid].xml} entry
 *       (see {@code XmlZipExportDriver}: "each object is stored with a file named
 *       [object's uuid].xml"), delete the temp docs, and return the XML.</li>
 * </ol>
 *
 * <h2>Response</h2>
 * <pre>
 *   GET /objects/{uuid}/export-xml                → {"uuid","objectType","ixType","xml"}
 *   GET /objects/{uuid}/export-xml?format=xml     → raw application/xml body
 * </pre>
 *
 * <h2>Known wiring points (marked // VERIFY)</h2>
 * The verified calls are {@code ObjectResolver.resolve}, {@code PluginFunctionUtils.toIxType},
 * {@code new LocalIdMap()} + {@code map.get(type).add(id)}, {@code ExportFacade.export(map, cs,
 * sc, folderId, name)} → {@code getZipDocument()}, and the document byte-read pattern
 * {@code cs.download(id, VERSION_CURRENT, false)[0].getInputStream().readAllBytes()}. The two
 * spots to confirm against your plugin build are the IX folder id source and the
 * {@code SecurityEscalator} bean name — both are used by {@code DeploymentHandler} and copied here.
 */
public final class ExportXmlHandler {

    private static final Logger LOG = LoggerFactory.getLogger(ExportXmlHandler.class);

    private ExportXmlHandler() {}

    public static HttpResponse getExportXml(HttpRequest req, Map<String, String> pathParams,
            ServiceBundle svc) {
        String uuid = pathParams.get("uuid");
        if (uuid == null || uuid.trim().isEmpty()) {
            return HttpResponse.error(HttpServletResponse.SC_BAD_REQUEST,
                "Required parameter 'uuid' is missing or empty");
        }
        uuid = uuid.trim();

        // 1. Resolve the uuid to its object (category + local id).
        ResolvedObject resolved;
        try {
            resolved = ObjectResolver.resolve(uuid, svc);
        } catch (Exception e) {
            LOG.debug("Could not resolve UUID {}: {}", uuid, e.getMessage());
            resolved = null;
        }
        if (resolved == null || resolved.category() == null) {
            return HttpResponse.error(HttpServletResponse.SC_NOT_FOUND,
                "Could not resolve object '" + uuid + "'. Pass the UUID of an existing design object.");
        }

        // 2. Map category → ix Type. (ObjectCategory and DesignObjectType share spellings, the
        //    same bridge ApplicationHandler.inferIxType uses.)
        final Type ixType;
        try {
            DesignObjectType dot = DesignObjectType.valueOf(resolved.category().name());
            ixType = PluginFunctionUtils.toIxType(dot);
        } catch (Exception e) {
            return HttpResponse.error(HttpServletResponse.SC_BAD_REQUEST,
                "Object '" + uuid + "' is a " + resolved.category().name()
                + ", which this route cannot export to IX XML yet.");
        }

        // Local id. Long for most kinds; a datatype's is a QName string — see // VERIFY note below.
        final Object localId = resolved.id();
        final String fUuid = uuid;

        // 3 + 4. Export (admin-escalated) and extract the object's XML.
        try {
            SecurityEscalator escalator = ApplicationContextHolder.getBean(SecurityEscalator.class); // VERIFY bean
            String xml = escalator.runAsAdminWithException(
                () -> exportSingleObjectXml(ixType, localId, fUuid, svc));
            if (xml == null) {
                return HttpResponse.error(HttpServletResponse.SC_INTERNAL_SERVER_ERROR,
                    "The export produced no " + fUuid + ".xml entry for object '" + fUuid + "'.");
            }
            if ("xml".equalsIgnoreCase(req.getQueryParam("format"))) {
                return new HttpResponse(HttpServletResponse.SC_OK, xml,
                    Map.of("Content-Type", "application/xml; charset=utf-8"));
            }
            JSONObject out = new JSONObject();
            out.put("uuid", fUuid);
            out.put("objectType", resolved.category().name());
            out.put("ixType", ixType.getKey());
            out.put("xml", xml);
            return HttpResponse.ok(out.toString());
        } catch (Exception e) {
            LOG.error("Failed to export IX XML for object {}", fUuid, e);
            return HttpResponse.error(HttpServletResponse.SC_INTERNAL_SERVER_ERROR,
                "Could not export IX XML for '" + fUuid + "': " + e.getMessage());
        }
    }

    /**
     * Runs a one-object IX export and returns the object's {@code [uuid].xml} contents.
     * Mirrors the ExportFacade usage in {@code ExportApplicationsAction} / {@code DeploymentHandler}.
     */
    private static String exportSingleObjectXml(Type ixType, Object localId, String uuid,
            ServiceBundle svc) throws Exception {
        ExportFacade exportFacade = ApplicationContextHolder.getBean(ExportFacade.class);
        ContentService cs = svc.contentService;

        // One-object LocalIdMap: map.get(type) is the Collection of local ids for that type.
        LocalIdMap localIdMap = new LocalIdMap();
        localIdMap.get(ixType).add(localId);

        // The IX system folder the export zip is written into. DeploymentHandler obtains this via
        // IxDocumentManager.getIxFolderId(); use the same source in your build. // VERIFY folder id
        long ixFolderId = ApplicationContextHolder.getBean(
            com.appiancorp.ix.IxDocumentManager.class).getIxFolderId();

        ExportResult result = exportFacade.export(
            localIdMap, cs, svc.serviceContext, ixFolderId, "lcp-export-" + uuid);

        Document zipDoc = result == null ? null : result.getZipDocument();
        if (zipDoc == null || zipDoc.getId() == null) {
            return null;
        }
        try {
            byte[] zipBytes;
            Document[] downloaded = cs.download(zipDoc.getId(), ContentConstants.VERSION_CURRENT, false);
            try (InputStream is = downloaded[0].getInputStream()) {
                zipBytes = is.readAllBytes();
            }
            // Entry is "[typeKey]/[uuid].xml" — match on the file name so we don't depend on the
            // exact type-folder label.
            return readZipEntryEndingWith(zipBytes, "/" + uuid + ".xml", uuid + ".xml");
        } finally {
            // Temp artifacts: the zip, the log, and the parameters file. Best-effort cleanup.
            safeDelete(cs, zipDoc.getId());
            if (result.getLogDocument() != null) {
                safeDelete(cs, result.getLogDocument().getId());
            }
            result.getParametersDocument().ifPresent(d -> safeDelete(cs, d.getId()));
        }
    }

    private static String readZipEntryEndingWith(byte[] zipBytes, String... suffixes) throws Exception {
        try (ZipInputStream zis = new ZipInputStream(new ByteArrayInputStream(zipBytes))) {
            ZipEntry entry;
            while ((entry = zis.getNextEntry()) != null) {
                String name = entry.getName();
                boolean match = false;
                for (String s : suffixes) {
                    if (name.endsWith(s)) { match = true; break; }
                }
                if (!match) { continue; }
                byte[] data = zis.readAllBytes();
                return new String(data, java.nio.charset.StandardCharsets.UTF_8);
            }
        }
        return null;
    }

    private static void safeDelete(ContentService cs, Long id) {
        if (id == null) { return; }
        try {
            cs.delete(id, false);
        } catch (Exception e) {
            LOG.warn("Could not delete temp export document {}: {}", id, e.getMessage());
        }
    }
}
