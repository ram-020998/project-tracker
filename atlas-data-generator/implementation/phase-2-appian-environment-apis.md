# Phase 2: Appian Environment APIs

## Objective

Build a set of Web APIs in the Appian application environment that enable the Data Generator MCP server to perform CRUD operations, query record properties, fetch reference data, and discover available users. These APIs are the bridge between the AI agent and the live Appian database.

---

## API Design Principles

1. **Generic over specific** — APIs should work for any record type, not be hardcoded per table
2. **Minimal first** — Start with basic CRUD + properties, extend later
3. **Appian-native** — Use Appian's record type system and expression language
4. **Secure** — API key authentication, restricted to non-production environments
5. **Idempotent where possible** — Repeated calls with same data shouldn't create duplicates (for retries)

---

## API Inventory

### First Iteration (MVP)

| # | API | Method | Purpose |
|---|-----|--------|---------|
| 1 | `/api/record/properties` | POST | Get record type field metadata (names, types, UUIDs, relationships) |
| 2 | `/api/record/create` | POST | Create a single record |
| 3 | `/api/record/update` | POST | Update fields on an existing record |
| 4 | `/api/record/query` | POST | Query records with filters |
| 5 | `/api/record/delete` | POST | Delete a record by ID |
| 6 | `/api/users/list` | GET | List available users in the environment |

### Future Iterations

| # | API | Method | Purpose |
|---|-----|--------|---------|
| 7 | `/api/record/bulk-create` | POST | Create multiple records in one call |
| 8 | `/api/record/footprint` | POST | Get all related records for a given record |
| 9 | `/api/reference-data/list` | POST | Query reference data from lookup tables |
| 10 | `/api/record/count` | POST | Count records matching a filter |

---

## API Specifications

### API 1: Get Record Properties

**Endpoint:** `POST /api/record/properties`

**Purpose:** Returns the complete field metadata for a record type, including field UUIDs needed for payload construction.

**Request:**
```json
{
  "recordType": "recordType!{e6bc8561-d3a6-4679-b7af-6e279910468e}AS_GSS_Evaluation_SYNCEDRECORD"
}
```

**Response:**
```json
{
  "success": true,
  "recordType": {
    "name": "AS_GSS_Evaluation_SYNCEDRECORD",
    "pluralName": "Evaluations",
    "description": "...",
    "reference": "recordType!{e6bc8561-d3a6-4679-b7af-6e279910468e}AS_GSS_Evaluation_SYNCEDRECORD",
    "fields": [
      {
        "name": "evaluationId",
        "reference": "recordType!{e6bc8561-...}.fields.{7f7c2d3b-...}evaluationId",
        "type": "Integer",
        "isPrimaryKey": true,
        "isCustomRecordField": false
      },
      {
        "name": "evaluationTitle",
        "reference": "recordType!{e6bc8561-...}.fields.{1aabcd17-...}evaluationTitle",
        "type": "Text",
        "isPrimaryKey": false,
        "isCustomRecordField": false
      }
    ],
    "relationships": [
      {
        "name": "vendor",
        "reference": "recordType!{e6bc8561-...}.relationships.{f95e9899-...}vendor",
        "targetRecordType": "recordType!{b6081510-...}AS_GSS_EvaluationVendor_SYNCEDRECORD",
        "relationshipType": "ONE_TO_MANY"
      }
    ]
  }
}
```

**Appian Implementation Notes:**
- Uses `a!recordTypeProperties()` function internally
- Converts the Appian map structure to JSON for the HTTP response
- This is a read-only operation

---

### API 2: Create Record

**Endpoint:** `POST /api/record/create`

**Purpose:** Creates a single record in the specified record type.

**Request:**
```json
{
  "recordType": "recordType!{e6bc8561-d3a6-4679-b7af-6e279910468e}AS_GSS_Evaluation_SYNCEDRECORD",
  "fields": {
    "evaluationTitle": "Test Evaluation for LPTA",
    "evaluationStatusId": 1,
    "evaluationStartDate": "2024-12-11",
    "contractingOfficer": "jason.john",
    "isActive": true,
    "isSignaturesRequired": true,
    "isWeightedFactorsRequired": false,
    "isEvaluatorMasked": false,
    "sourceApplicationId": 60
  }
}
```

**Response (success):**
```json
{
  "success": true,
  "recordId": 1045,
  "message": "Record created successfully"
}
```

**Response (error):**
```json
{
  "success": false,
  "error": "VALIDATION_ERROR",
  "message": "Field 'evaluationStatusId' value 99 is not a valid reference",
  "details": {
    "field": "evaluationStatusId",
    "value": 99
  }
}
```

