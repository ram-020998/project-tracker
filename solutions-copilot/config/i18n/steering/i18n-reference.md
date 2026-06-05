# Internationalization (i18n) — Complete Reference

This document is the authoritative reference for the jarvis-i18n power. All i18n skills load this file as context. It contains everything the agent needs to work with both BND (Bundle Management) and Appian Translation Sets correctly.

---

## 1. Overview

Appian applications use two internationalization systems. The choice depends on the application:

| System | Used By | How It Works |
|---|---|---|
| **BND (Bundle Management)** | Older apps (GSS, AM, RM, GCW, VM) | Keys stored in DB → synced to .properties files → loaded via `AS_CO_I18N_UT_displayLabel()` |
| **Appian Translation Sets** | Newer apps (GSM, future apps) | Native Appian objects → referenced via `translation!String Name(var: value)` |

**How to determine which system an app uses:**
1. Check `get_jarvis_config` response → if `translationSets` array is populated → Translation Sets
2. If `translationSets` is empty → BND
3. Future: an `internationalization` field in the app config will explicitly state "BND" or "TRANSLATION_SET" or "BOTH"

**CRITICAL RULE:** Every response must include the **bundle name** (for BND) or **translation set name** (for Translation Sets). The developer must always know exactly where a key lives.

---

## 2. BND (Bundle Management) System

### How It Works

```
1. Developer adds key via BND UI (DEV_TOOLS_newi18nToBnd interface)
2. Key stored in BND_Key table with: keyName, enUsLabel, context, arguments
3. BND Process Keys PM: writes to DB → auto-translates → syncs to .properties files
4. At runtime: AS_CO_I18N_UT_loadBundleFromFolder() loads .properties into a dictionary
5. Dictionary passed as "i18nData" / "bundleData" to child interfaces
6. AS_CO_I18N_UT_displayLabel(i18nData, bundleKey, arguments) returns localized text
```

### Key Naming Convention (CRITICAL)

All BND keys MUST use these prefixes:

| Prefix | Purpose | Example |
|---|---|---|
| `acs_` | Accessibility text (screen reader, ARIA labels) | `acs_Cancel` = "Press Enter to cancel changes" |
| `btn_` | Button labels | `btn_Cancel` = "Cancel" |
| `cpt_` | Captions (image captions, chart titles) | `cpt_VendorMetrics` = "Vendor Performance Metrics" |
| `hlp_` | Help tooltips | `hlp_VendorCategory` = "Select the primary business category" |
| `ins_` | Instruction text | `ins_Cancel` = "Do you want to cancel?" |
| `lbl_` | Labels (field labels, section headers) | `lbl_VendorName` = "Vendor Name" |
| `plc_` | Placeholder text | `plc_EnterVendorName` = "Enter vendor name" |
| `txt_` | General text (body text, descriptions, status) | `txt_StatusCancelled` = "Cancelled" |
| `vld_` | Validation messages | `vld_VendorNameRequired` = "Vendor name is required" |

### Key Name Format

- PascalCase after the prefix: `lbl_VendorName`, `btn_SaveAndClose`, `acs_UploadDocuments`
- Descriptive — the name should tell you what the label says without looking it up
- No spaces, no special characters

### Key ID Format (Internal)

```
keyId = "<bundleId>|<devPhaseId>|<keyName_lowercase>"

Example: "13|26|lbl_vendorname"
  - bundleId: 13 (AS.GSS.General)
  - devPhaseId: 26 (GSS v1.2)
  - keyName: lbl_vendorname (lowercased)
```

### Bundles

Each application has multiple bundles organized by functional area:

