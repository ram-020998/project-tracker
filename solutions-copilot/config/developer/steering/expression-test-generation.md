---
inclusion: manual
---

# Expression Test Generation Workflow

## Overview

This workflow generates test cases in XML format for expression rules found in an exported Appian package. It reads the SAIL definitions from the export, analyzes inputs/outputs, and produces structured test case XML that can be used for validation.

**Common Triggers:**
- "Generate test cases for expressions in package {UUID}"
- "Create test XML for the expression rules in this export"
- "Write test cases for {expression rule name}"
- "Generate tests from exported package"

---

## Quick Path (from existing export ZIP)

If the user already has an export ZIP in the `exports/` folder:

```
1. extract_sail_from_export(export_zip_path="exports/export-<uuid>.zip")
2. [AI analyzes expression rules and generates test case XML]
```

**If the package contains multiple expression rules**, use the chained rebuild approach (see "Multi-Object Packages" section under Deploying Test Cases).

---

## Full Path (from package UUID or object name)

```
1. export_package(package_uuid="<UUID>")
2. get_export_results(export_uuid="...") → downloads ZIP
3. extract_sail_from_export(export_zip_path="exports/export-<uuid>.zip")
4. [AI analyzes expression rules and generates test case XML]
```

**Finding the package UUID:**
- If user provides a package URL: extract the base64 ID from the URL path
- If user provides an object name: use `jarvis_search_objects` to find it, then identify the package

---

## CRITICAL: Check Existing Test Cases Before Modifying

**Before writing or deploying any test cases, you MUST inspect the export to see what tests already exist.**

### Mandatory Pre-Check

After extracting the SAIL from the export (`extract_sail_from_export`), review the "Test Cases" section for each expression rule. If test cases are already present:

