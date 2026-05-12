# Phase 3: Data Generator MCP Server

## Objective

Build a new MCP server (`solutions-data-generator-mcp`) that provides AI agents with tools to create, query, and manage test data in Appian environments. This server acts as the translation layer between the agent's simple JSON requests and Appian's UUID-based record type API format.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  AI Agent (Kiro / Amazon Q)                                         │
│                                                                     │
│  Uses both MCP servers together:                                    │
│  • Atlas MCP → understand the application (read-only)               │
│  • Data Generator MCP → create/modify data (write)                  │
└──────────────────────────────────┬──────────────────────────────────┘
                                   │ MCP Protocol (stdio)
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Data Generator MCP Server (Docker container)                       │
│                                                                     │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────────────────┐ │
│  │ Tool        │  │ Field        │  │ Payload Builder            │ │
│  │ Handlers    │  │ Registry     │  │ (JSON → Appian format)     │ │
│  │             │  │ (cached per  │  │                            │ │
│  │ • create    │  │  record type)│  │ • UUID reference lookup    │ │
│  │ • update    │  │              │  │ • Type formatting          │ │
│  │ • query     │  │              │  │ • Custom field exclusion   │ │
│  │ • delete    │  │              │  │                            │ │
│  │ • properties│  └──────────────┘  └────────────────────────────┘ │
│  │ • users     │                                                    │
│  │ • session   │  ┌──────────────┐  ┌────────────────────────────┐ │
│  └─────────────┘  │ Session      │  │ Appian Client              │ │
│                   │ Manager      │  │ (HTTP calls to Appian)     │ │
│                   │              │  │                            │ │
│                   │ • Track IDs  │  │ • Auth (API key)           │ │
│                   │ • Rollback   │  │ • Request/response         │ │
│                   │ • Audit log  │  │ • Error handling           │ │
│                   └──────────────┘  └────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
                                   │ HTTP
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Appian Environment (Phase 2 APIs)                                  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
solutions-data-generator-mcp/
├── main.py                      # Entry point
├── Dockerfile                   # Docker container build
├── Dockerfile.local             # Local development build
├── docker-compose.yml           # Local dev compose
├── requirements.txt             # Runtime dependencies
├── requirements-dev.txt         # Dev/test dependencies
├── Makefile                     # Build/test/run commands
├── mcp.json                     # MCP configuration template
├── pytest.ini                   # Test configuration
├── .gitlab-ci.yml               # CI/CD pipeline
│
├── data_generator/              # Main package
│   ├── __init__.py
│   ├── server.py                # MCP server setup and tool routing
│   ├── config.py                # Configuration management
│   ├── client.py                # Appian HTTP client
│   ├── field_registry.py        # Field UUID registry (cached)
│   ├── payload_builder.py       # JSON → Appian format conversion
│   ├── session_manager.py       # Track created records for rollback
│   ├── models.py                # Data models and tool schemas
│   ├── logging_config.py        # Logging setup
│   │
│   └── tools/                   # Tool implementations
│       ├── __init__.py
│       ├── record.py            # create, update, delete, query
│       ├── properties.py        # get_record_properties
│       ├── users.py             # list_users
│       └── session.py           # get_session, rollback_session
│
└── tests/                       # Test suite
    ├── __init__.py
    ├── test_field_registry.py
    ├── test_payload_builder.py
    ├── test_client.py
    ├── test_session_manager.py
    └── test_tools.py
```

---

## Configuration

**Environment variables:**

| Variable | Description | Required |
|----------|-------------|----------|
| `APPIAN_ENV_URL` | Base URL of the Appian environment (e.g., `https://myenv.appiancloud.com`) | Yes |
| `APPIAN_API_KEY` | API key for authentication | Yes |
| `APPIAN_ENV_NAME` | Human-readable environment name (for logging) | No |
| `SESSION_MAX_RECORDS` | Max records per session before requiring confirmation (default: 100) | No |
| `LOG_LEVEL` | Logging level (default: INFO) | No |

**MCP configuration (`mcp.json`):**
```json
{
  "mcpServers": {
    "appian-data-generator": {
      "command": "docker",
      "args": [
        "run", "--rm", "-i",
        "--env", "APPIAN_ENV_URL",
        "--env", "APPIAN_API_KEY",
        "registry.gitlab.appian-stratus.com/appian/prod/solutions-data-generator-mcp:latest"
      ],
      "env": {
        "APPIAN_ENV_URL": "https://eng-test-solutions.appiancloud.com",
        "APPIAN_API_KEY": "${APPIAN_API_KEY}"
      }
    }
  }
}
```

