# E1 + E2 Findings — SourceSelection Bulk Eval Generation

## BLOCKER: LCP Server Unavailable

**All LCP MCP calls return HTTP 307 (Temporary Redirect to login page).**
- `query_records` → 307
- `listrecorddata` → 307
- `list_users` → 307

**Root Cause:** The LCP environment credentials are expired or misconfigured for `merge-assist.appianpreview.com`.

**Impact:** Cannot query the live exemplar record (eval number `01072601`) or its child records. Cannot list users.

**Action Required:** Fix LCP credentials/session before proceeding to live data queries.

---

## E1 — Reference Intake (Schema-Only — No Live Data)

### Evaluation Record Type
- **Table:** `AS_GSS_EVALUATION`
- **Record Type UUID:** `e6bc8561-d3a6-4679-b7af-6e279910468e`
- **Record Type Name:** `AS_GSS_Evaluation_SYNCEDRECORD`
- **PK:** `EVALUATION_ID` (auto_increment int)

### Evaluation Fields (field map: DDL → camelCase)
| DDL Column | Appian Field | Type |
|---|---|---|
| EVALUATION_ID | evaluationId | int(11) PK auto_increment |
| EVALUATION_NUMBER | evaluationNumber | varchar(25) |
| EVALUATION_TITLE | evaluationTitle | varchar(255) |
| EVALUATION_DESCRIPTION | evaluationDescription | varchar(5000) |
| SOLICITATION_DESCRIPTION | solicitationDescription | varchar(5000) |
| SOLICITATION_DATE | solicitationDate | date |
| EVALUATION_START_DATE | evaluationStartDate | date |
| EVALUATION_DUE_DATE | evaluationDueDate | date |
| EVALUATION_COMPLETION_DATE | evaluationCompletionDate | date |
| COMPLETED_BY | completedBy | varchar(255) → User |
| EVALUATION_STATUS_ID | evaluationStatusId | int(11) → AS_GSS_R_DATA |
| EVALUATION_METHOD_ID | evaluationMethodId | int(11) → AS_GSS_R_DATA |
| EVALUATION_CHIEF | evaluationChief | varchar(255) → User |
| CONTRACTING_OFFICER | contractingOfficer | varchar(255) → User |
| CONTRACTING_SPECIALIST | contractingSpecialist | varchar(255) → User |
| IS_SIGNATURES_REQUIRED | isSignaturesRequired | tinyint(1) |
| IS_WEIGHTED_FACTORS_REQ | isWeightedFactorsRequired | tinyint(1) |
| IS_EVALUATOR_MASKED | isEvaluatorMasked | tinyint(1) |
| FOLDER_ID | folderId | int(11) |
| OFFICE365_FOLDER_ID | office365FolderId | varchar(255) |
| CREATED_BY | createdBy | varchar(255) |
| CREATED_DATETIME | createdDatetime | datetime |
| MODIFIED_BY | modifiedBy | varchar(255) |
| MODIFIED_DATETIME | modifiedDatetime | datetime |
| IS_ACTIVE | isActive | tinyint(1) |
| DUPLICATED_FROM_EVALUATION_ID | duplicatedFromEvaluationId | int(11) |
| SOURCE_APPLICATION_ID | sourceApplicationId | int |
| DELETION_REASON | deletionReason | varchar(1000) |
| IS_ON_SPOT_CONSENSUS | isOnSpotConsensus | tinyint(1) |
| IS_DEFAULT_DATA_GENERATED | isDefaultDataGenerated | tinyint(1) |
| IDV_AWARD_TYPE_ID | idvAwardTypeId | int(11) → AS_GSS_R_DATA |
| INSTRUMENT_TYPE_ID | instrumentTypeId | int(11) → AS_GSS_R_DATA |

### Exemplar Record (eval number `01072601`)
**⚠️ COULD NOT BE QUERIED — LCP 307 error. Must be retrieved once credentials are fixed.**
