# QE Knowledge Base — AIDC (AI Document Center)

This steering file provides solution-specific context for the QE Agent when testing the **AIDC (AI Document Center)** solution, also known as **AiDocumentCenter** in the Atlas codebase.

---

## 1. Solution Overview

| Field | Value |
|-------|-------|
| Solution Name | AI Document Center (AIDC) |
| Application Prefix | AIA |
| Atlas App Name | `AiDocumentCenter` |
| Jira Project | ADCS |
| Jira Components | aidc, aidc-a11y, aidc-classification, aidc-extraction, aidc-deployment, aidc-reporting |
| Team | AI Doc Center (AI AND INDUSTRY SOLUTIONS) |
| Project Lead | Isaac Dweck |
| Site | Doc Center (AIA Home Site) |

### Business Context

AIDC enables organizations to automate document processing using AI. Key capabilities include:
- **Document Classification** — Categorize documents into predefined types using AI models
- **Document Extraction** — Extract structured data (fields, tables) from documents using AI models
- **AI Review** — AI-powered validation and review of extracted data
- **Model Versioning** — Create, publish, and manage versions of classification and extraction models
- **Test Suites** — Automated testing of model accuracy with test cases
- **Deployments** — Package and deploy models across environments
- **Model Triggers** — Automated actions triggered by model events (e.g., post-reconciliation)
- **Self-Improvement Suggestions** — AI-generated suggestions to improve model performance

### LLM Providers Supported

| Provider | Models |
|----------|--------|
| Anthropic (Claude) | Haiku 3, Haiku 4.5, Sonnet 3, Sonnet 3.5, Sonnet 3.7 |
| Amazon (Nova) | Nova 2 Lite (Text), Nova 2 Lite (Vision) |

### Vision vs Text Mode

| Mode | Description | Page Limit | File Size Limit |
|------|-------------|-----------|-----------------|
| Text (Standard) | Text-based extraction from document content | 100 pages | 25 MB |
| Vision (Multimodal) | Image-based extraction using document images | 100 pages | 18 MB (Nova 2 Vision) |

---

## 2. Test Environment

| Field | Value |
|-------|-------|
| Environment Name | AIDC Test |
| Site URL | https://eng-test-aidc-test.appianpreview.com |
| Site Name | Doc Center |
| Site Path | /suite/sites/doc-center |

### Navigation to AIDC

1. Login at the site URL
2. Navigate to the "Doc Center" site
3. The landing page shows the Home dashboard with Classification and Extraction model summaries

---

## 3. Test Credentials

| Role | Username | Password | Notes |
|------|----------|----------|-------|
| QE Agent | kiro.user | appian@2026 | Primary test account for QE automation |

### Credential Troubleshooting

- The AIDC environment is NOT in the shared GAM credentials spreadsheet
- Credentials are managed separately by the AIDC team
- **Use `kiro.user` / `appian@2026` as the primary login** for test execution
- If `aia.admin` fails, the account may be locked (Appian locks after 5 failed attempts)
- Contact the AIDC team (Yin He, Matt Sawicki, Druva Kota) for credential resets

---

## 4. Core Workflows

### 4.1 Classification Model Workflow

1. **Create Classification Model** — Define model name, description, LLM selection, vision toggle
2. **Configure Categories** — Add classification categories with descriptions
3. **Publish Version** — Publish the model version to make it active
4. **Run Classification** — Upload documents and classify them against the model
5. **Review Results** — View classification instances, reconcile outcomes
6. **Test Suites** — Create test suites to measure model accuracy

### 4.2 Extraction Model Workflow

1. **Create Extraction Model** — Define model name, description, LLM selection, vision toggle
2. **Configure Fields** — Add extraction fields (text, table, large table types)
3. **Configure Validation Rules** — Add AI validation rules, JSON validation, low confidence checks
4. **Publish Version** — Publish the model version
5. **Run Extraction** — Upload documents and extract data
6. **Review & Reconcile** — Review extracted fields, reconcile values, accept/override
7. **AI Review** — Run AI review for additional validation
8. **Test Suites** — Measure extraction accuracy

### 4.3 Document Processing Guardrails

| Guardrail | Text Mode | Vision Mode (Claude) | Vision Mode (Nova 2 Lite) |
|-----------|-----------|---------------------|---------------------------|
| Max Pages (Classification) | 100 | 100 | 100 |
| Max Pages (Extraction) | 100 | 100 | 100 |
| Max File Size | 25 MB | 25 MB | 18 MB |
| Character Limit | 150,000 | N/A | N/A |