1. **Run existing tests first.** Before making any decisions, evaluate every existing test case using `evaluate_sail_expression` to confirm it actually passes. A test without an assertion, or with a wrong assertion, is a bad test — it provides false confidence.
2. **Replace bad tests entirely.** A test case is "bad" and must be replaced if:
   - It has **no assertion** (just sets inputs but never verifies output)
   - Its **assertion is wrong** (evaluates to false against the current rule logic)
   - Its **name is misleading** (e.g., named "Null" but doesn't actually test null)
   - It **duplicates another test** (same inputs and same branch, different name)
   Do NOT keep bad tests around. Replace them with correct, well-named tests that have proper assertions.
3. **Evaluate existing coverage.** Do the remaining good tests already cover the rule's branches, null handling, and edge cases adequately?
4. **Do NOT overwrite good tests without justification.** If the existing tests are correct and provide good coverage, leave them alone.
5. **Only add tests that fill gaps.** If existing tests miss a branch, boundary, or null case, add only the missing tests.
6. **Only remove good tests if they are obsolete.** A test is obsolete if it tests a code path that no longer exists.
7. **Only edit tests if the rule changed.** If the rule's logic was modified and existing assertions are now wrong, update those specific assertions.

### Decision Flow Per Rule

```
extract_sail_from_export → for each expression rule:
  ├── Is it a static data rule? (returns hardcoded data that never changes at runtime)
  │   └── YES → SKIP — static data rules do not need tests
  ├── Is it a pass-through wrapper? (delegates to another rule with no logic of its own)
  │   └── YES → SKIP — test the called rule instead, not the wrapper
  ├── Has existing tests?
  │   ├── YES → Run them with evaluate_sail_expression to check correctness
  │   │   ├── ALL PASS with proper assertions → Are they sufficient coverage?
  │   │   │   ├── YES → SKIP this rule (do not touch)
  │   │   │   └── NO → Add missing tests only
  │   │   └── ANY are bad (no assertions, wrong assertions, misleading names)
  │   │       └── REPLACE all bad tests with correct ones, keep good ones
  │   └── NO → Write a full test suite from scratch
```

### Rules That Do NOT Need Tests

Do not generate test cases for expression rules that are purely static data — rules whose output is fully determined at design time and never changes at runtime. A rule is static if **all** of the following are true:

1. The rule body contains **no conditional logic** (`if`, `a!match`, `choose`, `decision`)
2. The rule makes **no external calls** (`rule!`, integration calls, queries, `a!queryEntity`, `a!queryRecordType`, `#"<uuid>"(...)` connected system/integration calls)
3. The rule uses **no dynamic functions** (`today()`, `now()`, `loggedInUser()`, `userLocale()`)
4. The output is **fully hardcoded** — every value in the return is a literal (string, number, boolean, list of literals, type constructor with literal fields)

**⚠️ CRITICAL: Do NOT confuse `#"<uuid>"(...)` with type constructors.** The syntax `#"<uuid>"(key: value)` is a **connected system or integration call** — it invokes an external system and returns a response. This is NOT static data, even if the response fields look like hardcoded literals. The response comes from a live integration at runtime.

How to distinguish:
- **Type constructor (static):** `'type!{urn:com:appian:types:APP}MY_CDT'(field: "value")` — uses `type!{urn:...}` prefix
- **Integration call (NOT static):** `#"9e21079c-da3f-4df5-a9a8-6d6eb1e98507"(legalBusinessName: "Appian")` — uses `#"<uuid>"(...)` syntax

If you see `#"<uuid>"(...)` in a rule body, it is an integration call and the rule MUST be tested (see "Rules that call integrations" section below).

**⚠️ CRITICAL: Recognize integration responses by their OUTPUT shape.** If a rule's output contains a `success` field (e.g., `success: true`, `legalBusinessName: "Appian"`), it is wrapping an integration response — even if the code looks like a simple constructor. The presence of `success` in the output is the definitive signal that this rule calls an integration and MUST receive the standard integration test pattern:
1. A "completes without errors" smoke test
2. An assertion that `success = true`: `toboolean(index(test!output, "success", null)) = true`
3. A generic response body assertion: `not(isnull(test!output))`

**Do NOT classify a rule as "static data" if its output contains a `success` field.** The `success` field is the hallmark of an integration response — it means the rule is calling an external system at runtime.

**Whether or not the rule has inputs is irrelevant to this check.** A rule with inputs can still be static if it ignores them or uses them in a purely hardcoded mapping with no logic. The question is: does the output ever change at runtime? If no, skip it.

**Examples of static data rules (DO NOT test):**
- `'type!{urn:com:appian:types:MY_APP}MY_CDT'(field1: "hardcoded", field2: 123)` — type constructor with literal values
- `{a!map(label: "Active", value: true), a!map(label: "Inactive", value: false)}` — hardcoded list of maps
- `a!pagingInfo(1, 20, a!sortInfo("createdDate", false))` — static configuration object
- `{"PRODUCT", "SERVICE", "SUBSCRIPTION"}` — hardcoded list of strings

These are effectively constants stored as expression rules (see Section 4B of the best practices — "No array constants, use expression rules instead"). Testing them would just be testing that Appian can construct a type or return a literal, not testing any business logic.

**Rules that DO need tests (even if they look simple):**
- Rules that call other rules (`rule!MY_RULE(...)`) — the called rule may have logic or side effects
- Rules that call integrations via UUID syntax (`#"<uuid>"(...)`) — these invoke external systems at runtime
- Rules that use dynamic functions (`today()`, `now()`, `loggedInUser()`) — output changes over time
- Rules that reference constants (`cons!MY_CONSTANT`) where the test validates the constant's value is correct in the environment
- Rules with **any** conditional logic — even a single `if` or `a!match` means there are branches to cover

**The key distinction: if the rule's output is 100% determined by hardcoded literals at design time, it's static data and doesn't need tests. If anything about the output depends on runtime evaluation — logic, external calls, dynamic functions — it needs tests.**

### Rules That Are Pass-Through Wrappers (Also Do NOT Need Tests)

A pass-through rule is one that **delegates entirely to another rule** without adding any logic of its own. These rules:
- Call a single other rule (or query) and return its result (or `.data`, `.totalCount`, etc.)
- Pass inputs straight through (or use hardcoded parameters)
- Have **no conditional logic** — no `if`, `a!match`, `choose` around the call
- Perform **no transformation** on the result — no filtering, mapping, or reshaping the output

**Examples of pass-through rules (DO NOT test):**
```sail
/* Just delegates to another rule with hardcoded paging and forwards an input */
rule!AS_AIDB_QR_getDocument(
  pagingInfo: a!pagingInfo(1, 1, a!sortInfo(..., false)),
  username: ri!username,
  returnType: cons!AS_CO_ENUM_QE_RETURN_TYPE_DATA_SUBSET
).data

/* Just calls a query rule and returns the result */
rule!AS_GAM_QE_getVendors(showInactive: ri!showInactive)
```

**Why these don't need tests:**
- The rule has no logic of its own — testing it would be testing the *called* rule, not this one
- Per best practices: "If a parent rule calls a child rule, don't duplicate the child's test cases in the parent — test only the parent's own logic"
- The called rule's behavior should be tested on the called rule itself
- Any assertion on the output would depend on transactional data (environment-specific)
- **You cannot write a meaningful assertion** — if the rule queries data that may or may not exist (e.g., "get latest document for user"), the output could be null or populated depending on the environment's data state. There is no correct expected value to assert against.

**Exception — null input check:** If a pass-through rule has inputs (`ri!` parameters), always include a single "completes without errors" test case that passes `null` for each input. This doesn't test logic — it verifies the rule doesn't throw an unhandled error when given null. Use the "completes without errors" assertion type (no expected output, just confirm it doesn't blow up).

**Rules that call another rule but DO need tests:**
- Rules that **transform** the result (filter, map, reshape, extract specific fields with logic)
- Rules that have **conditional logic around the call** (e.g., `if(isnull(ri!id), null, rule!getById(id: ri!id))`)
- Rules that **combine results from multiple calls**
- Rules that **add error handling** around the call (e.g., wrapping in `a!defaultValue`)
- Rules that **call integrations returning structured responses** (e.g., responses with `success` and `result` fields) — these need:
  1. A "completes without errors" smoke test
  2. An assertion that `success = true`: `toboolean(index(test!output, "success", null)) = true`
  3. **A generic response body assertion** — validate the response is not null: `not(isnull(test!output))`. Do NOT assume specific field names in the response body unless you have confirmed the exact structure by examining callers or the integration definition. The response might use CDT field accessors, nested maps, or different key names depending on the integration.
  
  Only assert specific field values if:
  - You have confirmed the field name by examining the rule's callers or the integration connected system
  - The field is part of the integration's documented contract (e.g., a SAM.gov API always returns `legalBusinessName`)
  
  Generic assertion pattern:
  - `toboolean(index(test!output, "success", null)) = true` — integration succeeded
  - `not(isnull(test!output))` — response body exists

**The test:** if you removed the `rule!` call and replaced it with a hardcoded sample response, would there be any remaining logic to test? If no, it's a pass-through and doesn't need tests.

### Reporting

After processing, always report to the user:
- **Skipped (already covered):** Rules that had adequate existing tests — list them with a note like "4 existing tests cover all branches"
- **Augmented:** Rules where you added new tests alongside existing ones — explain what was added and why
- **Modified:** Rules where existing tests were changed — explain what was wrong
- **New:** Rules that had no tests and received a full test suite

---

## Test Case XML Format

Each expression rule should have test cases generated in the following XML structure:

```xml
<testCases>
  <testCase>
    <name>Test Case Name - Descriptive of scenario</name>
    <expressionRule>RULE_NAME</expressionRule>
    <description>What this test validates</description>
    <inputs>
      <input>
        <name>ri!parameterName</name>
        <type>Text|Integer|Boolean|List|CDT|Map|etc.</type>
        <value>sample value</value>
      </input>
      <!-- Additional inputs as needed -->
    </inputs>
    <expectedOutput>
      <type>Text|Integer|Boolean|List|CDT|Map|etc.</type>
      <value>expected result</value>
    </expectedOutput>
    <category>happy-path|edge-case|null-handling|boundary|error</category>
  </testCase>
</testCases>
```

---

## Test Case Generation Strategy

For each expression rule, generate test cases covering these categories:

### 1. Happy Path
- Standard inputs that exercise the primary logic path
- Typical real-world values the rule would receive

### 2. Null/Empty Handling
- `null` for each nullable input parameter
- Empty text `""` for text parameters
- Empty list `{}` for list parameters
- Verify the rule handles missing data gracefully

### 3. Boundary Conditions
- Minimum and maximum values for numeric inputs
- Single-character and very long strings for text inputs
- Single-element and large lists for list inputs
- Date boundaries (start/end of year, leap years)

### 4. Edge Cases
- Unexpected type combinations (if the rule uses `typeof` or type coercion)
- Special characters in text inputs
- Duplicate values in lists
- Negative numbers where positive are expected

### 5. Error/Invalid Inputs
- Inputs that should trigger error handling or default behavior
- Values outside expected ranges
- Mismatched types (if applicable)

---

## Analysis Steps

When generating test cases, follow this process:

1. **Identify Rule Inputs**: Extract all `ri!` parameters — note their names and expected types
2. **Understand Logic Flow**: Read the SAIL definition to understand:
   - What transformations are applied
   - What conditions/branches exist (`if`, `choose`, `a!match`)
   - What the return type is
3. **Map Branches to Tests**: Each conditional branch should have at least one test case that exercises it
4. **Determine Expected Outputs**: Trace through the logic manually for each test input set
5. **Document Assumptions**: If the expected output depends on external data (queries, rules), note that in the test description

---

## Gathering Context for Complex Inputs

When a rule has complex inputs (Maps, CDTs, record types, nested structures), **do not guess the field names or structure**. Instead, use the Jarvis KB and live tools to discover how the rule is actually called:

### Step 1: Find the rule in the KB

```
jarvis_get_context(parentFolderId=<kbFolderId>, objectName="<rule_name>")
```

This returns the rule's callers (`calledBy`), dependencies (`calls`), and cluster membership — giving you the full picture of where it lives in the app.

### Step 2: Examine callers to understand input shape

Look at the `calledBy` list and retrieve the caller's code:

```
jarvis_get_object_content(parentFolderId=<kbFolderId>, objectName="<caller_name>")
```

In the caller's code, find where the rule is invoked and examine:
- What values are passed to each `ri!` parameter
- What map keys are used (e.g., `.fileName`, `.appianDocId`, `.error`)
- What nested structures exist (e.g., `.dataSubset.data`)
- What the data looks like at runtime (field names, types, realistic values)

### Step 3: Check related rules for data contracts

If the rule calls helper rules (visible in `calls`), check those too:
- Filter/utility rules reveal which map keys they expect
- Constants reveal enum values or limits
- Record type queries reveal field structures

### What to look for in callers

| Caller Type | What it reveals |
|-------------|----------------|
| **Interface** | How users construct the input (grid selections, form fields → map keys) |
| **Process Model** | What upstream nodes produce (download responses, query results) |
| **Expression Rule** | How the data is transformed before being passed |

### Example workflow

For a rule like `validateDownloadDocumentForDocGeneration(ri!docDownloadResponse, ri!selectedDocumentMaps)`:

1. `jarvis_get_context` → finds it's called by "Create Document from Collection" process model
2. `jarvis_get_object_content("Create Document from Collection")` → shows the process has a "Download Docs From S3" node that produces `docDownloadResponse`, and a wizard interface that produces `selectedDocumentMaps`
3. `jarvis_get_object_content("AS_PD_FM_createDocFromCollectionWizard_Step3")` → reveals the exact map structure: `{fileName, fileType, appianDocId, fileSize, s3Path, isPspRecordConfig, recordTypeConfig, relatedRecord}`
4. Now you can write test cases with realistic field names and values that match actual runtime data

### RefData inputs

When a rule has an input named `refData` (typically typed as a Record Type), **do not pass null or hand-craft record type constructors**. Instead, find a query rule that loads the ref data from the database.

**How to find the correct query rule:**
1. Identify the record type UUID from the `refData` input's type definition
2. Use `get_object_dependencies` with `dependency_type: "DEPENDENTS"` on the record type to find rules that query it
3. Look for a query/expression rule whose return type is `"OBJECT_ARRAY"` — this is the loader that returns the full ref data set

**Use the query rule as the test input value:**
```
"refData": "rule!AS_PD_QR_getRefData(returnType: \"OBJECT_ARRAY\")"
```

**Note:** When the query rule has a `returnType` parameter, always use `"OBJECT_ARRAY"` — this returns the records directly as a list without needing `.data`. Do NOT use `"DATA_SUBSET"` (which returns a DataSubset requiring `.data` extraction).

**Fallback when no query rule exists:**
Not every record type will have a dedicated `QR_get` query rule. If no query rule is found in the dependents list, construct the record using the `recordType!` constructor syntax (see "Record Type / CDT Input Syntax" in the Deploying section).

**Discovery workflow:**
```
1. Identify the record type UUID from the refData input's type
2. Search for dependents: jarvis_get_impact_analysis(objectName="<RecordTypeName>")
   or get_object_dependencies(object_uuid="<RecordTypeUUID>", dependency_type="DEPENDENTS")
3. Look for expression rules with QR_, QE_, get, load, or query in the name
4. If found → use that rule in the test input
5. If not found → use a!queryRecordType() with the record type reference
```

**For null-handling tests:** You can still pass `null()` for `refData` to test null behavior.

**For filtering tests:** If the rule filters refData by a specific field (e.g., `wherecontains(3, ri!refData[refDataId])`), you may need to pass a filter parameter to the query or use a pagingInfo that returns enough records to include matching ones.

### Record Type inputs (single record)

When a rule has an input typed as a single record type (not a list), use the same query rule pattern but with `returnType: "SINGLE_OBJECT"` to get a single record directly — no need to wrap in `index(..., 1, null)`.

```
rule!AS_[appPrefix]_QR_get[RecordName](returnType: "SINGLE_OBJECT")
```

**Return type reference:**
- `"OBJECT_ARRAY"` — returns a list of records (use for list-typed inputs like `refData`)
- `"SINGLE_OBJECT"` — returns a single record (use for single-typed inputs like `collection`)

### BrandingMap inputs

When a rule accepts a `brandingMap` parameter (typed as `Map`), **do not hand-craft the map**. Every SOLUTIONS application has a loader rule `AS_[appPrefix]_loadBrandingMap` that returns the correct branding map structure for that application.

**Use the loader rule as the test input value:**
```
rule!AS_[appPrefix]_loadBrandingMap()
```

For example, if the application prefix is `PD`, use:
```
rule!AS_PD_loadBrandingMap()
```

This ensures the test uses a realistic branding map from the live environment rather than a guessed `a!map(AccentColor: "#FF0000")` that may not match the actual structure.

**For null-handling tests:** You can still pass `null()` for `brandingMap` to test null behavior.

### General Rule: Use Constants Instead of Hardcoded Values

When the rule under test references a constant (e.g., `cons!AS_PD_REF_ID_AGENT_STATUS_TYPE_COMPLETED`), **use that same constant in the test case inputs** instead of its hardcoded value.

**Example — instead of:**
```
"statusId": "3"
```

**Use:**
```
"statusId": "cons!AS_PD_REF_ID_AGENT_STATUS_TYPE_COMPLETED"
```

**Why:**
- If the constant value changes, the test still works
- Makes the test self-documenting — you can see the intent ("COMPLETED status") rather than a magic number
- Validates that the constant itself is correctly configured in the environment

**When to use hardcoded values instead:**
- For null-handling tests: `null()`
- For "non-matching" tests where you intentionally want a value that does NOT match the constant (e.g., `statusId: 1` to test the else branch)
- For boundary/edge case tests with specific numeric values

### Constructing relationships in record inputs

When a rule accesses a relationship on a record input, you must construct the related record(s) inside the parent record. Relationships are **not flat fields** — they are nested record constructors.

**How to identify a relationship access in SAIL code:**

In the rule's SAIL definition, a relationship access looks like:
```
ri!collection['recordType!{parent-uuid}Parent.relationships.{rel-uuid}relName.fields.{field-uuid}fieldName']
```

This means:
- `{parent-uuid}` = the parent record type UUID
- `{rel-uuid}relName` = the relationship UUID and name on the parent
- `{field-uuid}fieldName` = the field on the **related** record type (not the parent)

**How to construct it:**
1. The parent record uses `.relationships.{rel-uuid}relName` as the key
2. The value is wrapped in `{...}` (a list, even for a single related record)
3. Inside, construct the related record using **its own** record type UUID and field references

**Finding the related record type UUID:**
The rule's SAIL code only shows the parent record type UUID and the relationship UUID. To find the related record type UUID:
1. Look at the record type in the KB or via `get_object_dependencies` — the relationship target tells you which record type it points to
2. Or search for the relationship name (e.g., `collectionEntityMaps`) — it typically maps to a record type with a matching name (e.g., `AS_PD_CollectionEntityMap_RecordType`)

**Empty relationship:**
If you want to test with no related records:
```
'recordType!{parent-uuid}Parent.relationships.{rel-uuid}relName': {}
```

**When to construct instead of query:**
Even when a query rule exists, **construct the record if the rule accesses relationship fields.** A simple `QR_get(returnType: "SINGLE_OBJECT")` call without `relatedRecordData` will not populate relationships — those fields will be null.

**Rule of thumb:** Look at every field the rule accesses on the record input. If any of them contain `.relationships.`, construct the record manually so you can populate the nested data and get full test coverage.

---

## Example

Given an expression rule `APP_getStatusLabel` with:
```sail
ri!statusCode (Text)
```

Generate:
```xml
<testCases>
  <testCase>
    <name>Happy Path - Active status code</name>
    <expressionRule>APP_getStatusLabel</expressionRule>
    <description>Returns the display label for an active status code</description>
    <inputs>
      <input>
        <name>ri!statusCode</name>
        <type>Text</type>
        <value>"ACTIVE"</value>
      </input>
    </inputs>
    <expectedOutput>
      <type>Text</type>
      <value>"Active"</value>
    </expectedOutput>
    <category>happy-path</category>
  </testCase>

  <testCase>
    <name>Null Handling - Null status code</name>
    <expressionRule>APP_getStatusLabel</expressionRule>
    <description>Returns default value when status code is null</description>
    <inputs>
      <input>
        <name>ri!statusCode</name>
        <type>Text</type>
        <value>null</value>
      </input>
    </inputs>
    <expectedOutput>
      <type>Text</type>
      <value>"Unknown"</value>
    </expectedOutput>
    <category>null-handling</category>
  </testCase>

  <testCase>
    <name>Edge Case - Unrecognized status code</name>
    <expressionRule>APP_getStatusLabel</expressionRule>
    <description>Returns fallback when code doesn't match any known status</description>
    <inputs>
      <input>
        <name>ri!statusCode</name>
        <type>Text</type>
        <value>"INVALID_CODE_XYZ"</value>
      </input>
    </inputs>
    <expectedOutput>
      <type>Text</type>
      <value>"Unknown"</value>
    </expectedOutput>
    <category>edge-case</category>
  </testCase>
</testCases>
```

---

## Guidelines

### Best Practices (from [Appian Community Guide](https://community.appian.com/success/w/guide/3342/how-to-create-expression-rule-test-cases))

Content was rephrased for compliance with licensing restrictions.

**General:**
- Create test cases from the start of development to aid regression testing
- If a parent rule calls a child rule, don't duplicate the child's test cases in the parent — test only the parent's own logic
- Break down large expressions into individual rules for easier test coverage
- Every expression rule should have at least one **coverage test** and one **error handling test**

**Coverage Tests (testing intended outputs):**
- **Limited outcomes** (if/choose/match): Create 1 test case per possible branch/condition
- **Mathematical comparisons**: Cover all comparison outcomes (less than, equal to, greater than)
- **Unlimited outcomes** (calculations): Identify input groupings that cover different output categories. Calculate expected output outside Appian, then assert it.
- **Date/time rules**: Cover all groupings of expected outcomes including edge cases. Avoid hard-coded dates — use `today()`, `now()` etc. so tests don't go stale. Don't use `now()` in assertions (millisecond precision causes false negatives).
- **Type constructors**: Use "assertion expression evaluates to true" to validate output structure

**Error Handling Tests (testing graceful failure):**
- **Null handling**: Set one, some, or all inputs to null. Most rules need multiple null test cases.
- **Invalid math**: Test inputs that produce invalid calculations (e.g., denominator of zero)
- **Invalid function inputs**: Test with values that would cause expression errors (e.g., invalid username strings)
- **Date boundaries**: Test with dates outside expected ranges
- **Queries on transactional data**: Don't assert specific data (it varies by environment). Instead assert "test completes without errors" for connectivity, or validate that returned results match filter criteria.

**Assertion guidance:**
- Use `test!output` to assert the output equals what you expect
- For queries, use "assertion expression evaluates to true" with `typeof(test!output)` to validate return type
- For integrations, assert that the "success" output = true

**Regression testing workflow:**
1. Before changing a rule: run all existing test cases, resolve failures
2. After changing: add new coverage + error handling tests for the change
3. Run all test cases to ensure the update didn't break existing cases

### Generation Guidelines

- **One set of test cases per expression rule** — keep tests grouped by the rule they target
- **The first test case is always the default** — it becomes the default test case in the Appian designer (the inputs that load when you click "Test"). Always put the happy path first so it serves as the default. If there's no happy path (e.g., a pass-through rule with only a null smoke test), the first test case still becomes the default.
- **Never modify the object's description when writing test cases** — the `object_description` field is for intentional documentation changes, not a workaround for tooling constraints. Test case deployment should only touch test cases.
- **Aim for 3-7 test cases per rule** depending on complexity:
  - Simple rules (1 branch): 3 tests (happy path, null, edge case)
  - Medium rules (2-4 branches): 5 tests
  - Complex rules (5+ branches or nested logic): 7+ tests
- **Use realistic values** — reference actual CDT field names, constant values, or enum codes visible in the SAIL code
- **Note external dependencies** — if a rule calls other rules or queries data, mark those tests with a note that expected output may vary based on environment data
- **Preserve naming conventions** — use the application's prefix (e.g., `APP_`, `GAMS_`, `QE_`) in test names

### Testing Principles (from [Appian Docs](https://docs.appian.com/suite/help/26.4/Expression_Rule_Testing.html))

Content was rephrased for compliance with licensing restrictions.

1. **Test only your logic** — don't test Appian built-in functions (e.g., don't verify `sum()` adds numbers). Focus on your rule's specific logic, type handling, and null handling.

2. **Make tests as specific as possible** — isolate one part of the expression rule per test case. If a rule has 3 possible results, create 3 separate tests rather than one test checking all 3.

3. **Avoid "1=1 tests"** — if your assertion expression is basically the same as the rule definition, you're not testing anything. The assertion must be independently derived.

4. **Write reliable tests** — tests that depend on external system values (queries, `now()`, etc.) are fragile. Use static/hardcoded inputs where possible. For CDT inputs, construct minimal dictionaries with only the fields the rule uses.

5. **Test appropriate rules** — not all rules can be effectively tested. Rules querying transactional data that varies by environment may only need "completes without errors" assertions.

### Test-Driven Development Pattern

For rules with complex validation logic (like email validation), consider writing test cases BEFORE writing the rule:

1. Define test cases for each example input and expected output
2. Write the expression rule
3. Run tests continuously as you implement logic
4. Watch tests pass as you add each piece of validation

This ensures no edge cases are missed and documents expected behavior.

### Testing Rules with Dynamic Values

When a rule uses `today()`, `now()`, or queries:
- **Don't assert literal output values** — they'll change over time
- **Don't rewrite the rule logic in the assertion** (1=1 test)
- **Instead, test structural properties:**
  - Output length: `length(test!output) = year(today()) - ri!startYear + 1`
  - Output type: `typeof(test!output) = typeof({0})`
  - Contains expected values: `contains(test!output, year(today()))`

### Testing Rules with CDT Inputs

- Construct minimal test data using dictionaries with only the fields the rule uses
- Don't query real data — hardcode static inputs to avoid fragile tests
- Example: `{type: "OFFICE"}, {type: "ELECTRONICS"}` instead of querying a table

### Separate Assertions into Individual Test Cases

Even if assertions are simple and could be combined with `and()`, keep them in separate test cases:
- Makes debugging easier — you immediately know which specific check failed
- Documents expected behavior more clearly
- Each test case should describe one specific aspect of the rule's logic

### Using test!output in Assertion Expressions

When deploying test cases to Appian, the assertion expression can reference `test!output` to check properties of the rule's return value rather than asserting the exact value. This is the "assertion expression evaluates to true" pattern.

**Common test!output patterns:**

| Pattern | Use Case | Example |
|---------|----------|---------|
| `a!isNullOrEmpty(test!output)` | Verify output is empty/null | `a!isNullOrEmpty(test!output)` |
| `length(test!output) = N` | Verify array length | `length(test!output) = 3` |
| `typeof(test!output) = typeof({0})` | Verify return type is integer list | `typeof(test!output) = typeof({0})` |
| `typeof(test!output) = typeof("")` | Verify return type is text | `typeof(test!output) = typeof("")` |
| `not(isnull(test!output))` | Verify non-null output | `not(isnull(test!output))` |
| `a!isNotNullOrEmpty(test!output)` | Verify non-null and non-empty | `a!isNotNullOrEmpty(test!output)` |
| `test!output > 0` | Verify positive number | `test!output > 0` |
| `contains(test!output, "expected")` | Verify output contains value | `contains(test!output, "Active")` |
| `test!output.field = "value"` | Verify CDT field value | `test!output.status = "APPROVED"` |
| `toboolean(index(test!output, "success", null))` | Verify boolean field from integration response | `toboolean(index(test!output, "success", null))` |

**⚠️ CRITICAL: Type casting when using `index()` in assertions.** The `index()` function returns an untyped value. When comparing the result against a typed literal (integer, boolean, decimal), you **MUST** cast the indexed value to the expected type before comparing. Without the cast, the equality check can fail even when the values are logically equal.

| Expected Type | Cast Function | ❌ Wrong | ✅ Correct |
|---------------|---------------|----------|-----------|
| Integer | `tointeger()` | `index(test!output, "score", null) = 0` | `tointeger(index(test!output, "score", null)) = 0` |
| Boolean | `toboolean()` | `index(test!output, "success", null) = true` | `toboolean(index(test!output, "success", null)) = true` |
| Decimal | `todecimal()` | `index(test!output, "rate", null) = 3.5` | `todecimal(index(test!output, "rate", null)) = 3.5` |
| Text | *(no cast needed)* | — | `index(test!output, "label", null) = "Active"` |

Text comparisons work without casting because both sides are already text. All other types require explicit casting.

This applies anywhere you use `index()` to extract a value from a map/dictionary/CDT in an assertion — not just integration responses.

**⚠️ CRITICAL: SAIL uses function syntax for logical operators, NOT infix operators.**

| ❌ Wrong (infix) | ✅ Correct (function) |
|------------------|----------------------|
| `x or y` | `or(x, y)` |
| `x and y` | `and(x, y)` |
| `not x` | `not(x)` |

SAIL does not support infix `or` / `and` keywords. Always use `or(expr1, expr2)` and `and(expr1, expr2)` function calls.

**⚠️ CRITICAL: Do NOT use `test!output = {}` to compare against empty lists.** Appian does not reliably handle direct equality comparison against `{}` in assertion expressions. Always use `a!isNullOrEmpty(test!output)` instead.

| ❌ Wrong | ✅ Correct |
|----------|-----------|
| `test!output = {}` | `a!isNullOrEmpty(test!output)` |
| `test!output = cast(typeof({}), {})` | `a!isNullOrEmpty(test!output)` |

**When to use test!output vs literal assertions:**
- Use **literal assertions** ("Test output matches the asserted output") only for exact value matching — strings, numbers, booleans, arrays where you know the precise expected value
- Use **test!output expressions** ("Assertion expression evaluates to true") when:
  - The exact output is dynamic but structural properties are predictable (e.g., array length)
  - You want to verify the output type without asserting the full value
  - You need to check a property of a complex return value (CDT field, list membership)
  - The rule returns data from queries where exact values vary by environment

**Important:** When using `test!output` in an assertion, the test case assertion type in Appian must be set to **"Assertion expression evaluates to true"**, NOT "Test output matches the asserted output". The expression must evaluate to a boolean `true` for the test to pass. In the XML, this uses the `<a:resultAssertions>` element (with `<a:expectedOutput xsi:nil="true"/>`), whereas literal value matching uses `<a:expectedOutput>` with a typed value.

---

## Limitations

| Scenario | Handling |
|----------|----------|
| Rule calls other expression rules | Note dependency; expected output is best-effort based on logic analysis |
| Rule queries database/record types | Mark test as "requires live data"; suggest using `evaluate_sail_expression` to validate |
| Rule uses `loggedInUser()` or context functions | Document the assumption about the user context |
| Interface (not expression rule) | Skip — interfaces require UI interaction, not unit-style tests |
| No `<definition>` element in export | Skip — object type doesn't contain SAIL code |
| CDT / Record Type inputs | ✅ Supported — use URN constructor syntax (see "Deploying Test Cases" section) |
| Nested record relationships | ✅ Supported — nest URN constructors recursively |

---

## Deploying Test Cases — Batch Deployment (One Deploy Per Package)

**CRITICAL: Always deploy all test cases in a single deployment per package.** Do NOT deploy one rule at a time — chain `rebuild_export_package` calls to build a single ZIP with all test cases, then deploy once.

### Batch Deployment Pattern

```
1. export_package(package_uuid) → get_export_results → downloads ZIP
2. extract_sail_from_export(zip) → analyze all expression rules
3. [Generate and validate test cases for all rules]
4. Chain rebuilds — one per rule that needs tests:
   rebuild_export_package(original_zip, object_name="Rule1", test_cases=[...], output_zip_path="/tmp/step1.zip")
   rebuild_export_package("/tmp/step1.zip", object_name="Rule2", test_cases=[...], output_zip_path="/tmp/step2.zip")
   rebuild_export_package("/tmp/step2.zip", object_name="Rule3", test_cases=[...], output_zip_path="/tmp/final.zip")
5. inspect_package("/tmp/final.zip") → get_inspection_results
6. deploy_package("/tmp/final.zip") → get_deployment_results
```

Each `rebuild_export_package` only modifies its target object and passes the rest through unchanged. The final ZIP contains test cases for ALL rules — deployed in one shot.

**Why batch:**
- Fewer deployments = less risk of version conflicts
- Faster — one inspect + one deploy instead of N
- Cleaner deployment history in Appian

### Tool Reference

Test cases can be deployed using `rebuild_export_package` (then inspect + deploy manually) or `refactor_and_deploy` (end-to-end for a single object). For batch, always use the chained `rebuild_export_package` approach above.

The `test_cases` array accepts entries with `name`, `description`, `inputs` (name→value map), and optional `assertions`.

### Input Value Syntax by Type

| Input Type | `xsi:type` | Value Format | Example |
|------------|-----------|--------------|---------|
| Integer | `a:Expression` | Literal number | `"1"`, `"-5"`, `"0"` |
| Text | `a:Expression` | Quoted string | `"\"hello\""` |
| Boolean | `a:Expression` | true/false | `"true"` |
| Null | `a:Expression` | null() function | `"null()"` |
| Empty list | `a:Expression` | Empty braces | `"{}"` |
| Record Type / CDT | `a:Expression` | **URN constructor** (see below) | See example |

**⚠️ IMPORTANT: Null values must use `null()`, NOT the text string `"null"`.** The text `"null"` is interpreted as a literal 4-character string, not an actual null value. Always use `null()` when you need to pass a true null to a test case input. This applies to **any data type** — when a rule input is typed as Any Type (Variant), Map, CDT, or any other type and you want to pass null, use `null()`.

### Record Type / CDT Input Syntax (CRITICAL)

For inputs typed as record types or CDTs, you **MUST** use the URN constructor syntax. Do NOT use `a!map()` or `recordType!{...}.fields.{...}` — those will fail on import.

**Special Input: brandingMap**

When a rule has an input named `brandingMap`, **do NOT hardcode a map value** like `a!map(AccentColor: "#0066CC")`. Instead, call the application's branding map loader rule to get the real branding data.

**Convention:** The branding map rule follows the pattern `rule!AS_[appPrefix]_loadBrandingMap()`.

| App Prefix | Rule to Call |
|------------|-------------|
| `PD` | `rule!AS_PD_loadBrandingMap()` |
| `GSS` | `rule!AS_GSS_loadBrandingMap()` |
| `VM` | `rule!AS_VM_loadBrandingMap()` |
| *(any app)* | `rule!AS_[appPrefix]_loadBrandingMap()` |

**In test case inputs, use:**
```
"brandingMap": "rule!AS_PD_loadBrandingMap()"
```

**Special Input: refData**

When a rule has an input named `refData`, **do NOT manually construct URN records** with hardcoded field values. Instead, query for real data.

**Strategy:**
1. **Find an existing query rule first.** Use `jarvis_get_impact_analysis` or `get_object_dependencies` (DEPENDENTS) on the Record Type to find existing query expression rules (look for rules with prefixes like `QR_`, `QE_`, `get`, `load`).
2. **If an existing query rule exists**, call it in the test input to get real records:
   ```
   "refData": "rule!AS_PD_QR_getRefData(returnType: \"OBJECT_ARRAY\")"
   ```
3. **If no query rule exists**, use `a!queryRecordType()` directly:
   ```
   "refData": "a!queryRecordType(recordType: recordType!{3aaf4c97-8663-4d73-a80c-3ed2b0cb5c3a}AS_PD_R_Data_RecordType, fields: {}, pagingInfo: a!pagingInfo(1, 10)).data"
   ```

**Correct syntax:**
```
{#"urn:appian:record-type:v1:<record-type-uuid>"(
  #"urn:appian:record-field:v1:<record-type-uuid>/<field-uuid>": "value",
  #"urn:appian:record-field:v1:<record-type-uuid>/<field-uuid>": 123,
  #"urn:appian:record-relationship:v1:<record-type-uuid>/<relationship-uuid>": {
    #"urn:appian:record-type:v1:<related-record-uuid>"(
      #"urn:appian:record-field:v1:<related-record-uuid>/<field-uuid>": "nested value"
    )
  }
)}
```

**Key rules:**
- Wrap in `{...}` for a list of records (even if just one)
- Use `#"urn:appian:record-type:v1:<uuid>"(...)` as the constructor — NOT `a!map()`
- Fields use `#"urn:appian:record-field:v1:<record-uuid>/<field-uuid>"` as keys
- Relationships use `#"urn:appian:record-relationship:v1:<record-uuid>/<relationship-uuid>"` as keys
- Nested records follow the same pattern recursively
- Use `{}` for an empty relationship (no related records)
- SAIL functions like `repeat(256, "A")` can be used as field values

**Example — full test case input for a record type with nested relationship:**
```
{#"urn:appian:record-type:v1:1d117646-bff1-4459-a61e-b7dacd8334a8"(#"urn:appian:record-field:v1:1d117646-bff1-4459-a61e-b7dacd8334a8/ae61699b-8251-4a15-be3b-4088e281f894": "Valid Title", #"urn:appian:record-field:v1:1d117646-bff1-4459-a61e-b7dacd8334a8/0e5fe885-9b8a-4050-b1cc-7cde6365e1eb": "Valid Purpose", #"urn:appian:record-relationship:v1:1d117646-bff1-4459-a61e-b7dacd8334a8/43ce205e-17ff-48df-b283-c1b0a3da9fd6": {#"urn:appian:record-type:v1:eb8b5239-6a9c-4b0e-81e3-803624d52df9"(#"urn:appian:record-field:v1:eb8b5239-6a9c-4b0e-81e3-803624d52df9/68e391bd-ea94-40e6-bb51-0738d2216ede": "Valid Question")})}
```

### Extracting URNs from SAIL Code

The SAIL definition in the export uses the same URN identifiers. Map them as follows:

| In SAIL code | Maps to in test input |
|---|---|
| `fv!item[#"urn:appian:record-field:v1:<uuid>/<field>"]` | Field key: `#"urn:appian:record-field:v1:<uuid>/<field>"` |
| `ri!sections[#"urn:appian:record-relationship:v1:<uuid>/<rel>"]` | Relationship key: `#"urn:appian:record-relationship:v1:<uuid>/<rel>"` |
| Input type `<uuid>?list` with namespace `urn:com:appian:recordtype:datatype` | Constructor: `#"urn:appian:record-type:v1:<uuid>"(...)` |

### XML Serialization

The `_update_test_cases` function in `refactor_handlers.py` handles serialization. For complex inputs (CDTs, expressions, lists), the `<a:value>` element uses `xsi:type="a:Expression"`:

```xml
<a:value xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="a:Expression">
  {#"urn:appian:record-type:v1:..."(...)}
</a:value>
```

The `_is_expression_value()` helper detects when a value needs `a:Expression` vs a literal xsd type by checking for SAIL expression indicators (`{`, `#"urn:`, `a!`, `repeat(`, etc.).

### Multi-Object Packages (CRITICAL)

When a package contains multiple expression rules, you **MUST** use the chained `rebuild_export_package` approach to deploy all test cases in a single import. Using `refactor_and_deploy` per-object will fail because each import resets the other objects in the package back to their state in the source ZIP (wiping previously deployed tests).

**The problem:** `refactor_and_deploy` modifies one object in the ZIP and imports the entire package. Objects not targeted get reimported from the original ZIP (without tests), overwriting any tests deployed in a previous call.

**The solution:** Chain `rebuild_export_package` calls — each targets a different object, passing the output ZIP as input to the next — then deploy the final ZIP once.

```
1. export_package(package_uuid="<UUID>")
2. get_export_results(export_uuid="...") → downloads ZIP to /tmp/export.zip
3. rebuild_export_package(original_zip_path="/tmp/export.zip", object_name="Rule_A", output_zip_path="/tmp/step1.zip", test_cases=[...])
4. rebuild_export_package(original_zip_path="/tmp/step1.zip", object_name="Rule_B", output_zip_path="/tmp/step2.zip", test_cases=[...])
5. rebuild_export_package(original_zip_path="/tmp/step2.zip", object_name="Rule_C", output_zip_path="/tmp/final.zip", test_cases=[...])
6. deploy_package(package_file_path="/tmp/final.zip", deployment_name="Test Cases - All Rules")
7. get_deployment_results(deployment_uuid="...") → expect "imported: N, skipped: 0, failed: 0"
```

**Key points:**
- Each `rebuild_export_package` call bumps the version UUID for its target object and injects test cases, leaving other objects untouched
- The output ZIP of step N becomes the input ZIP of step N+1, accumulating changes
- The final ZIP contains all objects with their respective test cases
- One `deploy_package` call imports everything atomically — all objects update together
- Expect `"imported": <total objects in package>` in the deployment results (not just the ones with new tests)

**When to use each approach:**

| Scenario | Approach |
|----------|----------|
| Package has 1 expression rule | `refactor_and_deploy` (single call) |
| Package has 2+ expression rules needing tests | Chained `rebuild_export_package` → single `deploy_package` |
| Adding tests to one rule in a multi-object package | Still use the chained approach (other objects pass through unchanged) |

**Verification:** After deployment, re-export and run `extract_sail_from_export` to confirm all rules show their test cases in the "Test Cases:" section.

---

## Validating Test Cases

After generating test cases, validate them against the live environment using assertion-based evaluation in a loop.

### Validation Rules

1. **Always use assertions** — the evaluator returns empty when no assertion is present. There are 3 assertion types (see below). For most test cases, use "matches asserted output" with an equality check:
   ```
   rule!RULE_NAME(param: <value>) = <expected>
   ```
   - For boolean expected: `rule!MY_RULE(input: "x") = true`
   - For text expected: `rule!MY_RULE(input: "x") = "expected text"`
   - For numeric expected: `rule!MY_RULE(input: 5) = 42`
   - For smoke tests (no expected value): `rule!MY_RULE(input: "x")` (completes without errors)
   - For dynamic expected: `rule!MY_RULE(input: "x") = fn!SOME_FUNCTION(...)` (matches expression)

2. **Interpret results:**
   - `✅ Result:` (empty/no error) = assertion PASSED
   - Any error message or `false` = assertion FAILED

3. **Run ALL test cases in parallel batches** — group by expression rule, fire all assertions for one rule simultaneously, then move to the next rule.

### Validation Loop Pattern

```
FOR each expression rule in the package:
  FOR each test case for that rule:
    evaluate_sail_expression(
      expression="rule!{RULE_NAME}({param}: {value}) = {expected}"
    )
    Record: rule name, test name, category, input, expected, result (PASS/FAIL)
  END
END
```

### Assertion Types

There are 3 types of assertions the evaluator supports:

| Assertion Type | What It Checks | Expression Pattern | Pass Condition |
|----------------|---------------|-------------------|----------------|
| **Completes without errors** | Rule executes without throwing an error | `rule!RULE_NAME(param: value)` | No error in response (note: result will appear empty) |
| **Matches asserted output** | Rule output equals an expected value | `rule!RULE_NAME(param: value) = expectedValue` | Assertion evaluates to true (no error returned) |
| **Matches expression** | Rule output equals another expression's result | `rule!RULE_NAME(param: value) = fn!OTHER_FUNCTION(...)` | Both sides evaluate to the same value |

**Which to use:**
- Use **"matches asserted output"** (default/most common) — when you know the exact expected value. This should be the go-to for expression rules.
- Use **"matches expression"** — when the expected value is dynamic or computed (e.g., comparing against `today()`, `loggedInUser()`, or another rule)
- Use **"completes without errors"** (last resort) — only when an assertion genuinely cannot be made, e.g., the rule returns a complex CDT from live data where the exact output is unpredictable. For expression rules, this should rarely be needed.

**Interpreting results:**
- `✅ Result:` (empty/no error) = assertion PASSED (or rule completed without error for type 1)
- Error message or explicit `false` = assertion FAILED

### Presenting Results — Per-Rule Grid Format

After all validations complete, present results as **one grid per expression rule**, not a single combined table. This keeps results focused and readable.

**Format for each rule:**

```
## RULE_NAME

| # | Test Case | Category | Input | Expected | Result |
|---|-----------|----------|-------|----------|--------|
| 1 | Happy Path - description | happy-path | param: "value" | true | ✅ PASS |
| 2 | Null Handling - description | null-handling | param: null | false | ✅ PASS |
| 3 | Edge Case - description | edge-case | param: "bad" | "UNKNOWN" | ❌ FAIL |

**X passed, Y failed**
```

**Grid rules:**
- **One grid per expression rule** — each rule gets its own header and table
- One row per test case assertion
- Sort by test case order within each rule
- Show ✅ PASS or ❌ FAIL in the Result column
- End each grid with a per-rule totals line: `X passed, Y failed`
- If any test FAILS, show the failing expression and actual vs expected below that rule's grid
- After all rule grids, show an overall summary: `Overall: X passed, Y failed across N expression rules`

### Example Validation Run

For `RS_expressionRule_integer_easy` with input `score: 95`, expected `"A"`:

```
evaluate_sail_expression(expression="rule!RS_expressionRule_integer_easy(score: 95) = \"A\"")
→ ✅ Result:  (no error = PASS)
```

For a failing case where expected was wrong:
```
evaluate_sail_expression(expression="rule!RS_expressionRule_integer_easy(score: 89) = \"A\"")
→ ❌ Error: Expression evaluated to false
```

### Example Output

After running all validations, present results like this:

---

## RS_expressionRule_validEmail_easy

| # | Test Case | Category | Input | Expected | Result |
|---|-----------|----------|-------|----------|--------|
| 1 | Happy Path - Valid email | happy-path | email: "user@example.com" | true | ✅ PASS |
| 2 | Null Handling - Null email | null-handling | email: null | false | ✅ PASS |
| 3 | Null Handling - Empty string | null-handling | email: "" | false | ✅ PASS |
| 4 | Edge Case - Missing @ | edge-case | email: "userexample.com" | false | ✅ PASS |
| 5 | Edge Case - @ at position 1 | edge-case | email: "@example.com" | false | ✅ PASS |
| 6 | Boundary - Dot at last position | boundary | email: "user@example." | false | ✅ PASS |

**6 passed, 0 failed**

---

## RS_expressionRule_string_easy

| # | Test Case | Category | Input | Expected | Result |
|---|-----------|----------|-------|----------|--------|
| 1 | Happy Path - Engineering | happy-path | department: "Engineering" | "ENG-001" | ✅ PASS |
| 2 | Happy Path - Human Resources | happy-path | department: "Human Resources" | "HR-004" | ✅ PASS |
| 3 | Edge Case - Unrecognized dept | edge-case | department: "Legal" | "UNKNOWN" | ✅ PASS |
| 4 | Null Handling - Null dept | null-handling | department: null | "UNKNOWN" | ✅ PASS |
| 5 | Edge Case - Case sensitivity | edge-case | department: "engineering" | "UNKNOWN" | ✅ PASS |

**5 passed, 0 failed**

---

## RS_expressionRule_integer_easy

| # | Test Case | Category | Input | Expected | Result |
|---|-----------|----------|-------|----------|--------|
| 1 | Happy Path - Score 95 | happy-path | score: 95 | "A" | ✅ PASS |
| 2 | Boundary - Score 90 | boundary | score: 90 | "A" | ✅ PASS |
| 3 | Boundary - Score 89 | boundary | score: 89 | "B" | ✅ PASS |
| 4 | Happy Path - Score 72 | happy-path | score: 72 | "C" | ✅ PASS |
| 5 | Happy Path - Score 59 | happy-path | score: 59 | "F" | ✅ PASS |
| 6 | Edge Case - Score 0 | edge-case | score: 0 | "F" | ✅ PASS |
| 7 | Edge Case - Negative score | edge-case | score: -5 | "F" | ✅ PASS |

**7 passed, 0 failed**

---

**Overall: 18 passed, 0 failed across 3 expression rules**
