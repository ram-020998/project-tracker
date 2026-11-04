// ─────────────────────────────────────────────────────────────────────────────
// Route registration for the ExportXmlHandler prototype.
//
// Add this line inside RequestRouter's route-registration block, next to the other
// /objects/{uuid}/... routes (e.g. just after the lines):
//
//     get("/objects/{uuid}/security", SecurityHandler::getSecurity);
//     get("/objects/{uuid}/versions", VersionHistoryHandler::listVersions);
//
// Add:

        get("/objects/{uuid}/export-xml", ExportXmlHandler::getExportXml);

// ─────────────────────────────────────────────────────────────────────────────
// CONVERTER route (the one you actually want): IX export XML -> live plugin JSON.
// Takes a single object's [uuid].xml (from a normal Appian export package) in the
// request body and returns the SAME JSON a live read produces. No import.
//
// Add this line in the POST block (near the other /objects/... POSTs):

        post("/objects/from-export-xml", ConvertExportHandler::fromExportXml);

// And add the imports at the top of RequestRouter.java:
//
//     import com.appian.research.lcpapis.handlers.ExportXmlHandler;
//     import com.appian.research.lcpapis.handlers.ConvertExportHandler;
//
// (ExportXmlHandler lives in the same handlers package, so if RequestRouter already
//  wildcard/explicitly imports that package the import may be unnecessary.)
//
// Optional sibling route — a batch variant mirroring POST /objects/batch, returning
// IX XML for many uuids in one call (recommended once the single-object route works):
//
//     post("/objects/export-xml-batch", ExportXmlHandler::getExportXmlBatch);
//
//  A batch export is also cheaper: ExportFacade.export takes a LocalIdMap with many
//  entries, so one escalated export + one zip read yields every object's XML.
