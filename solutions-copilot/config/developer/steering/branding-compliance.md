---
inclusion: auto
---

# Branding Compliance Tools

## Tools

- `analyze_appian_code` with `analysis_types: ["branding"]` — scans for raw hex codes and hardcoded color tokens
- `fix_branding` — replaces raw values with branding map calls, reports conflicts

## When to Use

- During code review: include `"branding"` in analysis_types alongside other checks
- On-demand: when user asks to check or fix branding/colors in an object
- After extracting SAIL from an export (before deploying refactored code)

## Workflow

1. **Analyze**: Run `analyze_appian_code` with `analysis_types: ["branding"]` on the object UUID
2. **Review**: Present findings to user — single-key matches show the fix, multi-key matches list options
3. **Fix**: Run `fix_branding` with the SAIL code (from `extract_sail_from_export`)
4. **Resolve conflicts**: The fixed code includes a `/* BRANDING CONFLICTS */` comment listing unresolved values. Ask the user which key to use for each, then do a string replacement
5. **Deploy**: Pass the final SAIL to `rebuild_export_package` → `inspect_package` → `deploy_package`

## Configuration

The branding map and rule names are loaded from the file at `JARVIS_BRANDING_CONFIG` env var (mounted into the container). No parameters needed at call time.

## Conflict Handling

When a hex code or color token maps to multiple branding keys, the tools:
- **analyze**: reports all options — e.g., "`Blue3` in `borderColor` — choose from: `AccentColor`, `LoadingBarColor`, `InfoAccentColor`"
- **fix**: leaves the value unchanged and appends a conflict comment

Present conflicts to the user and ask them to choose. Then replace the remaining raw value with their chosen key using string replacement before deploying.

## Key Concepts

- **Branding map**: maps key names (e.g., `DividerColor`) to color values (`Gray1` or `#AABBCC`)
- **Display rule**: `rule!AS_PD_displayBranding(brandingMap: ..., key: "...")` — retrieves color from map at runtime
- **Load rule**: `rule!AS_PD_getBrandingMap()` — creates the brandingMap variable
- **brandingMap source**: auto-detected from code — uses `ri!brandingMap` if it exists as a rule input, otherwise `local!brandingMap`
