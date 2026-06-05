# i18n Audit Workflow

Audit Appian interfaces and expression rules for internationalization compliance. Detects hard-coded text, missing translations, wrong prefixes, stale keys, and other i18n violations.

---

## Triggers

Activate this skill when the user asks:
- "Audit this interface for i18n"
- "Check if there's hard-coded text in this object"
- "Are all labels internationalized?"
- "Find i18n violations in GSS"
- "What keys are stale?"
- "Check i18n compliance for this package"
- "Are there missing translations?"

---

## Audit Types

### Audit 1: Hard-Coded Text Detection

Detect user-facing text that is NOT internationalized (hard-coded strings instead of i18n keys).

**Step 1 — Get the interface SAIL code:**
```
jarvis_get_object_content(parentFolderId: <kbFolderId>, objectName: "<INTERFACE_NAME>")
```

**Step 2 — Scan for violations:**

Look for quoted strings in these parameters (these should use i18n):
- `label:` — field labels
- `labelPosition:` — skip (this is a constant like "ABOVE")
- `instructions:` — instruction text
- `helpTooltip:` — help text
- `placeholder:` — placeholder text
- `buttonLabel:` — button text
- `text:` (in richTextItem) — display text
- `confirmButtonLabel:` / `cancelButtonLabel:` — dialog buttons
- `emptyGridMessage:` — empty state text
- `validationGroup:` — skip (not user-facing)

**What IS a violation:**
- `label: "Vendor Name"` — hard-coded label
- `instructions: "Enter the vendor's legal name"` — hard-coded instruction
- `text: "No results found"` — hard-coded display text

**What is NOT a violation:**
- `label: rule!AS_CO_I18N_UT_displayLabel(...)` — properly internationalized
- `label: translation!Vendor Name` — properly internationalized
- `labelPosition: "ABOVE"` — not user-facing text, it's a constant
- `value: local!vendor.name` — data, not display text
- `label: ""` — intentionally blank
- `showWhen: true` — not text

**Step 3 — Report findings:**
```
🔍 i18n Audit: AS_GSS_FM_vendorForm

  ❌ Hard-coded text found (3 violations):
    1. label: "Vendor Score" (line ~45) → should be lbl_VendorScore
    2. instructions: "Enter a value between 0 and 100" (line ~47) → should be ins_VendorScoreRange
    3. helpTooltip: "This is the confidence score" (line ~48) → should be hlp_VendorScore

  ✅ Properly internationalized (12 labels):
    - Uses rule!AS_CO_I18N_UT_displayLabel throughout
    - Bundle data loaded at top level ✓

  💡 Suggested keys for violations:
    Bundle: AS.GSS.General
    1. lbl_VendorScore = "Vendor Score"
    2. ins_VendorScoreRange = "Enter a value between 0 and 100"
    3. hlp_VendorScore = "This is the confidence score"
```

---

### Audit 2: Key Prefix Validation

Check that all keys in a bundle follow the prefix convention.

```sql
SELECT k.keyname, k.enuslabel, b.bundlename
FROM Appian.BND_Key k
JOIN Appian.BND_Bundle b ON k.bundleid = b.bundleid
JOIN Appian.SMT_Application a ON b.appid = a.appid
WHERE a.appdbtableprefix = '<APP_PREFIX>'
AND k.isdeleted = 0
AND k.keyname NOT REGEXP '^(acs_|btn_|cpt_|hlp_|ins_|lbl_|plc_|txt_|vld_)'
ORDER BY b.bundlename, k.keyname
LIMIT 30
```

**Report:**
```
🔍 Prefix Audit: AS_GSS

  ❌ Keys with invalid/missing prefix (2 found):
    Bundle: AS.GSS.General
    1. "vendorName" = "Vendor Name" → should be lbl_VendorName
    2. "cancelButton" = "Cancel" → should be btn_Cancel

  ✅ 754 keys have valid prefixes
```

---

### Audit 3: Stale Keys

Find keys where the English label was updated but translations haven't been refreshed.

