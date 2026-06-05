# i18n Lookup Workflow

Find and search internationalization keys across BND bundles and Appian Translation Sets. Every result MUST include the bundle name or translation set name — the developer must always know exactly where a key lives.

---

## Triggers

Activate this skill when the user asks:
- "Does a Cancel key exist for GSS?"
- "Find the i18n key for vendor name"
- "What's the label for lbl_VendorScore?"
- "Search for keys containing 'evaluation'"
- "What bundle is btn_Save in?"
- "Show me all keys in the AS.VM.General bundle"
- "Is there already a key for 'Submit'?"
- "What translation strings does GSM have for 'Search'?"

---

## Step 1: Determine the i18n System

Check `get_jarvis_config` for the target app:
- If `translationSets` array is populated → use `jarvis_get_translation` tool
- If `translationSets` is empty → use `query_sql` against BND tables
- If both exist → search both, present results grouped by system

---

## Step 2: Execute the Search

### For BND Apps (GSS, AM, RM, GCW, VM)

**Search by key name or label text:**
```sql
SELECT k.keyname, k.enuslabel, b.bundlename, k.context, k.arguments, k.argumentcount
FROM Appian.BND_Key k
JOIN Appian.BND_Bundle b ON k.bundleid = b.bundleid
JOIN Appian.SMT_Application a ON b.appid = a.appid
WHERE a.appdbtableprefix = '<APP_PREFIX>'
AND (k.keyname LIKE '%<SEARCH>%' OR k.enuslabel LIKE '%<SEARCH>%')
AND k.isdeleted = 0
ORDER BY b.bundlename, k.keyname
LIMIT 30
```

**Look up exact key name:**
```sql
SELECT k.keyname, k.enuslabel, b.bundlename, k.context, k.arguments, k.argumentcount, k.addedby, k.addedon
FROM Appian.BND_Key k
JOIN Appian.BND_Bundle b ON k.bundleid = b.bundleid
JOIN Appian.SMT_Application a ON b.appid = a.appid
WHERE a.appdbtableprefix = '<APP_PREFIX>'
AND k.keyname = '<EXACT_KEY_NAME>'
AND k.isdeleted = 0
LIMIT 5
```

**Check for duplicate label text (before creating new key):**
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

**List all keys in a specific bundle:**
```sql
SELECT k.keyname, k.enuslabel, k.arguments
FROM Appian.BND_Key k
JOIN Appian.BND_Bundle b ON k.bundleid = b.bundleid
WHERE b.bundlename = '<BUNDLE_NAME>'
AND k.isdeleted = 0
ORDER BY k.keyname
LIMIT 50
```

**List all bundles for an app (with key counts):**
```sql
SELECT b.bundleid, b.bundlename, COUNT(k.keyid) as key_count
FROM Appian.BND_Bundle b
LEFT JOIN Appian.BND_Key k ON b.bundleid = k.bundleid AND k.isdeleted = 0
JOIN Appian.SMT_Application a ON b.appid = a.appid
WHERE a.appdbtableprefix = '<APP_PREFIX>'
GROUP BY b.bundleid, b.bundlename
ORDER BY key_count DESC
LIMIT 20
```

### For Translation Set Apps (GSM, newer apps)

**Search by text:**
```
jarvis_get_translation(parentFolderId: <kbFolderId>, query: "<SEARCH_TEXT>", locale: "")
```

**Look up by UUID:**
```
jarvis_get_translation(parentFolderId: <kbFolderId>, query: "<UUID>", locale: "")
```

**Get all translations for a key:**
```
jarvis_get_translation(parentFolderId: <kbFolderId>, query: "<UUID>", locale: "all")
```

**Get specific locale:**
```
jarvis_get_translation(parentFolderId: <kbFolderId>, query: "<UUID>", locale: "fr-FR")
```

---

## Step 3: Present Results

### CRITICAL: Always show the bundle/translation set name

**For BND results:**
```
🔍 Search results for "Cancel" in AS_VM:

  Bundle: AS.VM.General (1539 keys)
    btn_Cancel = "Cancel"
    acs_Cancel = "Press Enter to cancel changes"
    ins_Cancel = "Do you want to cancel?"
    ins_CancelMessage = "Your changes will be lost. Do you want to proceed?"
    txt_ActionCancelled = "Cancelled"
    txt_StatusCancelled = "Cancelled"
    cpt_NotNeededCancelled = "Not Needed/Cancelled"
```

**For Translation Set results:**
```
🔍 Search results for "Search" in AS_GSM:

  Translation Set: AS_GSM_TranslationSet
    "Search" (uuid: 90350847-88ed-4e73-8d21-0e3a25481688)
    "Search Criteria" (uuid: 50f99892-ca20-4836-9fbb-58287fde23fe)
    "Search History" (uuid: 9b84b38d-1702-405b-a63a-0f42d065e0d0)
    "Search Vendors" (uuid: a86a5400-deb8-4f9e-8ef8-dc26cb3bcf00)

  Translation Set: AS_GSM_CO_TranslationSet
    "Search" (uuid: e1ac7a22-9311-46c2-87fb-d2027a33e436)
```

### Presentation Rules

- Group results by bundle name (BND) or translation set name (Translation Sets)
- Show key count per bundle when listing bundles
- For BND: show `keyname = "label"` format
- For Translation Sets: show `"label" (uuid: ...)` format
- If arguments exist, note them: `txt_AssignedTo = "Assigned to {0} on {1}" [2 args]`
- If a key is stale, flag it: `⚠️ STALE`
- If duplicate labels found, warn: "⚠️ Multiple keys have the same label text"
