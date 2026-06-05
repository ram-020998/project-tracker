---
inclusion: auto
---

# Knowledge Query Workflow

## Activation Triggers

This workflow activates when the user:
- Asks a question about the Appian codebase or application functionality
- Says "Ask JARVIS about..."
- Asks "How does X work?"
- Asks "What objects are involved in X?"
- Asks "Show me all X in the application"
- Asks "What is the value of constant X?"
- Asks "Debug this expression: ..."
- Asks "What's the difference between X and Y?"
- Asks "What breaks if I change X?" / "Is it safe to modify X?"
- Asks "How many X are in the application?" / "Is X unused?"
- Asks "Who has access to X?" / "What security rules apply to X?"
- Asks "Show me the data model for X" / "What fields does X have?"
- Asks about platform capabilities, limitations, or best practices
- Asks "What's the recommended approach for X?"
- Selects option 5 from the JARVIS menu

**This workflow does NOT activate for:**
- Code review requests (use code-review-workflow)
- Design document creation (use design-doc-workflow)
- Object creation (use implementation-workflow)

---

## Research Protocol

Follow these phases in order for every question.

### Phase 1: Classify the Question (Two-Step)

#### Step 1: Determine the Domain

Every question belongs to one (or more) of these domains. Classify FIRST before doing anything else:

| Domain | Signal | Examples | Primary Source |
|--------|--------|----------|---------------|
| **Codebase** | User references objects, features, flows, dependencies, data model, security | "How does evaluation scoring work?", "What calls X?", "Show me the data model" | KB (if available) → Live API |
| **Knowledge** | User asks about platform capabilities, limitations, best practices, "how should we", gotchas, recommendations | "What are the limitations of synced records?", "Best approach for batch processing?", "Has anyone done X before?" | Google Drive → Google Chat |
| **Data** | User asks about actual data — row counts, table structure, column types, data distribution | "How many evaluations are there?", "What columns does X have?", "Is there an index on Y?" | SQL (query_sql) |
| **Live** | User wants to test an expression, check a constant value, or debug something in real-time | "What is the value of cons!X?", "Evaluate this expression", "Debug this rule call" | evaluate_sail_expression |

**Multi-domain questions:** Some questions span domains. Handle them in order:
- "How does X work and what are the limitations?" → Codebase first, then Knowledge
- "What fields does the table have and how many rows?" → Codebase (data model) + Data (SQL)
- "Is this expression correct and does the data exist?" → Live (evaluate) + Data (SQL)

#### Step 2: Determine the Question Type (for Codebase domain only)

If the domain is Codebase, further classify:

| Type | Example | Signal |
|------|---------|--------|
| Technical | "What does AS_GSS_QR_getEvaluationDetails do?" | User names a specific object |
| Business | "How does evaluation scoring work?" | User asks about a process or feature |
| Structural | "What objects are involved in the consensus flow?" | User asks about a flow or group of objects |
| Relationship | "What depends on the Evaluation record type?" | User asks about dependencies |
| Compare | "What's the difference between X and Y?" | User asks to compare two objects or flows |
| Impact | "What breaks if I change X?" | User asks about blast radius or change safety |
| Inventory | "How many interfaces are in GSS?" / "Is X unused?" | User asks about counts or unused objects |
| Security | "Who has access to X?" | User asks about permissions or access control |
| Data Model | "Show me the data model for evaluations" | User asks about fields, entities, or record relationships |

---

### Phase 2: Determine Application Context

Before searching, determine which application the question is about:
- Call `get_jarvis_config` to get the list of registered applications
- Match user input against `appPrefix`, `appName`, or `jiraProjects` from the response
- Extract: `appUuid`, `appPrefix`, `kbFolderId` from the matched application

**KB availability:** If `kbFolderId` exists for the matched application, use KB-powered strategies. If not, use live API strategies.

**KB freshness check (MANDATORY — DO NOT SKIP):**

⚠️ **After calling `get_jarvis_config`, BEFORE making any other tool call, check the `staleCount` field for the matched application.**

- If `kbFolderId` is null/empty → KB is not available for this app. Skip KB strategies.
- If `staleCount` is 0 → KB is fresh. Proceed silently.
- If `staleCount` > 0 → **STOP. Your NEXT message to the user MUST be the freshness warning below. Do NOT call any KB tool (jarvis_get_app_tree, jarvis_search_objects, etc.) until the user responds.**

   > **KB Status:** {staleCount} objects have changed since the last KB generation.
   > Shall I proceed with the current KB, or would you like to refresh first?

**If you call a KB tool before showing this warning when staleCount > 0, you are violating the workflow.**

If the application is ambiguous, ask the user.

---

### Phase 3: Execute Strategy by Domain

Route to the correct strategy based on the domain from Phase 1.

---

## Domain A: Codebase Questions (KB-Powered)

