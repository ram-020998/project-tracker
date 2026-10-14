# 04 — Shared UI component interfaces (`GH_UI_*`)

Reusable interfaces called as `rule!GH_UI_X(...)` from pages and views. Create with `createInterface` (with `inputs` and
`testInputs`), then `testInterface` with realistic inputs. Follow `10-design-system.md`. Skill steps: Step 4A+4B
verification, `interface-generation-checklist.md`, `validateExpression(isInterface: true)` retry loop (max 3).

Components verified to exist in the skill registry (2026-10-14): headerContentLayout, cardLayout, columnsLayout,
columnLayout, sideBySideLayout, sideBySideItem, richTextDisplayField, richTextIcon, tagField, tagItem, stampField,
progressBarField, gridField, gridColumn, columnChartField, barChartField, pieChartField, chartSeries, milestoneField,
sectionLayout, textField, dropdownField, buttonArrayLayout, buttonWidget, recordLink, dynamicLink, documentDownloadLink,
cardGroupLayout, gaugeField. (`a!richTextItem` and `a!headingField` are standard but absent from the registry list — confirm
via validateExpression.) Instruction files to read before coding: `references/layouts/{header-content,card,columns,sidebyside}-layout-instructions.md`,
`references/components/{rich-text,stamp-field,grid-field,chart,button}-instructions.md`.
Critical warnings captured: headerContentLayout `header` only accepts cardLayout/billboardLayout; sideBySideItem width only
AUTO/MINIMIZE/1X–10X and only sideBySideLayout may nest inside it; columnsLayout needs an AUTO column and spacing ∉ {LESS,MORE};
recordLink inside a grid must be wrapped in richTextDisplayField; gridField `showSearchBox` only with record data; button
style only SOLID/OUTLINE/GHOST/LINK; stampField/richTextIcon icon names must be valid aliases (never guess — validate).

| Interface | Inputs | Renders |
|---|---|---|
| `GH_UI_PageHeader` | `title` Text, `subtitle` Text, `icon` Text, `meta` Any (optional list of components on the right) | a `a!cardLayout(style:"NONE", showBorder:false, padding:"STANDARD")` containing sideBySideLayout: brand stamp (icon, background `#4F46E5`, size SMALL) · title H1 + subtitle SECONDARY · right MINIMIZE item = meta. Must be usable directly as `headerContentLayout.header`. |
| `GH_UI_KpiCard` | `label` Text, `value` Text, `icon` Text, `color` Text hex, `hint` Text, `link` Any | cardLayout (border, padding STANDARD, height "SHORT_PLUS" optional) with sideBySide: stamp(icon, backgroundColor soft of color, contentColor color) + value (EXTRA_LARGE, STRONG) + label (SMALL SECONDARY) + hint (SMALL). `link` makes the whole card clickable. |
| `GH_UI_TagList` | `tags` List of Map `{text, color, soft}` | `a!tagField(labelPosition:"COLLAPSED", tags: a!forEach(..., a!tagItem(text, backgroundColor: soft, textColor: color)), size:"SMALL")`; empty list → nothing (showWhen). |
| `GH_UI_EmptyState` | `icon` Text, `title` Text, `message` Text | centered richText: large SECONDARY icon, STRONG title, SECONDARY message. |
| `GH_UI_StageTracker` | `artifacts` List of Map (stage, status, version, publishedBy, publishedAt, blobKey), `compact` Boolean | For each of `GH_UI_stages()`: find artifact by stage; render a step (`a!milestoneField` is acceptable but limited colours — preferred: columnsLayout of 4 columns, each a small card/rich text with stage icon, stage label, status dot+label coloured via `GH_UI_stageStatusColor`, and when not compact: "v{version} · {publishedBy} · {date}"). Missing stage → "Not started" in slate. compact=true → one-line row of 4 coloured pills (for feature cards). |
| `GH_UI_LaneProgress` | `counts` List of Map `{status, count}`, `showLegend` Boolean | A stacked horizontal bar of lanes using `a!barChartField` (stacking "PERCENT_TO_TOTAL", one series per lane coloured with lane colors, single category) OR a progressBarField of %done + a row of lane count pills. Recommend: progressBar (percentage = done/total*100, style THIN, colour `#059669`) + pill row "To Do 12 · Design 3 · … · Done 40". |
| `GH_UI_StoryCard` | `story` Map (id, backlogKey, title, storyType, appianPart, status, epicTitle), `showLane` Boolean | compact card for Board/feature lists: key in SMALL SECONDARY + type tag; title (STRONG, linked with `a!recordLink(recordType: GH Story, identifier: id)`); footer: appianPart tag + epic title SECONDARY; optional lane pill. |
| `GH_UI_LabelValue` | `label` Text, `value` Any, `icon` Text | Summary-view field row: label SMALL SECONDARY over value (or "—"). |

Test each with `testInterface` (literal inputs, e.g. StageTracker with 2 of 4 stages present → missing ones show "Not started").