**Appian Implementation Notes:**
- The API receives simple field name → value pairs
- Internally, it must construct the full Appian record type expression using the field UUIDs
- For each field, apply type-specific conversion:
  - `"Date"` fields: parse ISO string → `fn!date(year, month, day)`
  - `"Datetime"` fields: parse ISO string → `fn!datetime(year, month, day, hour, min, sec, 0)`
  - `"User"` fields: string → `fn!touser(username)`
  - `"Integer"` fields: number or null → value or `fn!tointeger(null)`
  - `"Decimal"` fields: number or null → value or `fn!todecimal(null)`
  - `"Boolean"` fields: true/false
  - `"Text"` fields: string value
- Skip fields marked `isCustomRecordField: true` (computed fields)
- Skip the primary key field (auto-generated)
- Use `a!writeRecords()` or equivalent to persist
- Return the auto-generated primary key value

---

### API 3: Update Record

**Endpoint:** `POST /api/record/update`

**Purpose:** Updates specific fields on an existing record.

**Request:**
```json
{
  "recordType": "recordType!{e6bc8561-d3a6-4679-b7af-6e279910468e}AS_GSS_Evaluation_SYNCEDRECORD",
  "recordId": 1045,
  "fields": {
    "evaluationStatusId": 3,
    "evaluationCompletionDate": "2024-12-15",
    "completedBy": "jason.john"
  }
}
```

**Response:**
```json
{
  "success": true,
  "recordId": 1045,
  "message": "Record updated successfully",
  "fieldsUpdated": ["evaluationStatusId", "evaluationCompletionDate", "completedBy"]
}
```

**Appian Implementation Notes:**
- Fetches the existing record first
- Applies only the specified field updates (partial update)
- Same type conversion logic as create
- Returns which fields were actually updated

---

### API 4: Query Records

**Endpoint:** `POST /api/record/query`

**Purpose:** Query records with filters. Used for exemplar pattern learning and validation.

**Request:**
```json
{
  "recordType": "recordType!{e6bc8561-d3a6-4679-b7af-6e279910468e}AS_GSS_Evaluation_SYNCEDRECORD",
  "filters": [
    {
      "field": "evaluationStatusId",
      "operator": "=",
      "value": 3
    },
    {
      "field": "evaluationMethodId",
      "operator": "=",
      "value": 4
    }
  ],
  "limit": 5,
  "fields": ["evaluationId", "evaluationTitle", "evaluationStatusId", "evaluationMethodId", "createdDatetime"]
}
```

**Response:**
```json
{
  "success": true,
  "totalCount": 12,
  "records": [
    {
      "evaluationId": 1001,
      "evaluationTitle": "HD940225Q0010",
      "evaluationStatusId": 3,
      "evaluationMethodId": 4,
      "createdDatetime": "2024-12-11T07:29:45Z"
    }
  ]
}
```

**Supported operators:** `=`, `!=`, `>`, `<`, `>=`, `<=`, `IN`, `IS_NULL`, `IS_NOT_NULL`

**Appian Implementation Notes:**
- Uses `a!queryRecordType()` internally
- Constructs filter expressions from the JSON filter array
- `fields` parameter controls which fields are returned (reduces payload size)
- `limit` defaults to 10, max 100

---

### API 5: Delete Record

**Endpoint:** `POST /api/record/delete`

**Purpose:** Delete a record by ID. Used for cleanup and rollback.

**Request:**
```json
{
  "recordType": "recordType!{e6bc8561-d3a6-4679-b7af-6e279910468e}AS_GSS_Evaluation_SYNCEDRECORD",
  "recordId": 1045
}
```

**Response:**
```json
{
  "success": true,
  "message": "Record deleted successfully"
}
```

**Appian Implementation Notes:**
- Uses `a!deleteRecords()` or sets `isActive = false` (soft delete) depending on application pattern
- Should handle FK constraint violations gracefully (return error if child records exist)

---

### API 6: List Users

**Endpoint:** `GET /api/users/list`

**Purpose:** Returns available users in the environment for populating User-type fields.

**Request:** No body needed.

**Response:**
```json
{
  "success": true,
  "users": [
    {
      "username": "jason.john",
      "displayName": "Jason John",
      "email": "jason.john@example.com"
    },
    {
      "username": "appian.administrator",
      "displayName": "Appian Administrator",
      "email": null
    }
  ]
}
```

**Appian Implementation Notes:**
- Returns users from the relevant groups (e.g., Source Selection users)
- May filter to only active users
- Could accept a `group` parameter to filter by Appian group

---

## Authentication & Security

### API Key Authentication

All APIs require an API key passed in the header:
```
Appian-API-Key: <api-key-value>
```

The API key is configured in the Appian environment and grants access to the data generation APIs only.

### Security Constraints

1. **Non-production only** — These APIs should only be deployed to dev/test/staging environments
2. **No cascade deletes** — Delete operations should fail if child records exist, not cascade
3. **Audit logging** — All write operations should be logged with timestamp and caller identity
4. **Rate limiting** — Optional, but recommended for bulk operations (e.g., max 100 creates per minute)