**When to use:** Domain is Codebase AND the application has a `kbFolderId` in the `get_jarvis_config` response.

The KB provides pre-computed intelligence that answers most codebase questions in 1-3 calls. Follow the T-Retriever navigation pattern from `.kiro/steering/t-retriever-navigation.md`.

### Strategy A1: Technical (Specific Object) — KB

User names a specific object. Get everything in one call.

1. `jarvis_get_context(parentFolderId, objectName)` — returns content + deps + metadata + impact + clusters

If the object is not found in KB (recently created), fall back to live API Strategy A2.

**Budget:** 1 call

### Strategy A2: Business (Functional Area) — KB

User asks about a process or feature.

1. `jarvis_get_app_tree(parentFolderId)` — find the relevant cluster (if not already known from context)
2. `jarvis_get_cluster(parentFolderId, clusterName)` — get all objects in the feature with descriptions, tags, inputs
3. `jarvis_get_object_content(parentFolderId, objectName)` — read the top 2-3 key objects (Process Models, main interfaces)

**Budget:** 3-5 calls

### Strategy A3: Structural (Flow/Chain) — KB

User asks about a flow or group of objects.

1. `jarvis_get_cluster(parentFolderId, clusterName)` — get the feature cluster
2. `jarvis_get_dependency_chain(parentFolderId, objectName)` — trace calls/calledBy for key objects

**Budget:** 2-3 calls

### Strategy A4: Relationship / Data Model — KB

User asks about dependencies, data model, or how records connect.

1. `jarvis_get_data_model(parentFolderId)` — full data model with fields, relationships, data stores
2. Optionally: `jarvis_get_dependency_chain(parentFolderId, objectName)` — for specific object relationships

**Budget:** 1-2 calls

### Strategy A5: Impact Analysis — KB

User asks about blast radius or change safety.

1. `jarvis_get_impact_analysis(parentFolderId, objectName)` — direct callers, transitive callers, affected clusters, type breakdown

**Budget:** 1 call

### Strategy A6: Compare — KB

User asks to compare two objects or flows.

1. `jarvis_get_context(parentFolderId, objectNameA)` — full context for object A
2. `jarvis_get_context(parentFolderId, objectNameB)` — full context for object B
3. Present side-by-side comparison table

**Budget:** 2 calls

### Strategy A7: Inventory — KB

User asks about counts, breakdowns, or unused objects.

**For type counts:**
1. `jarvis_get_app_tree(parentFolderId)` — objectCounts section has all type counts

**For all objects of a type:**
1. `jarvis_get_objects_by_type(parentFolderId, objectType)` — full list with metadata

**For unused detection:**
1. `jarvis_get_dead_code(parentFolderId)` — all unreachable objects by type

**Budget:** 1 call

### Strategy A8: Security — KB

User asks about permissions or access control.

1. `jarvis_get_security_audit(parentFolderId)` — application-wide security issues
2. OR `jarvis_get_object_content(parentFolderId, objectName)` — security config for a specific object

**Budget:** 1-2 calls

---

## Domain A: Codebase Questions (Live API Fallback)

**When to use:** Domain is Codebase AND the application does NOT have a `kbFolderId`, OR the object was not found in KB.

### Live API Search Tool Hierarchy

| Priority | Tool | Best For | Notes |
|----------|------|----------|-------|
| 1st | `search_objects_semantic` | Primary discovery — natural language, ranked by relevance | Does NOT return Record Types. Use `appPrefix` for app-specific queries. |
| 2nd | `list_application_objects` | Exhaustive search, type-filtered, Record Types | Required for Record Types. Use for pagination. |
| 3rd | `search_objects_by_name` | Precise prefix match when you know the naming pattern | Use when you know the exact object name prefix. |

### Strategy B1: Technical (Specific Object) — Live API

1. `search_objects_by_name(objectName)` or `get_appian_object(uuid)` — find/fetch the object
2. `explain_appian_code(uuid)` — detailed logic explanation
3. Optionally: `get_object_dependencies(uuid, DEPENDENTS)` — what uses it
4. **SQL supplement** for QE_/QR_ rules: `DESCRIBE {table}`, `SHOW INDEX FROM {table}`

**Budget:** 3-8 calls

### Strategy B2: Business (Functional Area) — Live API

1. `search_objects_semantic(searchTerm, appPrefix, batchSize=15)` — ranked discovery
2. `list_application_objects(appUuid, searchTerm=keyword, objectType="Record Type")` — find data model
3. `get_appian_object(uuid)` for top 3-5 most relevant objects
4. Optionally: `get_object_dependencies(uuid, DEPENDENTS)` for the primary object

**Budget:** 5-10 calls

### Strategy B3: Structural (Flow/Chain) — Live API