| Bundle Pattern | Purpose |
|---|---|
| `AS.<APP>.General` | App-wide labels (buttons, common text, statuses) — the main bundle |
| `AS.<APP>.TMG.Tasks` | Task management labels |
| `AS.<APP>.TMG.TaskBehaviorType` | Task behavior type labels |
| `AS.<APP>.TMG.TaskChecklist` | Task checklist labels |
| `AS.<APP>.TMG.DueDateCalculationRule` | Due date calculation labels |
| `AS.<APP>.QNM.Question` | Questionnaire question labels |
| `AS.<APP>.QNM.Questionnaire` | Questionnaire labels |
| `AS.<APP>.QNM.QuestionnaireSettings` | Questionnaire settings labels |
| `AS.<APP>.ADT.AuditHistory` | Audit history labels |
| `AS.<APP>.Portal` | Vendor/external portal labels |
| `AS.<APP>.MSG.AllBundles` | Messaging labels |
| `AS.<APP>.StateAndLocalGovernment` | State/local government specific labels |
| `AS.CO.CommonObjects` | Cross-application common labels |

**How to choose the right bundle for a new key:**
- Common labels (Cancel, Save, Back, Next, etc.) → `AS.<APP>.General`
- Feature-specific labels → match the bundle to the feature area (QNM, TMG, Portal, etc.)
- If unsure → ask the developer which feature area the key belongs to

### Arguments in Labels

Labels can contain arguments (dynamic values) using `{0}`, `{1}`, etc.:

```
Key: txt_AssignedTo
Label: "Assigned to {0} on {1}"
Arguments: 2 (username, date)

Usage: rule!AS_CO_I18N_UT_displayLabel(
  i18nData: local!bundleData,
  bundleKey: "txt_AssignedTo",
  arguments: {loggedInUser(), today()}
)
```

### How displayLabel Works

```sail
rule!AS_CO_I18N_UT_displayLabel(
  i18nData: ri!i18nData,      /* Dictionary loaded from .properties file */
  bundleKey: ri!bundleKey,     /* Key name like "lbl_VendorName" or "bundleName.lbl_VendorName" */
  arguments: ri!arguments      /* Optional: list of values to substitute {0}, {1}, etc. */
)
```

The rule:
1. Parses the bundleKey (splits on "." if it contains a bundle name prefix)
2. Looks up the key in the i18nData dictionary
3. If not found → returns the bundleKey itself (for debugging)
4. If arguments provided → replaces {0}, {1}, etc. with argument values
5. Returns the localized text string

### Loading Bundle Data

Bundle data is loaded ONCE at the top-level interface and passed down:

```sail
a!localVariables(
  local!bundleData: rule!AS_CO_I18N_UT_loadBundleFromFolder(
    bundleFolder: cons!AS_GSS_I18N_FLD_BUNDLE_FILES,
    bundleNames: {"AS.GSS.General", "AS.GSS.TMG.Tasks"},
    localeAgnostic: false
  ),
  
  /* Pass to all child interfaces */
  rule!AS_GSS_SCT_VendorDetails(
    bundleData: local!bundleData,
    ...
  )
)
```

**NEVER load bundle data inside child interfaces** — this causes duplicate queries and performance issues.

### Database Tables

| Table | Purpose | Key Columns |
|---|---|---|
| `BND_Bundle` | Bundle definitions | `bundleid`, `appid`, `bundlename`, `bundlefolderid` |
| `BND_Key` | The actual keys | `keyid`, `bundleid`, `devphaseid`, `keyname`, `enuslabel`, `context`, `arguments`, `argumentcount`, `isdeleted`, `isstale` |
| `BND_Key_TranslateAuto` | Auto-translated values | `keytranslateid`, `keyid`, `locale`, `label` |
| `BND_Key_TranslateManual` | Manual translation overrides | `keytranslateid`, `keyid`, `locale`, `label` |
| `BND_AppConfig` | Per-app i18n config | `appid`, `islocaleagnostic`, `autotranslatelocales`, `manualtranslatelocales` |

### Key SQL Queries for BND