---

## 5. Current Release: ADCS 4.2.0

| Field | Value |
|-------|-------|
| Fix Version | Release 4.2.0 |
| Release Date | 2026-05-08 |
| Sprint | AIDC Sprint 18 (active) |

### Key Features in 4.2.0

- Nova 2 Lite LLM provider support (text and vision)
- Updated guardrails for Nova 2 Vision (18MB file size limit, 100 page limit)
- LLM choice list updates for AI Reviewer
- Vision toggle on model configuration

---

## 6. Application Architecture (from Atlas)

### Object Counts

| Type | Count |
|------|-------|
| Expression Rules | 495 |
| Interfaces | 234 |
| Constants | 262 |
| Process Models | 96 |
| Record Types | 33 |
| Translation Strings | 1,113 |
| AI Skills | 5 |
| Total Objects | 2,254 |

### Key Record Types

| Record Type | Purpose |
|-------------|---------|
| AIA Classification Model | Classification model definitions |
| AIA Classification Model Version | Versioned classification configurations |
| AIA Classification Instance | Individual classification runs |
| AIA Classification Instance Outcome | Results per document in a classification |
| AIA Extraction Model | Extraction model definitions |
| AIA Extraction Model Version | Versioned extraction configurations |
| AIA Extraction Instance | Individual extraction runs |
| AIA Extraction Instance Field | Extracted field values per instance |
| AIA Model Test Suite | Test suite definitions |
| AIA Model Test Suite Case | Individual test cases in a suite |
| AIA Model Trigger | Automated triggers on model events |
| AIA Deployment | Deployment packages |
| AIA Model Version Suggestion | AI-generated improvement suggestions |

### Key Constants (Guardrails)

| Constant | Purpose |
|----------|---------|
| AIA_INT_NOVA2LITE_VISION_PAGE_LIMIT | Page limit for Nova 2 Vision (100) |
| AIA_INT_EXTRACTION_NOVA2LITE_MAX_FILE_SIZE | Max file size for Nova 2 Vision extraction (18MB) |
| AIA_INT_EXTRACTION_MAX_FILE_SIZE | Max file size for standard extraction (25MB) |

### Instance Statuses

| Status | Description |
|--------|-------------|
| Initiated | Processing started |
| Extracted / Classified | AI processing complete |
| Extracted with Errors / Classified with Errors | Completed with errors |
| Reconciled Manually | User reviewed and reconciled |
| Reconciled Automatically | Auto-reconciled via rules |
| Instance Error | Fatal error during processing |

---

## 7. Open Bugs

| Key | Summary | Priority | Component | Status |
|-----|---------|----------|-----------|--------|
| ADCS-1035 | Suggestion Agent Error from Execution Log Length Exception | Not Set | — | Verification |
| ADCS-1003 | AI Review Table issues | Not Set | aidc-extraction | Backlog |
| ADCS-993 | Incorrect extracted rows count on instance summary | Not Set | aidc-extraction | Backlog |
| ADCS-990 | Self-Improvement Suggestions: Agent Subcall Fails When Prompt Exceeds 200K Token Limit | Not Set | aidc-extraction | Backlog |
| ADCS-985 | Some validation messages still shown after fixing validations | Not Set | aidc-extraction | Backlog |
| ADCS-966 | Row highlighting does not work on instance field summary for tables extracted from PDF | Highest | aidc-extraction | Backlog |
| ADCS-947 | Run Classification - Document names with spaces get cut off | Lowest | aidc-classification | Backlog |
| ADCS-936 | PM error on reconciling a Classification Instance | Highest | aidc-classification | Backlog |
| ADCS-896 | Home Page UI pink box error | Not Set | aidc | Backlog |
| ADCS-882 | Options rules for table columns aren't appearing in the json schema | Not Set | aidc-extraction | Backlog |
| ADCS-809 | Visual Models not showing Bounding Boxes for Tables | High | aidc-extraction | Backlog |

---

## 8. Key Test Cases (Xray)

| Key | Summary | Focus Area |
|-----|---------|------------|
| ADCS-474 | Verify Error Handling for Large Documents | File size limits (25MB text, 18MB Nova Vision) |
| ADCS-497 | Verify Error Handling for Long Documents | Page limits (100 pages), character limits (150K) |

---

## 9. Known Quirks & Testing Notes

