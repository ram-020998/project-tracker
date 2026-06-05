# i18n Create Workflow

Generate new internationalization keys following the team's conventions. This skill produces the key name, label, and bundle assignment — ready for the developer to add via the BND UI or Appian Designer.

---

## Triggers

Activate this skill when the user asks:
- "Create an i18n key for 'Vendor Score'"
- "I need a label for a new Save button"
- "Generate bundle keys for this interface"
- "What should I name this i18n key?"
- "Suggest keys for these labels"

---

## Step 1: Determine the i18n System

Check `get_jarvis_config` for the target app:
- If `translationSets` populated → generate for Translation Sets (simpler — just the text value)
- If `translationSets` empty → generate for BND (key name + label + bundle assignment)

---

## Step 2: Gather Context

Ask or infer:
1. **Which app?** (determines prefix and available bundles)
2. **What's the English text?** (the label the user will see)
3. **What type of text is it?** (button, label, instruction, validation, etc.) → determines prefix
4. **Which feature area?** (determines which bundle) — if not obvious, ask

---

## Step 3: Check for Duplicates (CRITICAL)

Before generating a new key, ALWAYS check if the label already exists:

**For BND:**
```sql
SELECT k.keyname, k.enuslabel, b.bundlename
FROM Appian.BND_Key k
JOIN Appian.BND_Bundle b ON k.bundleid = b.bundleid
JOIN Appian.SMT_Application a ON b.appid = a.appid
WHERE a.appdbtableprefix = '<APP_PREFIX>'
AND k.enuslabel = '<EXACT_TEXT>'
AND k.isdeleted = 0
LIMIT 10
```

**For Translation Sets:**
```
jarvis_get_translation(parentFolderId: <kbFolderId>, query: "<EXACT_TEXT>", locale: "")
```

If a match is found:
```
⚠️ This label already exists:
  Bundle: AS.VM.General
  Key: btn_Cancel = "Cancel"

Do you want to reuse this existing key, or create a new one?
(Creating a new one is valid if the context is different — e.g., "Cancel" on a form vs "Cancel" on a dialog)
```

---

## Step 4: Generate the Key (BND)

### Determine the Prefix

| If the text is for... | Use prefix |
|---|---|
| A button | `btn_` |
| A field label | `lbl_` |
| A placeholder in an input field | `plc_` |
| An instruction or guidance text | `ins_` |
| A help tooltip | `hlp_` |
| A validation/error message | `vld_` |
| Accessibility/screen reader text | `acs_` |
| A caption (chart, image) | `cpt_` |
| General text (status, description, body) | `txt_` |

### Determine the Key Name

Rules:
- PascalCase after prefix: `lbl_VendorScore`, `btn_SaveAndClose`
- Descriptive — should tell you what it says without looking up the label
- Match existing patterns in the same bundle

**Research existing patterns first:**
```sql
SELECT k.keyname FROM Appian.BND_Key k
JOIN Appian.BND_Bundle b ON k.bundleid = b.bundleid
WHERE b.bundlename = '<TARGET_BUNDLE>'
AND k.keyname LIKE '<PREFIX>%'
AND k.isdeleted = 0
ORDER BY k.keyname
LIMIT 20
```

Look at how existing keys are named and follow the same style.

### Determine the Bundle

| If the key is... | Assign to bundle |
|---|---|
| Common (Cancel, Save, Back, Next, Close, Confirm, Delete, Update) | `AS.<APP>.General` |
| Task management related | `AS.<APP>.TMG.Tasks` |
| Questionnaire related | `AS.<APP>.QNM.*` (pick the specific sub-bundle) |
| Portal/external user facing | `AS.<APP>.Portal` |
| Audit related | `AS.<APP>.ADT.AuditHistory` |
| Feature-specific but no matching bundle exists | `AS.<APP>.General` (default) |

### Handle Arguments

If the label contains dynamic values:
- Identify the dynamic parts
- Replace with `{0}`, `{1}`, etc.
- Note the argument count

Example:
```
User says: "I need a label for 'Assigned to John on May 24'"
→ Key: txt_AssignedTo
→ Label: "Assigned to {0} on {1}"
→ Arguments: 2
→ Context: "Shows who a task is assigned to and when. {0}=username, {1}=date"
```

---

## Step 5: Generate the Key (Translation Sets)

For Translation Set apps, generation is simpler:
- Suggest the text value for the primary locale
- Suggest a description (for developers)
- Suggest notes for translator (context)
- Suggest translation variable names if dynamic values exist

Example:
```
Text: "Assigned to {name} on {date}"
Description: "Shows task assignment with username and date"
Notes for Translator: "{name} is a person's name, {date} is a calendar date"
Variables: name, date
```

---

## Step 6: Present the Result

### For BND:
```
📝 New i18n Key:

  Bundle: AS.VM.General
  Key Name: lbl_VendorScore
  Label (en-US): "Vendor Score"
  Arguments: 0
  Context: "Label for the vendor confidence score field on the evaluation form"

  To add: Open BND → Select AS_VM → AS.VM.General bundle → Add key

  Usage in SAIL:
  rule!AS_CO_I18N_UT_displayLabel(
    i18nData: local!bundleData,
    bundleKey: "lbl_VendorScore"
  )
```

### For Translation Sets:
```
📝 New Translation String:

  Translation Set: AS_GSM_TranslationSet
  Value (en-US): "Vendor Score"
  Description: "Label for the vendor confidence score field"
  Notes for Translator: "A numerical score representing vendor performance"
  Variables: none

  To add: Open Translation Set in Appian Designer → Add String

  Usage in SAIL:
  translation!Vendor Score
```

### For multiple keys at once:
```
📝 Suggested i18n Keys (5):

  Bundle: AS.VM.General
  1. lbl_VendorScore = "Vendor Score"
  2. lbl_ConfidenceLevel = "Confidence Level"
  3. btn_Recalculate = "Recalculate"
  4. txt_ScoreUpdated = "Score updated successfully"
  5. vld_ScoreOutOfRange = "Score must be between 0 and 100"
```

---

## Rules

- **ALWAYS check for duplicates before suggesting a new key**
- **ALWAYS include the bundle name in the output**
- **ALWAYS follow the prefix convention** — never suggest a key without a valid prefix
- **ALWAYS research existing key naming patterns** in the same bundle before suggesting names
- **NEVER suggest generic key names** like `lbl_Text1` or `btn_Button` — be descriptive
- **NEVER suggest keys that concatenate labels** — use arguments instead