```sql
-- Find all bundles for an app
SELECT b.bundleid, b.bundlename, COUNT(k.keyid) as key_count
FROM Appian.BND_Bundle b
LEFT JOIN Appian.BND_Key k ON b.bundleid = k.bundleid AND k.isdeleted = 0
JOIN Appian.SMT_Application a ON b.appid = a.appid
WHERE a.appdbtableprefix = '<APP_PREFIX>'
GROUP BY b.bundleid, b.bundlename
ORDER BY b.bundlename
LIMIT 20

-- Search for a key across all bundles for an app
SELECT k.keyname, k.enuslabel, b.bundlename, k.context, k.arguments
FROM Appian.BND_Key k
JOIN Appian.BND_Bundle b ON k.bundleid = b.bundleid
JOIN Appian.SMT_Application a ON b.appid = a.appid
WHERE a.appdbtableprefix = '<APP_PREFIX>'
AND (k.keyname LIKE '%<SEARCH>%' OR k.enuslabel LIKE '%<SEARCH>%')
AND k.isdeleted = 0
ORDER BY b.bundlename, k.keyname
LIMIT 30

-- Look up a specific key by name
SELECT k.keyname, k.enuslabel, b.bundlename, k.context, k.arguments, k.argumentcount
FROM Appian.BND_Key k
JOIN Appian.BND_Bundle b ON k.bundleid = b.bundleid
WHERE k.keyname = '<KEY_NAME>'
AND k.isdeleted = 0
LIMIT 5

-- Find stale keys (translations need updating)
SELECT k.keyname, k.enuslabel, b.bundlename
FROM Appian.BND_Key k
JOIN Appian.BND_Bundle b ON k.bundleid = b.bundleid
JOIN Appian.SMT_Application a ON b.appid = a.appid
WHERE a.appdbtableprefix = '<APP_PREFIX>'
AND k.isstale = 1
AND k.isdeleted = 0
ORDER BY b.bundlename, k.keyname
LIMIT 50

-- Check if a key already exists (duplicate detection)
SELECT k.keyname, k.enuslabel, b.bundlename
FROM Appian.BND_Key k
JOIN Appian.BND_Bundle b ON k.bundleid = b.bundleid
JOIN Appian.SMT_Application a ON b.appid = a.appid
WHERE a.appdbtableprefix = '<APP_PREFIX>'
AND k.enuslabel = '<EXACT_LABEL_TEXT>'
AND k.isdeleted = 0
LIMIT 10
```

---

## 3. Appian Translation Sets (Native)

### How It Works

```
1. Developer creates a Translation Set object in Appian Designer (1 per app typically)
2. Adds Translation Strings to the set (each with a primary locale value + optional other locales)
3. References strings in SAIL via: translation!String Name(var: value)
4. At runtime: Appian resolves the translation string to the user's locale automatically
5. No manual loading needed — it's handled by the platform
```

### Key Differences from BND

| Aspect | BND | Translation Sets |
|---|---|---|
| Loading | Manual — `loadBundleFromFolder()` at top level | Automatic — platform resolves at runtime |
| Reference | `rule!AS_CO_I18N_UT_displayLabel(bundleData, key)` | `translation!String Name(var: value)` |
| Variables | `{0}`, `{1}` positional | `{varName}` named, keyword syntax |
| Rich text | Not supported | Supported — variables can be `a!richTextItem()` |
| Naming | Prefix convention (lbl_, btn_, etc.) | Free-form (but prefix convention still recommended) |
| Limit | No hard limit | 5,000 strings per translation set |
| Duplicate detection | None built-in | Built-in — warns on same primary locale value |
| Bulk creation | Manual via BND UI | "Generate from interface" — auto-detects all display text |

### Translation String Reference Syntax

```sail
/* Simple string */
translation!Save

/* String with named variables */
translation!Assigned to {name} on {date}(
  name: loggedInUser(),
  date: today()
)

/* String with rich text variable */
translation!Case submitted by {name}(
  name: a!richTextItem(
    text: loggedInUser(),
    style: "STRONG"
  )
)
```

### Translation Set Properties