---

## Core Components

### 1. Appian Client (`client.py`)

HTTP client for communicating with the Appian environment APIs.

```python
class AppianClient:
    """HTTP client for Appian environment APIs."""

    def __init__(self, base_url: str, api_key: str):
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.session = requests.Session()
        self.session.headers.update({
            "Appian-API-Key": api_key,
            "Content-Type": "application/json",
        })

    def get_record_properties(self, record_type_ref: str) -> dict:
        """Call the Properties API."""
        resp = self._post("/suite/webapi/record/properties", {
            "recordType": record_type_ref
        })
        return resp["recordType"]

    def create_record(self, record_type_ref: str, fields: dict) -> dict:
        """Call the Create API."""
        return self._post("/suite/webapi/record/create", {
            "recordType": record_type_ref,
            "fields": fields
        })

    def update_record(self, record_type_ref: str, record_id: int, fields: dict) -> dict:
        """Call the Update API."""
        return self._post("/suite/webapi/record/update", {
            "recordType": record_type_ref,
            "recordId": record_id,
            "fields": fields
        })

    def query_records(self, record_type_ref: str, filters: list, 
                      limit: int = 10, fields: list | None = None) -> dict:
        """Call the Query API."""
        payload = {
            "recordType": record_type_ref,
            "filters": filters,
            "limit": limit,
        }
        if fields:
            payload["fields"] = fields
        return self._post("/suite/webapi/record/query", payload)

    def delete_record(self, record_type_ref: str, record_id: int) -> dict:
        """Call the Delete API."""
        return self._post("/suite/webapi/record/delete", {
            "recordType": record_type_ref,
            "recordId": record_id
        })

    def list_users(self) -> list[dict]:
        """Call the Users API."""
        resp = self._get("/suite/webapi/users/list")
        return resp["users"]

    def _post(self, path: str, payload: dict) -> dict:
        url = f"{self.base_url}{path}"
        response = self.session.post(url, json=payload, timeout=30)
        response.raise_for_status()
        data = response.json()
        if not data.get("success", True):
            raise AppianAPIError(data.get("error"), data.get("message"), data.get("details"))
        return data

    def _get(self, path: str) -> dict:
        url = f"{self.base_url}{path}"
        response = self.session.get(url, timeout=30)
        response.raise_for_status()
        return response.json()
```

---

### 2. Field Registry (`field_registry.py`)

Caches record type properties and provides field lookup by name.

```python
class FieldRegistry:
    """Caches record type field metadata for UUID lookup and type info."""

    def __init__(self, client: AppianClient):
        self._client = client
        self._cache: dict[str, RecordTypeInfo] = {}

    def get_record_type(self, record_type_ref: str) -> RecordTypeInfo:
        """Get or fetch record type info (cached)."""
        if record_type_ref not in self._cache:
            props = self._client.get_record_properties(record_type_ref)
            self._cache[record_type_ref] = self._build_info(props)
        return self._cache[record_type_ref]

    def _build_info(self, props: dict) -> RecordTypeInfo:
        """Build structured info from raw properties response."""
        fields = {}
        for f in props["fields"]:
            fields[f["name"]] = FieldInfo(
                name=f["name"],
                reference=f["reference"],
                field_type=f["type"],
                is_primary_key=f["isPrimaryKey"],
                is_custom=f["isCustomRecordField"],
            )
        return RecordTypeInfo(
            name=props["name"],
            reference=props["reference"],
            fields=fields,
            relationships=props.get("relationships", []),
        )

    def get_writable_fields(self, record_type_ref: str) -> dict[str, FieldInfo]:
        """Get only fields that can be written to (excludes PK and custom)."""
        info = self.get_record_type(record_type_ref)
        return {
            name: f for name, f in info.fields.items()
            if not f.is_primary_key and not f.is_custom
        }
```

---

### 3. Payload Builder (`payload_builder.py`)

Converts simple JSON field values to Appian's typed format.