- **Nova 2 Lite + Vision + Classification**: May return invalid JSON for large documents (100+ pages). This is a platform/model limitation, not a solution bug.
- **JPG vs PNG**: Files with mismatched extensions (e.g., PNG saved as .jpg) may cause "Content not accepted" errors with Nova 2 Vision.
- **Processing Time**: Classification and extraction runs can take 30-60+ seconds depending on document size and model complexity.
- **Vision Toggle**: The "Enable Vision" toggle appears next to the LLM dropdown when configuring models. It controls whether the model uses multimodal (image-based) processing.
- **Page Load**: Always wait for the Appian progress bar to disappear before interacting.
- **AI Skill Timeouts**: Large documents may cause AI skill timeouts — wait up to 2 minutes before flagging as an error.
- **Test Data**: Use documents of specific sizes/page counts for guardrail testing. See Section 16 for the full test file inventory.
- **Test Files Drive Folder**: https://drive.google.com/drive/u/0/folders/12tGgYjVmQbOeTSURJvf0vTkJ3yWST41b

---

## 10. Team Contacts

| Name | Role | Email |
|------|------|-------|
| Yin He | Product Owner | yin.he@appian.com |
| Matt Sawicki | Developer / Code Reviewer | matt.sawicki@appian.com |
| Druva Kota | Developer / Design Reviewer | druva.kota@appian.com |
| Juhi Nagaich | Developer | juhi.nagaich@appian-ctr.com |
| Anupama Shetty | QE | anupama.shetty@appian.com |
| Angela Ru | UX | angela.ru@appian.com |
| Susheela Meyyappan | QE | susheela.meyyappan@appian.com |

---

## 11. Release History

| Version | Status | Date |
|---------|--------|------|
| Release 2.9.0 | Released | 2025-08-01 |
| Release 3.0.0 | Released | 2025-09-19 |
| Release 3.1.0 | Released | 2025-12-09 |
| Release 4.0.0 | Unreleased | — |
| Release 4.1.0 | Unreleased | — |
| Release 4.2.0 | Unreleased | 2026-05-08 |

---

## 12. Database Schema

### Summary

| Metric | Value |
|--------|-------|
| Total Tables | 41 |
| Business Tables | 33 |
| Reference Tables | 7 |
| Framework Tables | 1 |
| Total Columns | 402 |
| Foreign Keys | 24 |

### Key Business Tables

| Table | Purpose |
|-------|---------|
| AIA_EXTRACTION_MODEL | Extraction model definitions |
| AIA_EXTRACTION_MODEL_VERSION | Versioned extraction configurations |
| AIA_EXTRACTION_MODEL_VERSION_FIELD | Field definitions per version |
| AIA_EXTRACTION_MODEL_VERSION_SECTION | Section rules per version |
| AIA_EXTRACTION_MODEL_VERSION_VALIDATION | Validation rules per version |
| AIA_EXTRACTION_INSTANCE | Individual extraction runs |
| AIA_EXTRACTION_INSTANCE_FIELD | Extracted field values |
| AIA_EXTRACTION_INSTANCE_FIELD_ROW | Table row data |
| AIA_EXTRACTION_INSTANCE_FIELD_ROW_CELL | Table cell data |
| AIA_EXTRACTION_INSTANCE_EVENT_HISTORY | Audit trail for instances |
| AIA_EXTRACTION_INSTANCE_SECTION | Section data per instance |
| AIA_EXTRACTION_INSTANCE_VALIDATION | Validation results per instance |
| AIA_EXTRACTION_BOUNDING_BOXES | OCR bounding box data |
| AIA_CLASSIFICATION_MODEL | Classification model definitions |
| AIA_CLASSIFICATION_MODEL_VERSION | Versioned classification configs |
| AIA_CLASSIFICATION_MODEL_OPTION | Category options per version |
| AIA_CLASSIFICATION | Classification run data |
| AIA_CLASSIFICATION_INSTANCE_OUTCOME | Per-document classification results |
| AIA_MODEL_TEST_SUITE | Test suite definitions |
| AIA_MODEL_TEST_SUITE_CASE | Individual test cases |
| AIA_MODEL_TEST_SUITE_RUN | Test suite execution results |
| AIA_MODEL_TRIGGER | Automated triggers |
| AIA_MODEL_VERSION_EXAMPLE | Example documents per version |
| AIA_MODEL_VERSION_PROMPT | Prompt configurations |
| AIA_MODEL_VERSION_SUGGESTION | AI improvement suggestions |
| AIA_DEPLOYMENT | Deployment packages |
| AIA_PROCESS_MODEL | Custom process model definitions |
| AIA_PROCESS_MODEL_STEP | Steps within process models |
| AIA_PROMPT | Prompt execution records |
| AIA_PROMPT_RESPONSE | AI response records |

