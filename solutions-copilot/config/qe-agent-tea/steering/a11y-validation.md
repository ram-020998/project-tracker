# A11y Validator — Live Screen Accessibility Testing

This steering file provides the QE Agent with instructions to run accessibility validation on any Appian screen during test execution. It validates against the Aurora Accessibility Checklist (69 rules) using live DOM inspection and color contrast analysis.

**When to use:** During Section 4.4 (Accessibility Testing) of the QE workflow, or whenever accessibility validation is requested.

**Prerequisites:**
- Chrome DevTools MCP or Playwright MCP (for browser interaction)
- A11y Accessibility MCP (for color contrast — configured at user level)
- Python 3.8+ with the A11y Validator installed (see Setup below)

---

## Setup (One Time)

```bash
cd ai-framework/tools/A11y-Validator
./setup.sh
```

Or manually:
```bash
cd ai-framework/tools/A11y-Validator
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cd mcp/a11y-accessibility && npm install && cd ../..
```

---

## Quick Validation (3 Steps)

### Step 1 — Capture HTML + Screenshot

Use Chrome DevTools MCP `evaluate_script` (or Playwright equivalent) to capture the page:

```javascript
() => {
  const target = document.querySelector('[role="dialog"]') || document.querySelector('main') || document.body;
  const clone = target.cloneNode(true);
  clone.querySelectorAll('[style]').forEach(el => {
    const style = el.getAttribute('style');
    if (style && style.includes('--appian-')) {
      const cleaned = style.split(';').filter(s => !s.trim().startsWith('--appian-')).join(';').trim();
      cleaned ? el.setAttribute('style', cleaned) : el.removeAttribute('style');
    }
  });
  clone.querySelectorAll('[class*="erd_scroll_detection"]').forEach(el => el.remove());
  return '<!DOCTYPE html><html lang="en-US"><head><meta charset="UTF-8"></head><body>' + clone.innerHTML + '</body></html>';
}
```

Save the result as `screen.html`. Take a screenshot and save as `screen.png`.

### Step 2 — Run Live DOM Checks

Execute these scripts on the live page to collect accessibility data:

**Touch Targets (24x24px minimum):**
```javascript
() => {
  const MIN = 24;
  const els = document.querySelectorAll('button, a[href], [role="button"], [role="link"]');
  const failing = [];
  els.forEach(el => {
    const r = el.getBoundingClientRect();
    if (r.width === 0 || r.height === 0) return;
    if ((r.width < MIN || r.height < MIN) && r.width > 1) {
      failing.push({ label: el.getAttribute('aria-label') || el.textContent.trim().substring(0,40), w: Math.round(r.width), h: Math.round(r.height) });
    }
  });
  return { failing: failing.length, items: failing };
}
```

**Label Announcements:**
```javascript
() => {
  const selectors = 'button,a[href],[role="button"],[role="link"],input,select,textarea,[role="combobox"],[role="group"],[role="region"],h1,h2,h3,h4,h5,h6,table,[role="grid"],img,svg[role="img"]';
  const results = [];
  document.querySelectorAll(selectors).forEach(el => {
    const r = el.getBoundingClientRect();
    if (r.width === 0 || r.height === 0) return;
    const name = el.getAttribute('aria-label') || (el.getAttribute('aria-labelledby') ? (document.getElementById(el.getAttribute('aria-labelledby'))||{}).textContent?.trim() : null) || el.getAttribute('alt') || el.textContent.trim().replace(/\s+/g,' ').substring(0,60) || null;
    if (!name) results.push({ tag: el.tagName, role: el.getAttribute('role'), issue: 'NO LABEL' });
  });
  return { issues: results.length, items: results };
}
```

**Color Pair Extraction:**
```javascript
() => {
  const pairs = new Map();
  document.querySelectorAll('*').forEach(el => {
    const r = el.getBoundingClientRect();
    if (r.width === 0 || r.height === 0) return;
    const s = window.getComputedStyle(el);
    if (s.color && s.backgroundColor && s.backgroundColor !== 'rgba(0, 0, 0, 0)') {
      const k = s.color + '|' + s.backgroundColor;
      if (!pairs.has(k)) pairs.set(k, { fg: s.color, bg: s.backgroundColor, sample: el.textContent.trim().substring(0,20) });
    }
  });
  return Array.from(pairs.values()).slice(0,15);
}
```

For each color pair, run `check_color_contrast` via A11y MCP:
- Regular text: must pass 4.5:1
- Large text (18pt+ or 14pt bold): must pass 3:1

