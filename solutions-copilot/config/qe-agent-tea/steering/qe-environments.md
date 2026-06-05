# QE Environments & Credentials Lookup

## Source of Truth

All test environments, URLs, and credentials are maintained in this Google Sheet:

**Sheet ID:** `1lOEWVzGm9GU1vWUf6HWOGuFXq4mIfR0WLLNM00WK7hc`
**URL:** https://docs.google.com/spreadsheets/d/1lOEWVzGm9GU1vWUf6HWOGuFXq4mIfR0WLLNM00WK7hc/edit

---

## How to Look Up Environments & Credentials

When testing any solution, follow this process:

### Step 1: Identify the Solution

| Solution | Sheet Tab Name | Atlas App Name |
|----------|---------------|----------------|
| GSS (Source Selection) | `GSS Sites Users` | `SourceSelection` |
| GCM (Clause Automation / GCA) | `GCM Sites Users` | `ClauseAutomation` |
| GCW (Contract Writing) | `GCW Sites Users` | `ContractWriting` |
| AM (Award Management) | `AM Sites Users` | `AwardManagement` |
| RM (Requirements Management) | `RM Sites Users` | `RequirementsManagement` |
| VM (Vendor Management) | `VM Sites Users` | `VendorManagement` |
| SA (Source Analysis) | `SA Sites Users` | `ProcureSightEnterprise` |
| UAM (User Access Management) | `UAM Site Users` | `UserAccessManagement` |
| GAM Suite | `GAM Suite Users` | `GamSuiteModule` |

### Step 2: Read the Credentials Sheet

Use the Google Workspace MCP to read the appropriate tab:

```
Tool: read_sheet_values
Spreadsheet ID: 1lOEWVzGm9GU1vWUf6HWOGuFXq4mIfR0WLLNM00WK7hc
Range: <Tab Name>!A1:F50
```

**Example for GSS:**
```
read_sheet_values(spreadsheet_id="1lOEWVzGm9GU1vWUf6HWOGuFXq4mIfR0WLLNM00WK7hc", range_name="GSS Sites Users!A1:F50")
```

**Example for GCM:**
```
read_sheet_values(spreadsheet_id="1lOEWVzGm9GU1vWUf6HWOGuFXq4mIfR0WLLNM00WK7hc", range_name="GCM Sites Users!A1:F50")
```

### Step 3: Read the Environments Tab for URLs

The `Environments` tab contains all site URLs with their types:

```
read_sheet_values(spreadsheet_id="1lOEWVzGm9GU1vWUf6HWOGuFXq4mIfR0WLLNM00WK7hc", range_name="Environments!A1:D50")
```

### Step 4: Match Environment to Credentials

The credentials tabs are structured as:

```
Row 1-2: Instructions (highlight colors)
Row 3: Empty
Row 4+: [Environment Name] | [Role] | [Username] | [Password]
```

- The first column contains the environment name (e.g., "GSS Test2", "GCM Test2")
- Subsequent rows under the same environment have empty first column — they belong to the same environment
- A blank row separates different environments

### Step 5: Environment Selection Priority

**Always use the environment defined in the solution's QE Knowledge Base steering file.** Each solution KB specifies its test environment — use that as the source of truth:

- **RM tickets** → Use the environment from `qe-knowledge-base-RM.md` (Section 2)
- **GSS tickets** → Use the environment from `qe-knowledge-base-GSS.md` (Section 2)
- **AIDC tickets** → Use the environment from `qe-knowledge-base-AIDC.md` (Section 2)

**CI/CD Pipeline Rule:** Whenever a ticket is in the "Verification & Validation" queue, it means the changes have already been deployed to the Test environments via CI. Packages deployed to Dev2 automatically propagate to Test environments. Therefore, always test on the Test environment specified in the solution KB — never on Dev2.

**NEVER use Dev2 for verification testing.** Dev2 is a development environment, not a test environment. Even if the Pull Request field points to a Dev2 URL, that is irrelevant for determining where to test.

**Fallback order (only if the primary KB-specified environment is down):**

1. **Solution-specific test site** (from the solution's QE Knowledge Base) — always use this
2. **Combined MariaDB Test Site** — fallback if solution-specific site is unavailable
3. **Combined Oracle Test Site** — fallback for Oracle-specific testing

---

## Environment URL Patterns

| Domain Pattern | Access |
|----------------|--------|
| `*.appianpreview.com` | Accessible externally (use this) |
| `*.eng-appiancloud.com` | Internal only (may not resolve externally) |
| `*.appiancloud.com` | Legacy/deprecated sites |

**Always try `.appianpreview.com` first.** If the sheet shows `.eng-appiancloud.com`, try replacing with `.appianpreview.com`.

---

## Credential Troubleshooting

1. **If login fails:** Try other users from the same environment section in the sheet.
2. **Password patterns:** Common passwords are `appian21`, `appian22`, `appian23`, `appian24`, `appian25`, `appian2021`.
3. **Sheet may be stale:** The sheet notes say "highlight confirmed passwords in green" and "incorrect passwords in red" — not all passwords may be current.
4. **Newline characters:** Some passwords in the sheet have trailing `\n` — strip these before using.

---

## Shared/Combined Environments

Some environments have all solutions deployed together:

| Environment | URL | Password | Solutions |
|-------------|-----|----------|-----------|
| Combined MariaDB Test | `eng-test-fed-aq-test2.appianpreview.com` | appian2021 | AM, RM, GSS, GCM, GCW, VM |
| Combined Oracle Test | `eng-test-fed-aq-test2-oracle.appianpreview.com` | varies | AM, RM, GSS, GCM, GCW, VM |
| Demo | `eng-test-fed-aq-demo.appianpreview.com` | varies | All solutions |

**Note:** Dev 2 (`eng-test-fed-aq-dev2.appianpreview.com`) is a development environment only. Do NOT use it for verification testing. Changes deployed to Dev2 automatically propagate to Test environments via CI.

---

## Other Credential Sources

| Source | Tab Name | Use Case |
|--------|----------|----------|
| API Keys | `API Keys` | REST API testing |
| Suite API Keys | `Suite API Keys` | Suite-level API access |
| EPU Admins | `EPU Admins` | Admin/deployment operations |
| Auto Site Users | `Auto Site Users` | Automation framework users |

---

## Rules

- **Never hardcode credentials** in steering files or test scripts — always look them up from the sheet.
- **Always verify login works** before proceeding with test execution.
- **If a credential fails**, try the next user in the same role from the sheet before escalating.
- **Document working credentials** in test execution reports so the team knows which ones are current.