```python
class PayloadBuilder:
    """Converts agent's simple JSON to Appian record type format."""

    def __init__(self, field_registry: FieldRegistry):
        self._registry = field_registry

    def build_create_payload(self, record_type_ref: str, fields: dict) -> dict:
        """Build the payload for the Appian Create API.
        
        Input: {"evaluationTitle": "Test", "evaluationStatusId": 1, ...}
        Output: Appian-formatted field map with type conversions applied
        """
        writable = self._registry.get_writable_fields(record_type_ref)
        payload = {}

        for field_name, value in fields.items():
            if field_name not in writable:
                # Skip unknown or non-writable fields
                continue
            field_info = writable[field_name]
            converted_value = self._convert_value(value, field_info.field_type)
            payload[field_name] = converted_value

        return payload

    def _convert_value(self, value, field_type: str):
        """Apply type-specific conversion for the Appian API.
        
        The Appian Web API handles the actual fn!date(), fn!touser() wrapping
        server-side. We send clean typed values in JSON:
        - Date: "2024-12-11" (ISO format string)
        - Datetime: "2024-12-11T07:29:45Z" (ISO format string)
        - User: "jason.john" (username string)
        - Integer: 1001 or null
        - Decimal: 99.5 or null
        - Boolean: true/false
        - Text: "string value"
        """
        if value is None:
            return None

        if field_type == "Date":
            # Ensure ISO date format
            return str(value)
        elif field_type == "Datetime":
            return str(value)
        elif field_type == "User":
            return str(value)
        elif field_type == "Integer":
            return int(value) if value is not None else None
        elif field_type == "Decimal":
            return float(value) if value is not None else None
        elif field_type == "Boolean":
            return bool(value)
        else:  # Text
            return str(value)
```

**Note:** The actual `fn!date()`, `fn!touser()` wrapping happens in the Appian Web API implementation (Phase 2), not in the MCP server. The MCP server sends clean typed JSON values, and the Appian-side expression rules handle the Appian expression construction.

---

### 4. Session Manager (`session_manager.py`)

Tracks all records created in a session for rollback capability.

```python
class SessionManager:
    """Tracks records created in the current session for rollback."""

    def __init__(self):
        self._created_records: list[CreatedRecord] = []
        self._session_start = datetime.now(timezone.utc)

    def track_creation(self, record_type_ref: str, record_id: int, fields: dict):
        """Record a successful creation for potential rollback."""
        self._created_records.append(CreatedRecord(
            record_type_ref=record_type_ref,
            record_id=record_id,
            fields=fields,
            created_at=datetime.now(timezone.utc),
        ))

    def get_session_summary(self) -> dict:
        """Get summary of current session."""
        by_type: dict[str, int] = {}
        for r in self._created_records:
            by_type[r.record_type_ref] = by_type.get(r.record_type_ref, 0) + 1
        return {
            "session_start": self._session_start.isoformat(),
            "total_records_created": len(self._created_records),
            "records_by_type": by_type,
            "records": [
                {"record_type": r.record_type_ref, "record_id": r.record_id, 
                 "created_at": r.created_at.isoformat()}
                for r in self._created_records
            ],
        }

    def get_rollback_plan(self) -> list[tuple[str, int]]:
        """Get records to delete in reverse creation order (for FK safety)."""
        return [
            (r.record_type_ref, r.record_id)
            for r in reversed(self._created_records)
        ]

    def clear(self):
        """Clear session after successful rollback."""
        self._created_records = []
        self._session_start = datetime.now(timezone.utc)
```

---

## MCP Tools

### Tool Definitions

| Tool | Description | Arguments |
|------|-------------|-----------|
| `get_record_properties` | Get field metadata for a record type | `record_type_ref` |
| `create_record` | Create a single record | `record_type_ref`, `fields` |
| `update_record` | Update fields on an existing record | `record_type_ref`, `record_id`, `fields` |
| `query_records` | Query records with filters | `record_type_ref`, `filters`, `limit?`, `fields?` |
| `delete_record` | Delete a record by ID | `record_type_ref`, `record_id` |
| `list_users` | List available users in the environment | (none) |
| `get_session` | Get summary of records created in this session | (none) |
| `rollback_session` | Delete all records created in this session | `confirm` (must be true) |

### Tool Implementation (`tools/record.py`)

```python
class RecordTools:

    @staticmethod
    async def create_record(arguments: dict) -> list[types.TextContent]:
        record_type_ref = arguments["record_type_ref"]
        fields = arguments["fields"]

        # Build payload (validates fields, applies type conversion)
        payload = _payload_builder().build_create_payload(record_type_ref, fields)

        # Call Appian API
        result = _client().create_record(record_type_ref, payload)

        # Track for session rollback
        _session().track_creation(record_type_ref, result["recordId"], fields)

        return format_json_response({
            "success": True,
            "record_id": result["recordId"],
            "record_type": record_type_ref,
            "fields_written": list(payload.keys()),
        })

    @staticmethod
    async def query_records(arguments: dict) -> list[types.TextContent]:
        record_type_ref = arguments["record_type_ref"]
        filters = arguments.get("filters", [])
        limit = arguments.get("limit", 10)
        fields = arguments.get("fields")

        result = _client().query_records(record_type_ref, filters, limit, fields)

        return format_json_response({
            "total_count": result.get("totalCount", 0),
            "records": result.get("records", []),
        })
```