```sql
SELECT k.keyname, k.enuslabel, b.bundlename, k.addedon
FROM Appian.BND_Key k
JOIN Appian.BND_Bundle b ON k.bundleid = b.bundleid
JOIN Appian.SMT_Application a ON b.appid = a.appid
WHERE a.appdbtableprefix = '<APP_PREFIX>'
AND k.isstale = 1
AND k.isdeleted = 0
ORDER BY b.bundlename, k.keyname
LIMIT 50
```

**Report:**
```
🔍 Stale Keys: AS_GSS

  ⚠️ 5 stale keys found (translations need updating):

  Bundle: AS.GSS.General
    1. lbl_EvaluationStatus = "Evaluation Status" (stale since 2021-11-15)
    2. txt_PendingReview = "Pending Review" (stale since 2021-11-20)

  Bundle: AS.GSS.TMG.Tasks
    3. lbl_TaskDueDate = "Task Due Date" (stale since 2021-12-01)
    4. ins_TaskOverdue = "This task is overdue" (stale since 2021-12-01)
    5. vld_DueDateRequired = "Due date is required" (stale since 2021-12-01)
```

---

### Audit 4: Duplicate Labels

Find keys with the same English label text (potential consolidation opportunity).

```sql
SELECT k.enuslabel, COUNT(*) as duplicate_count, 
       GROUP_CONCAT(CONCAT(b.bundlename, '.', k.keyname) SEPARATOR ', ') as keys
FROM Appian.BND_Key k
JOIN Appian.BND_Bundle b ON k.bundleid = b.bundleid
JOIN Appian.SMT_Application a ON b.appid = a.appid
WHERE a.appdbtableprefix = '<APP_PREFIX>'
AND k.isdeleted = 0
GROUP BY k.enuslabel
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC
LIMIT 20
```

**Report:**
```
🔍 Duplicate Labels: AS_GSS

  ⚠️ 3 labels appear in multiple keys:

  1. "Cancel" (3 occurrences):
     - AS.GSS.General.btn_Cancel
     - AS.GSS.General.txt_StatusCancelled  ← different meaning, OK
     - AS.GSS.TMG.Tasks.btn_CancelTask     ← could reuse btn_Cancel?

  2. "Save" (2 occurrences):
     - AS.GSS.General.btn_Save
     - AS.GSS.General.btn_SaveAndClose     ← different, OK
```

---

### Audit 5: Missing Translations (Translation Sets)

For apps using Translation Sets, check if all strings have values for all configured locales.

```
jarvis_get_translation(parentFolderId: <kbFolderId>, query: "<uuid>", locale: "all")
```

Compare the returned locales against the translation set's configured locales. Flag any strings missing values for configured locales.

---

### Audit 6: Bundle Loading Pattern

Check if bundle data is loaded correctly (at top level, not in child interfaces).

**Step 1 — Get the interface SAIL:**
```
jarvis_get_object_content(parentFolderId: <kbFolderId>, objectName: "<INTERFACE_NAME>")
```

**Step 2 — Check for violations:**
- If the interface calls `loadBundleFromFolder` AND it's not a top-level form (FM_ prefix) → violation
- If the interface is a section (SCT_) or component (CPS_) and loads bundle data → violation
- Top-level forms (FM_) SHOULD load bundle data — that's correct

**Report:**
```
🔍 Bundle Loading Audit: AS_GSS_SCT_vendorDetails

  ❌ Bundle data loaded inside a section interface
     This should receive bundleData as a rule input, not load it internally.
     
  Fix: Add ri!bundleData input and remove the loadBundleFromFolder call.
```

---

## Presentation Rules

- Always show the bundle name for every key mentioned
- Group violations by severity: ❌ (must fix) vs ⚠️ (should fix) vs 💡 (suggestion)
- For hard-coded text violations, suggest the correct key name and bundle
- Show counts: "3 violations found out of 15 labels checked"
- If no violations found: "✅ All labels properly internationalized"