### Reference Tables

| Table | Rows | Purpose |
|-------|------|---------|
| AIA_REF_INSTANCE_STATUS | 2 | Instance status labels/icons |
| AIA_REF_VALIDATION_ERROR_TYPE | 7 | Validation error type names |
| AIA_REF_TRIGGER_TYPE | — | Trigger type definitions |
| AIA_REF_SUGGESTION_STATUS | 3 | Suggestion status (Active/Resolved/Overridden) |
| AIA_EXTRACTION_INSTANCE_EVENT_TYPE | 9 | Event type names for audit trail |
| AIA_AI_SKILL_TYPE | 3 | AI skill type definitions |
| AIA_CHAT_RECORD_TYPE | 1 | Chat instructions |

---

## 13. Active Epics & Feature Areas

### In Progress

| Key | Summary | Focus |
|-----|---------|-------|
| ADCS-844 | LLM Provider choice | Nova 2 Lite support, vision toggle, guardrails |
| ADCS-728 | External Requests AI Doc Center | Customer-driven enhancements |
| ADCS-547 | 3.1 Improvements | General improvements |
| ADCS-217 | Automatic Improvement of Models | Self-learning AI suggestions |
| ADCS-875 | AI Doc Center Bugs | Bug tracking epic |

### Backlog (Future)

| Key | Summary | Focus |
|-----|---------|-------|
| ADCS-1033 | 20+ pages w/ Vision multimodal LLM | Extend vision page limits |
| ADCS-1025 | Remove Reliance On External Plugins | Architecture cleanup |
| ADCS-848 | Clone Models | Model duplication feature |
| ADCS-847 | Create model from scanned pdf | Scanned document support |
| ADCS-846 | Create Model from Record | Record-based model creation |
| ADCS-845 | Instance Searchability Improvements | Search/filter enhancements |
| ADCS-717 | Test Plans and Executions | Test suite improvements |

---

## 14. Hub Objects (High-Risk Shared Components)

These are the most-depended-on objects. Changes to these have the widest blast radius:

| Object | Type | Inbound Deps | Risk Level |
|--------|------|-------------|------------|
| AIA_UTIL_LoadBrandingMap | Expression Rule | 181 | 🔴 Critical |
| AIA_MODEL_TYPE_VALUES | Constant | 49 | 🔴 Critical |
| AIA_ExtractJson | Expression Rule | 44 | 🔴 Critical |
| AIA_UTIL_Filter | Expression Rule | 43 | 🔴 Critical |
| AIA Extraction Instance | Record Type | 37 | 🟠 High |
| AIA_Test_GetLatestExtractionModelVersion | Expression Rule | 36 | 🟠 High |
| AIA_Test_GetLatestExtractionInstance | Expression Rule | 31 | 🟠 High |
| AIA_UTIL_displayUserFullName | Expression Rule | 26 | 🟡 Medium |
| AIA_UTIL_displayDateTime | Expression Rule | 25 | 🟡 Medium |
| AIA_EXTRACTION_FIELD_TYPE_TABLE | Constant | 24 | 🟡 Medium |
| AIA_EXTRACTION_FIELD_TYPE_LARGE_TABLE | Constant | 24 | 🟡 Medium |
| AIA_getLlmVersionDetailsById | Expression Rule | 22 | 🟡 Medium |
| AIA_MODEL_VERSION_STATUS_PUBLISHED | Constant | 20 | 🟡 Medium |
| AIA_IsDocumentExtension | Expression Rule | 19 | 🟡 Medium |
| AIA_LogMetric | Expression Rule | 19 | 🟡 Medium |

---

## 15. Atlas MCP Usage for AIDC

When testing AIDC tickets, use these Atlas calls:

```
# Discover app structure
get_app_overview("AiDocumentCenter")

# Find classification/extraction bundles
search_bundles("AiDocumentCenter", "classification")
search_bundles("AiDocumentCenter", "extraction")

# Get validation logic
get_object_code("AiDocumentCenter", "AIA_ENUM_LlmVersions")
get_object_code("AiDocumentCenter", "AIA_getLlmVersionDetailsById")

# Check guardrail constants
search_objects("AiDocumentCenter", "NOVA2LITE")
search_objects("AiDocumentCenter", "MAX_FILE_SIZE")
search_objects("AiDocumentCenter", "PAGE_LIMIT")
```

---

## 16. Test Files Inventory

**Google Drive Source:** https://drive.google.com/drive/u/0/folders/12tGgYjVmQbOeTSURJvf0vTkJ3yWST41b