---

## Error Handling

All APIs return consistent error responses:

```json
{
  "success": false,
  "error": "ERROR_CODE",
  "message": "Human-readable error description",
  "details": { }
}
```

**Error codes:**

| Code | Meaning |
|------|---------|
| `INVALID_RECORD_TYPE` | Record type reference not found |
| `RECORD_NOT_FOUND` | Record ID doesn't exist |
| `VALIDATION_ERROR` | Field value fails validation |
| `FK_CONSTRAINT_VIOLATION` | Referenced record doesn't exist |
| `PERMISSION_DENIED` | API key doesn't have access |
| `CUSTOM_FIELD_WRITE` | Attempted to write to a computed field |
| `DUPLICATE_RECORD` | Record with same unique key already exists |
| `INTERNAL_ERROR` | Unexpected server error |

---

## Appian Implementation Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Appian Application                                             │
│                                                                 │
│  Web APIs (HTTP endpoints)                                      │
│  ├── /api/record/properties  → calls a!recordTypeProperties()   │
│  ├── /api/record/create      → calls a!writeRecords()           │
│  ├── /api/record/update      → calls a!writeRecords()           │
│  ├── /api/record/query       → calls a!queryRecordType()        │
│  ├── /api/record/delete      → calls a!deleteRecords()          │
│  └── /api/users/list         → calls a!queryRecordType(User)    │
│                                                                 │
│  Shared Expression Rules                                        │
│  ├── AS_GSS_DG_BuildRecordPayload   ← constructs typed payload  │
│  ├── AS_GSS_DG_ResolveFieldRef      ← maps name → UUID ref      │
│  ├── AS_GSS_DG_ConvertFieldValue    ← applies type conversion   │
│  └── AS_GSS_DG_ValidateFields       ← pre-write validation      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Key expression rule: `AS_GSS_DG_BuildRecordPayload`**

This rule takes the JSON field map from the API request and constructs the full Appian record type expression:

1. Calls `a!recordTypeProperties()` to get field references
2. For each field in the request:
   - Looks up the field's `reference` string (contains UUID)
   - Checks `isCustomRecordField` — skips if true
   - Checks `isPrimaryKey` — skips if true
   - Applies type conversion based on field `type`
3. Constructs the record type value expression
4. Returns the constructed record for `a!writeRecords()`

---

## Testing the APIs

### Manual Testing with curl

```bash
# Get record properties
curl -X POST https://env-url.appiancloud.com/suite/webapi/record/properties \
  -H "Appian-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"recordType": "recordType!{e6bc8561-...}AS_GSS_Evaluation_SYNCEDRECORD"}'

# Create a record
curl -X POST https://env-url.appiancloud.com/suite/webapi/record/create \
  -H "Appian-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "recordType": "recordType!{e6bc8561-...}AS_GSS_Evaluation_SYNCEDRECORD",
    "fields": {
      "evaluationTitle": "Test from API",
      "evaluationStatusId": 1,
      "isActive": true
    }
  }'

# Query records
curl -X POST https://env-url.appiancloud.com/suite/webapi/record/query \
  -H "Appian-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "recordType": "recordType!{e6bc8561-...}AS_GSS_Evaluation_SYNCEDRECORD",
    "filters": [{"field": "evaluationStatusId", "operator": "=", "value": 1}],
    "limit": 5
  }'
```

### Validation Checklist

- [ ] Properties API returns all fields with correct UUIDs
- [ ] Create API generates auto-increment PK and returns it
- [ ] Create API rejects writes to custom/computed fields
- [ ] Create API handles all field types correctly (Date, Datetime, User, Boolean, Integer, Decimal, Text)
- [ ] Update API performs partial update (only specified fields)
- [ ] Query API filters work for all operators
- [ ] Delete API handles FK constraint violations gracefully
- [ ] Users API returns active users
- [ ] All APIs return proper error responses for invalid inputs
- [ ] API key authentication works correctly

---

## Estimated Effort

| Task | Effort |
|------|--------|
| Properties API | 2 hours |
| Create API + payload builder | 4 hours |
| Update API | 2 hours |
| Query API | 3 hours |
| Delete API | 1 hour |
| Users API | 1 hour |
| Error handling + validation | 2 hours |
| Testing | 3 hours |
| **Total** | **~18 hours (2-3 days)** |

---

## Dependencies

- Appian environment with Source Selection application deployed
- API key configured in the environment
- Record types must be synced records (database-backed)

## Risks

- **Record type reference strings are environment-specific** — The UUIDs in record type references are consistent across environments for the same application version, but the agent must discover them via the Properties API rather than hardcoding.
- **Write permissions** — The API key's service account must have write access to the record types. May need Appian admin configuration.
- **Synced record cache** — After direct writes via `a!writeRecords()`, the synced record cache may need time to refresh before queries return the new data. May need to handle eventual consistency.