1. `search_objects_semantic(searchTerm, appPrefix, batchSize=20)` — broad discovery
2. `list_application_objects(appUuid, searchTerm=keyword, objectType="Record Type")` — data model
3. `get_object_dependencies(uuid, DEPENDENTS)` + `get_object_dependencies(uuid, PRECEDENTS)` for primary objects

**Budget:** 8-15 calls

### Strategy B4: Relationship / Data Model — Live API

1. `list_application_objects(appUuid, searchTerm=keyword, objectType="Record Type")` — find Record Types
2. `get_appian_object(uuid)` for each relevant Record Type (limit 5-8)
3. `validate_record_relationships(uuid)` for the primary Record Type

**Budget:** 5-15 calls

### Strategy B5: Impact Analysis — Live API

1. Find the target object (search if needed)
2. **Level 1:** `get_object_dependencies(uuid, DEPENDENTS)` — direct dependents
3. **Level 2:** For each Level 1 dependent that is shared/core: `get_object_dependencies(dependent_uuid, DEPENDENTS)`
4. **Level 3 (optional):** If Level 2 has high-risk objects (16+ dependents), trace one more level
5. Build dependency tree with risk classification (Low: 0-5, Medium: 6-15, High: 16+)

**Depth limit:** Max 3 levels. If Level 2 has 50+ dependents, stop.

**Budget:** 5-15 calls

### Strategy B6: Compare — Live API

1. Fetch both objects: `get_appian_object(uuid)` for each
2. `get_object_dependencies` for each
3. Present side-by-side comparison table

**Budget:** 4-8 calls

### Strategy B7: Inventory — Live API

**For type counts:**
1. `list_application_objects(appUuid, objectType=type)` for each main type — extract `totalCount` from first page

**For unused detection:**
1. `get_object_dependencies(uuid, DEPENDENTS)` — zero dependents = potentially unused

**Budget:** 14-16 calls for full inventory, 1-2 per unused check

### Strategy B8: Security — Live API

1. Find the object: `search_objects_by_name(name)` or `list_application_objects`
2. `get_appian_object(uuid)` — fetch full config
3. Extract security sections based on object type

**Budget:** 2-4 calls

---

## Domain B: Knowledge Questions (Drive + Chat)

**When to use:** Domain is Knowledge — user asks about platform capabilities, limitations, best practices, recommendations, or "has anyone done X before?"

**Prerequisites:** `searchDrive` must be `true` in the `globalSettings` from `get_jarvis_config`. If not enabled, tell the user and suggest they enable it in the JARVIS Settings page.

### Strategy K1: Platform Knowledge (Drive Search)

1. Extract 1-2 focused keywords from the question
2. Search globally across all Drive files:
   ```
   Tool: mcp_google_workspace_search_drive_files
   Input: user_google_email, query="{keyword}", page_size=5
   ```
3. Read the top 2-3 most relevant docs:
   ```
   Tool: mcp_google_workspace_get_drive_file_content
   Input: file_id, user_google_email
   ```
4. Extract: limitations, capabilities, gotchas, recommended patterns

**Budget:** 3-5 calls

### Strategy K2: Team Knowledge (Chat Search — supplement only)

**Only if Drive search returns nothing useful AND the topic is very specific:**

1. Check if `searchChat` is `true` in config
2. Search globally across all Chat spaces:
   ```
   Tool: mcp_google_workspace_search_messages
   Input: user_google_email, query="{keyword}", page_size=5
   ```
3. Do NOT read full threads — extract key points from returned messages only
4. Flag chat findings as informal/unverified

**Budget:** 1-2 additional calls

### Strategy K3: Combined (Knowledge + Codebase Examples)

**When the question is "What's the recommended approach for X?" — answer from docs, then show existing implementation examples from codebase.**

1. Run Strategy K1 (Drive search) first for the recommendation
2. Then run a codebase search (KB or live API) to find existing implementations as examples
3. Present: recommendation from docs + "Here's how it's currently implemented in the app"

**Budget:** 5-8 calls total

### Knowledge Answer Structure

```
[Direct answer to the platform question]

Sources:
- 📄 {Document Name} — {key finding} (link)
- 💬 {Chat Space} — {informal finding, needs verification} (link)

[Any caveats or things to verify]
```

**⚠️ Chat findings rule:** Always label chat-sourced information as "informal/unverified" and include the message link for the user to check full thread context.

---

## Domain C: Data Questions (SQL)

**When to use:** Domain is Data — user asks about actual data, row counts, table structure, column types, data distribution, or indexes.

### Strategy D1: Database Investigation

