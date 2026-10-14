# 10 — Design system for the Genesis Hub site (every interface MUST follow this)

The user's bar: **"very, very good-looking"**, simple, modern, not the whole Genesis UI. Mirror the Genesis web app's
light-first **Indigo · Slate** language (ADR-055) inside SAIL's constraints.

## 1. Palette (hex — SAIL accepts hex in `color`/`backgroundColor` of richTextItem, tagItem, stampField, cardLayout `style` only takes enum)

| Token | Hex | Use |
|---|---|---|
| brand | `#4F46E5` (indigo-600) | page titles accents, primary KPI stamp, links, active stage |
| brand-soft | `#EEF2FF` (indigo-50) | soft tag backgrounds, highlighted card fills (via tag/stamp) |
| slate | `#475569` (slate-600) | secondary text |
| slate-soft | `#F1F5F9` | neutral tag background |
| ink | `#0F172A` | headings |
| success | `#059669` / soft `#ECFDF5` | done / completed / created |
| warning | `#D97706` / soft `#FFFBEB` | in-review / design-review / updated |
| danger | `#DC2626` / soft `#FEF2F2` | deprecated / bug fix / failed |
| info | `#0284C7` / soft `#F0F9FF` | in progress / implementation |
| violet | `#7C3AED` / soft `#F5F3FF` | code review / verification |

Card `style` enum: use `"NONE"` (white) with `showBorder: true` and `borderColor` if available, or `"STANDARD"` for
subtle grey section backgrounds. Avoid a "rainbow dashboard": colour only tags/stamps/icons, never whole sections.

## 2. Lane palette (8 Workbench lanes, in order)

| value | label | color | soft |
|---|---|---|---|
| `to-do` | To Do | `#64748B` | `#F1F5F9` |
| `design` | Design | `#4F46E5` | `#EEF2FF` |
| `design-review` | Design Review | `#D97706` | `#FFFBEB` |
| `implementation` | Implementation | `#0284C7` | `#F0F9FF` |
| `code-review` | Code Review | `#7C3AED` | `#F5F3FF` |
| `verification` | Verification | `#DB2777` | `#FDF2F8` |
| `deployment` | Deployment | `#0D9488` | `#F0FDFA` |
| `done` | Done | `#059669` | `#ECFDF5` |
Unknown value → label = the raw value, color slate.

## 3. Stage palette (feature stages, in order)

`spec` → "Spec", `ux_design` → "UX Design", `technical_design` → "Technical Design", `breakdown` → "Feature Breakdown".
Stage status color: `completed` success · `in-review` warning · `in-progress` info · `draft` slate · missing ("Not started") slate-soft, dashed/secondary text.

## 4. Other tag colors
- storyType: `Story` brand / brand-soft; `Task` slate / slate-soft.
- changeKind: `created` success, `updated` warning, `deprecated` danger. isBugfix=1 → extra "Bug fix" danger tag.
- Object type (normalized, see 03): Record Type `#4F46E5`, Interface `#0284C7`, Expression Rule `#7C3AED`, Process Model `#D97706`, Constant `#0D9488`, Data / Reference data `#DB2777`, Integration `#64748B`, Other slate.

## 5. Typography & layout rules
- Page = `a!headerContentLayout(header: a!cardLayout(...GH_UI_PageHeader...), contents: …, backgroundColor: "TRANSPARENT")`
  (header MUST be wrapped in a cardLayout — skill rule).
- Page title: `a!headingField(text:, size: "LARGE", headingTag: "H1", fontWeight: "BOLD")`; subtitle: richTextItem SECONDARY.
- Section titles: `a!headingField(size: "SMALL"/"MEDIUM", headingTag: "H2")` or sectionLayout with `labelHeadingTag`.
- KPI row: `a!columnsLayout` of 4–6 `a!columnLayout` (width `"1X"` each … or MEDIUM; keep one AUTO), each a `GH_UI_KpiCard`.
- Cards: padding `"STANDARD"`, `showBorder: true`, `marginBelow: "STANDARD"`; clickable cards use `link: a!recordLink(…)`.
- Card lists: `a!cardGroupLayout` (if available, `cardWidth` e.g. `"MEDIUM"`) or columnsLayout with forEach.
- Grids: `a!gridField` with `a!recordData` (record source → enables `showSearchBox`), `pageSize` 15–25, rowHeader set,
  first column = record link wrapped in `a!richTextDisplayField` (NEVER a bare recordLink in a gridColumn value).
- sideBySideItem widths: only `AUTO`, `MINIMIZE`, `1X..10X`.
- columnsLayout spacing: only `STANDARD`/`NONE`/`DENSE`/`SPARSE`; at least one `AUTO` column.
- Long text (descriptions, wiki notes): `a!richTextDisplayField` with paragraphs split on `char(10)`; preserve line breaks via
  `a!forEach(split(text, char(10)), a!richTextItem(text: fv!item & char(10)))` or simply richTextItem text (newlines render).
- Empty states everywhere (`GH_UI_EmptyState`): icon + "No X yet" + one-line hint. Never show a blank card.
- Dates: `GH_UI_formatDateTime` → "Sep 6, 2026 6:03 PM"; relative hint optional.
- Accessibility: every grid `rowHeader`; icons have `altText`/caption; collapsible sections set `labelHeadingTag`;
  link text is meaningful (not "click here").
- Read-only: inputs allowed ONLY for filters/search (local variables); no buttons with submit.

## 6. Site branding (manual — the Dev MCP site API exposes no colour fields)
Set in Appian Designer → site `GH Genesis Hub` → Branding/Appearance. Recommended **"Indigo Night"**:
| Setting | Hex | Why |
|---|---|---|
| Header / navigation (sidebar) background | `#1E1B4B` | deep indigo-950 — premium, high contrast with white nav text |
| Selected page / tab background | `#4F46E5` | brand indigo-600, same as every page header stamp |
| Accent colour | `#4F46E5` | links, focus, default controls — makes every link in the pages match the brand |
| Loading bar | `#A5B4FC` | indigo-300, visible on the dark sidebar |
Alternative "Clean Light": navigation `#FFFFFF`, selected `#EEF2FF`, accent `#4F46E5`, loading bar `#4F46E5`.
Page content background is already `#F8FAFC` (set in every headerContentLayout), which suits both.