Each translation set has:
- **Name** — follows app naming (e.g., `AS_GSM_TranslationSet`)
- **Translation locales** — which languages are supported (e.g., en-US, de, fr-FR, ja)
- **Primary translation locale** — the default/required locale (usually en-US)
- **UUID** — unique identifier for programmatic access

Each translation string has:
- **Value** — the text for each locale
- **Description** — context for developers (which component uses this)
- **Notes for Translator** — context for translators
- **Translation Variables** — named dynamic values in `{}`
- **UUID** — unique identifier

### Accessing Translation Sets via JARVIS

Use `jarvis_get_translation` tool:

```
jarvis_get_translation(parentFolderId: <kbFolderId>, query: "Search", locale: "")
→ Returns all translation strings matching "Search" with their UUIDs and text

jarvis_get_translation(parentFolderId: <kbFolderId>, query: "<uuid>", locale: "all")
→ Returns all locale values for a specific translation string

jarvis_get_translation(parentFolderId: <kbFolderId>, query: "<uuid>", locale: "fr-FR")
→ Returns the French translation for a specific string
```

### Translation Sets in App Config

From `get_jarvis_config`, apps with Translation Sets show:
```json
{
  "translationSets": [
    {
      "name": "AS_GSM_CO_TranslationSet",
      "description": "Translation Set for AS GSM CO rules and interfaces",
      "id": 21,
      "uuid": "b549b54a-404f-438c-9c43-53d4b44074cb"
    },
    {
      "name": "AS_GSM_TranslationSet",
      "description": "Translation Set for GSM",
      "id": 20,
      "uuid": "24be3129-52d3-4ff1-9d5f-6cf395fdc06b"
    }
  ]
}
```

---

## 4. Best Practices (Both Systems)

### From the SOLUTIONS Best Practices Checklist (Section 9)

1. **All display text must be internationalized** — no hard-coded strings in interfaces
2. **Bundle data loaded at top-level parent interface and passed down** — never load inside child components
3. **Use `AS_<APP>_I18N_UT_displayLabel`** (BND) or `translation!` domain (Translation Sets) — never `index()` directly
4. **Correct prefixes** — acs, btn, cpt, hlp, ins, lbl, plc, txt, vld
5. **Separate bundle files by area of functionality** — don't put everything in one bundle
6. **Separate label for each instance of display text** — don't reuse generic keys across different contexts
7. **No concatenation of multiple labels** — use arguments instead of string concatenation
8. **No constants for text that should be internationalized** — use i18n bundles, not constants

### Common Violations to Detect

| Violation | How to Detect |
|---|---|
| Hard-coded text | Interface SAIL contains quoted strings in label/instruction/tooltip parameters |
| Wrong prefix | Key name doesn't start with a valid prefix (acs_, btn_, cpt_, hlp_, ins_, lbl_, plc_, txt_, vld_) |
| Label concatenation | SAIL contains `& " " &` or `concat()` with multiple displayLabel calls |
| Duplicate key | Same `enuslabel` text exists in multiple keys within the same app |
| Missing translation | Key exists in en-US but not in other configured locales |
| Stale key | `isstale = 1` in BND_Key — source label changed but translations not updated |
| Bundle loaded in child | `loadBundleFromFolder` called inside a non-top-level interface |

---

## 5. Relationship to JARVIS

### How jarvis-i18n Uses JARVIS Tools

| Tool | Used For |
|---|---|
| `query_sql` | Read BND tables (BND_Key, BND_Bundle, BND_AppConfig) |
| `jarvis_get_translation` | Look up/search Translation Set strings |
| `jarvis_get_object_content` | Read interface SAIL to detect hard-coded text |
| `get_jarvis_config` | Determine which i18n system an app uses (translationSets field) |
| `jarvis_search_objects` | Find i18n-related objects (displayLabel rules, bundle constants) |

### When JARVIS Should Invoke jarvis-i18n

- During **code review** — check that interfaces use i18n correctly
- During **implementation** — when creating new interfaces, suggest proper i18n keys
- During **design** — when a design doc mentions new user-facing text, note that i18n keys will be needed