1. Identify the table name(s) from the question — table names are UPPERCASE (e.g., AS_GSS_EVALUATION)
2. Choose the right query type:
   - Structure → `DESCRIBE {TABLE_NAME}`
   - Count → `SELECT COUNT(*) FROM {TABLE_NAME} LIMIT 1`
   - Distribution → `SELECT {column}, COUNT(*) as cnt FROM {TABLE_NAME} GROUP BY {column} ORDER BY cnt DESC LIMIT 20`
   - Index → `SHOW INDEX FROM {TABLE_NAME}`
   - Discovery → `SELECT TABLE_NAME, COLUMN_NAME FROM information_schema.columns WHERE TABLE_SCHEMA = 'Appian' AND COLUMN_NAME LIKE '%{keyword}%' LIMIT 50`
3. Present results in plain language with raw data as evidence

**Answer structure:**
```
[Direct answer to the data question]

Evidence:
{formatted query results}

[Any observations — patterns, anomalies, implications]
```

**Budget:** 1-3 SQL calls

---

## Domain D: Live Questions (Expression Evaluation)

**When to use:** Domain is Live — user wants to test an expression, check a constant value, or debug something.

### Strategy L1: Expression Evaluation

1. `evaluate_sail_expression(expression)` — evaluate directly
   - Constants: `cons!CONSTANT_NAME`
   - Rules: `rule!RULE_NAME(param1: value1, param2: value2)`
   - Math/logic: any valid SAIL expression
2. If the expression fails, show the error and suggest corrections
3. **SQL supplement** for debugging data issues:
   - `query_sql` with `SELECT * FROM {table} WHERE {condition} LIMIT 10`
   - Use when: "why does this query return empty?", "is there data for X?"

**Known limitations of evaluate_sail_expression:**
- Cannot resolve `recordType!` references
- Rule calls require all parameters to be provided
- Runs in system context

**Budget:** 1-5 calls

---

### Phase 4: Synthesize Answer

**Rules for answer quality:**

1. Answer in plain language FIRST, then provide technical details
2. Reference specific object names (so the user can dig deeper)
3. For business questions: explain the "what" and "how", not just list objects
4. For technical questions: include relevant code snippets or configuration details
5. Group related objects logically (e.g., "Data layer: ..., Business logic: ..., UI: ...")
6. Mention deprecated objects if found (objects with "DEPRECATED" or "zzz" prefix)
7. Note cross-application objects if found (different prefix than expected)
8. For knowledge questions: cite sources with links
9. For multi-domain answers: clearly separate the codebase findings from the knowledge findings

**Answer structure for business/structural questions:**

```
[Plain language summary of how it works]

Key Objects:
- [Record Type] — stores the data
- [Process Model] — orchestrates the flow
- [Expression Rules] — business logic
- [Interfaces] — user-facing forms

[Any notable findings: deprecated objects, cross-app dependencies, etc.]
```

---

### Phase 5: Offer Next Steps

Always end with 1-2 relevant follow-up options:

- "Want me to go deeper into [specific object]?"
- "Want me to trace the full dependency chain for [object]?"
- "Want me to run a code analysis on [object]?"
- "Want me to check the relationships for [Record Type]?"
- "Want me to evaluate an expression to test this?"
- "Want me to list all [type] objects in the application?"
- "Want me to compare [object A] with [object B]?"
- "Want me to check the blast radius if we modify [object]?"
- "Want me to show the application inventory breakdown?"
- "Want me to check the security configuration for [object]?"
- "Want me to map the data model for [functional area]?"
- "Want me to search the team's knowledge base for platform docs on [topic]?"
- "Want me to check if anyone discussed [topic] in team chat?"
- "Want me to check the architecture and patterns for [application]?"

---

## Pagination Rules (Live API only)

**CRITICAL:** `list_application_objects` returns max 50 results per page.

- If `totalCount > 50`, you MUST paginate to get all results
- Use `startIndex`: 1, 51, 101, 151, etc.
- For targeted searches (keyword + type filter): ALWAYS get all pages before analyzing
- For broad searches (keyword only, no type filter): scan first page descriptions — if relevant objects are found, continue; if not, refine the search keyword
- Never analyze partial results without acknowledging there are more pages

---

## Fallback: When Search Returns Nothing

If keyword search returns 0 results:

1. Try alternate keywords or synonyms (e.g., "Score" → "Rating", "Approval" → "Review")
2. Try a broader search without type filter
3. Try searching from the Record Type angle — find the closest Record Type and trace dependencies outward
4. If still nothing, ask the user for more context or a specific object name

---

## Important Notes

- This workflow is conversational — the user may ask follow-up questions. Maintain context across turns.
- Do NOT dump raw API responses. Always synthesize into readable answers.
- If a question spans multiple applications, handle each application separately.
- The `evaluate_sail_expression` tool is powerful but runs in the live environment — use it for read-only operations (queries, constant lookups, expression testing). Do NOT use it for write operations.
- When KB is available, prefer it over live API for codebase questions — it's faster and provides richer context.
- For Knowledge domain questions, always search Drive first before falling back to Chat.