### Tool Implementation (`tools/session.py`)

```python
class SessionTools:

    @staticmethod
    async def get_session(arguments: dict) -> list[types.TextContent]:
        summary = _session().get_session_summary()
        return format_json_response(summary)

    @staticmethod
    async def rollback_session(arguments: dict) -> list[types.TextContent]:
        if not arguments.get("confirm"):
            return format_json_response({
                "error": "Rollback requires explicit confirmation",
                "message": "Set confirm=true to proceed. This will delete all records created in this session.",
                "session": _session().get_session_summary(),
            })

        plan = _session().get_rollback_plan()
        results = []
        errors = []

        for record_type_ref, record_id in plan:
            try:
                _client().delete_record(record_type_ref, record_id)
                results.append({"record_type": record_type_ref, "record_id": record_id, "deleted": True})
            except Exception as e:
                errors.append({"record_type": record_type_ref, "record_id": record_id, "error": str(e)})

        _session().clear()

        return format_json_response({
            "rolled_back": len(results),
            "errors": len(errors),
            "details": results + errors,
        })
```

---

## Server Setup (`server.py`)

```python
class DataGeneratorMCPServer:
    """Data Generator MCP Server with tool routing."""

    def __init__(self):
        self.server = Server("data-generator-mcp")
        self._setup_handlers()

        self.tool_handlers = {
            "get_record_properties": PropertiesTools.get_record_properties,
            "create_record": RecordTools.create_record,
            "update_record": RecordTools.update_record,
            "query_records": RecordTools.query_records,
            "delete_record": RecordTools.delete_record,
            "list_users": UsersTools.list_users,
            "get_session": SessionTools.get_session,
            "rollback_session": SessionTools.rollback_session,
        }
```

---

## Docker Packaging

**Dockerfile:**
```dockerfile
FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY data_generator/ ./data_generator/
COPY main.py .

ENTRYPOINT ["python", "main.py"]
```

**requirements.txt:**
```
mcp>=1.0.0
requests>=2.31.0
```

---

## Error Handling Strategy

The MCP server wraps all Appian API errors into structured tool responses:

```python
try:
    result = client.create_record(...)
except AppianAPIError as e:
    return format_json_response({
        "success": False,
        "error": e.error_code,
        "message": e.message,
        "details": e.details,
        "suggestion": _get_suggestion(e.error_code),
    })
```

**Suggestions by error type:**
- `FK_CONSTRAINT_VIOLATION` → "The referenced record doesn't exist. Create the parent record first. Check insertion_order from the schema."
- `VALIDATION_ERROR` → "Check the field type and valid values. Use get_reference_data from Atlas MCP for valid enum values."
- `CUSTOM_FIELD_WRITE` → "This field is computed and cannot be written directly. Remove it from your fields."

---

## Testing Strategy

### Unit Tests (mocked Appian API)

- Field registry caching behavior
- Payload builder type conversions
- Session manager tracking and rollback ordering
- Error handling for all API error codes

### Integration Tests (against real Appian environment)

- Create → Query → Verify → Delete cycle
- Multi-record creation with FK dependencies
- Rollback of entire session
- Concurrent session isolation

---

## Estimated Effort

| Task | Effort |
|------|--------|
| Project scaffolding (structure, config, Docker) | 2 hours |
| Appian client | 2 hours |
| Field registry | 2 hours |
| Payload builder | 2 hours |
| Session manager | 2 hours |
| Tool implementations (8 tools) | 4 hours |
| Server setup and routing | 1 hour |
| Error handling | 2 hours |
| Unit tests | 4 hours |
| Docker build + CI/CD | 2 hours |
| Integration testing | 3 hours |
| **Total** | **~26 hours (3-4 days)** |

---

## Dependencies

- Phase 2 APIs must be deployed and accessible
- Docker for containerization
- `mcp` Python package for MCP protocol
- `requests` for HTTP calls

## Risks

- **Appian API latency** — Each create call is an HTTP round-trip. For bulk operations, this could be slow. Acceptable for MVP; batch API in Phase 5.
- **Session state is in-memory** — If the MCP server process dies, session tracking is lost. Acceptable for MVP since sessions are short-lived.
- **Field registry cache invalidation** — If record type schema changes between calls, the cache could be stale. Mitigated by per-session lifetime (cache resets when server restarts).