**Save all results as `live_checks.json`:**
```json
{
  "touch_targets": {"failing": 0, "items": []},
  "label_announcements": {"issues": 0, "items": []},
  "color_contrast": [{"fg": "rgb(...)", "bg": "rgb(...)", "ratio": 8.2, "pass": true, "passesWCAG2AA": true}],
  "link_differentiation": {"issues": 0, "items": []},
  "focus_indicators": {"richTextLinksFound": 0, "results": []},
  "zoom_200": {"issues": []},
  "zoom_400": {"issues": []},
  "tooltips": {"found": 0, "results": []},
  "image_of_text": {"suspects": 0, "items": []},
  "stamp_tooltips": {"stampsFound": 0, "withTooltips": 0},
  "signature": {"canvasFound": 0},
  "workflow": {"results": []},
  "dynamic_content": {},
  "grayscale_screenshot": "",
  "partial_checks": [],
  "dynamic_status_messages": {"liveRegionsFound": 0, "potentialTriggers": [], "tested": [], "untested": [], "issues": []}
}
```

### Step 3 — Run Validator + Report

```bash
source ai-framework/tools/A11y-Validator/venv/bin/activate
python ai-framework/tools/A11y-Validator/main.py \
  --file screen.html \
  --screenshot screen.png \
  --live-checks live_checks.json \
  --jira-context ai-framework/tools/A11y-Validator/jira_a11y_context.json \
  --no-checklist
```

---

## Interpreting Results for the Verification Template

Include in the "Accessibility Testing" section of the verification report:

**If 0 issues:**
```
Accessibility Testing:
Verified screen passes all 69 Aurora Accessibility Checklist rules
Verified color contrast meets WCAG 2 AA (4.5:1 text, 3:1 icons) for all color pairs
Verified all interactive elements have accessible names
Verified no touch target size violations (24x24px minimum)
```

**If issues found:**
```
Accessibility Testing:
A11y Validator found [N] issues:
- [A11Y-C] [Issue description] — [Component] — WCAG [ref]
- [A11Y-H] [Issue description] — [Component] — WCAG [ref]
- [A11Y-M] [Issue description] — [Component] — WCAG [ref]
Color contrast: All pairs pass WCAG 2 AA
Touch targets: [N] elements below 24x24px minimum
Full report: [path to HTML report]
```

---

## Severity Mapping

| Severity | Action |
|---|---|
| A11Y-C (Critical) | Blocks AT users — flag as test failure, bounce ticket |
| A11Y-H (High) | Significant issue — flag as test failure, bounce ticket |
| A11Y-M (Medium) | Degrades experience — log as separate bug, don't block ticket |
| A11Y-L (Low) | Minor — note in observations, don't block ticket |

---

## When to Run

- **Always:** On forms, modals, and dialogs (highest risk for a11y issues)
- **Always:** On grids and data tables
- **Recommended:** On record views and dashboards
- **Skip:** On pages with only navigation (low risk)

---

## Additional Scripts (Run If Applicable)

**Grayscale simulation** (for color-as-only-identifier check):
```javascript
() => { document.body.style.filter = 'grayscale(100%)'; return 'on'; }
```
Take screenshot, then remove: `() => { document.body.style.filter = ''; return 'off'; }`

**Focus indicators** (for rich text links):
```javascript
() => {
  const links = document.querySelectorAll('.LinkedItem---standalone_richtext_link');
  const results = [];
  links.forEach(l => { l.focus(); const s = window.getComputedStyle(l); results.push({ text: l.textContent.trim().substring(0,30), pass: s.outline !== 'none' && !s.outline.includes('0px') }); });
  return { richTextLinksFound: results.length, results };
}
```

**Link differentiation** (embedded links — color only):
```javascript
() => {
  const links = document.querySelectorAll('a[href], [role="link"]');
  const issues = [];
  links.forEach(link => {
    const r = link.getBoundingClientRect();
    if (r.width === 0 || r.height === 0) return;
    const style = window.getComputedStyle(link);
    const parent = link.parentElement;
    const parentText = parent ? parent.textContent.replace(link.textContent,'').trim() : '';
    if (parentText.length < 5) return;
    const hasUnderline = style.textDecoration.includes('underline');
    const hasIcon = !!link.querySelector('svg,img');
    if (!hasUnderline && !hasIcon) issues.push({ text: link.textContent.trim().substring(0,40), issue: 'Color only' });
  });
  return { issues: issues.length, items: issues };
}
```

---

## Reference

- Full rule details: ai-framework/tools/A11y-Validator/rules_export/A11Y_VALIDATION_RULES_PLAIN_LANGUAGE.md
- Aurora Checklist: https://appian-design.github.io/aurora/accessibility/checklist/
- Tool coverage map: ai-framework/tools/A11y-Validator/aurora_checklist_tool_coverage.html