**Local Path:** `test-files/aidc/`

### Error Testing Files (`test-files/aidc/error-testing/`)

| File | Size | Purpose |
|------|------|---------|
| 26mb.jpg | ~26 MB | Exceeds 25MB text limit AND 18MB Nova Vision limit |
| 26mb_as_pdf.pdf | ~27 MB | Same image as PDF — exceeds all file size limits |
| 277_page.PDF | ~1.4 MB | Exceeds 100-page limit for classification/extraction |

### Large/Boundary Files (`test-files/aidc/large-files/`)

| File | Size | Pages | Purpose |
|------|------|-------|---------|
| 99pages_datadog_annual_report.pdf | ~3.5 MB | 99 | Just UNDER 100-page limit (boundary - should pass) |
| 100pg_anna_karenina.pdf | ~1.2 MB | 100 | EXACTLY at 100-page limit (boundary - should pass) |
| anna_karenina_full.pdf | ~5.7 MB | 800+ | Well OVER 100-page limit (should fail) |
| 22mb_nvidia_2022.pdf | ~22 MB | — | Exceeds 18MB Nova Vision limit, under 25MB text limit |
| 27mb_tree_conservation.pdf | ~27 MB | — | Exceeds BOTH 25MB text and 18MB Nova Vision limits |
| meta_annual_10k.pdf | ~2.5 MB | 100+ | Standard annual report for extraction testing |
| AAPL_2024_annual.pdf | ~1.1 MB | — | Standard financial document |

### Standard Test Files (`test-files/aidc/standard/`)

| File | Type | Purpose |
|------|------|---------|
| example_bank_statement.pdf | PDF | Standard extraction testing (bank statement fields) |
| US_passport_card.jpg | JPEG | Classification testing (identity documents) |
| canada_passport.jpg | JPEG | Classification testing (international passports) |
| norwegian_passport.jpg | JPEG | Classification testing (vision-based) |

### Drive Folder Structure (Full)

```
AIDC Test Files (12tGgYjVmQbOeTSURJvf0vTkJ3yWST41b)
├── 100+ Pages and Large files/    — Guardrail boundary testing
├── Error Testing/                 — Invalid/oversized files
├── File Types/                    — Format support testing
│   ├── MSG/                       — Email .msg files
│   ├── EML/                       — Email .eml files
│   ├── DOCX/                      — Word documents
│   ├── TIFF/                      — TIFF images
│   ├── JPEG/                      — JPEG images
│   └── PNG/                       — PNG images
├── Packets of PDFs/               — Split packet classification
├── Tables and Spreadsheets/       — Table extraction testing
├── Closing Disclosures/           — Financial document extraction
├── 1040s/                         — Tax form extraction
├── Acord Files/                   — Insurance form extraction
├── COIs/                          — Certificate of Insurance
├── Passports/                     — Identity document classification
├── Dental Claims CL/              — Healthcare claims
├── Licenses/                      — License document classification
├── Finance Files/                 — Financial documents
├── Hotel Invoices/                — Invoice extraction
├── Handwritten Docs/              — Handwriting recognition testing
├── Other Languages/               — Multi-language support
├── Checkboxes/                    — Checkbox detection testing
├── Booking Details/               — Travel document extraction
├── XML Italian Invoices/          — XML format testing
├── DOL AI Doc Examples/           — Department of Labor docs
├── Trade Confirmations/           — Financial trade docs (PII changed)
└── Aidan CV's/                    — Resume/CV extraction
```

### Test File Selection Guide

| Test Scenario | File to Use |
|---------------|-------------|
| Nova 2 Vision > 18MB (should fail) | `error-testing/26mb.jpg` or `large-files/22mb_nvidia_2022.pdf` |
| Text mode > 25MB (should fail) | `error-testing/26mb_as_pdf.pdf` or `large-files/27mb_tree_conservation.pdf` |
| > 100 pages (should fail) | `error-testing/277_page.PDF` or `large-files/anna_karenina_full.pdf` |
| Exactly 100 pages (should pass) | `large-files/100pg_anna_karenina.pdf` |
| Just under 100 pages (should pass) | `large-files/99pages_datadog_annual_report.pdf` |
| Standard extraction (happy path) | `standard/example_bank_statement.pdf` |
| Vision classification (happy path) | `standard/US_passport_card.jpg` |
| Multi-document classification | Use files from Drive `Packets of PDFs/` folder |
| Excel/spreadsheet extraction | Use files from Drive `Tables and Spreadsheets/` folder |

---
