<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Solutions OS Revamp — Executive Presentation</title>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
:root {
  --bg: #0f1117;
  --surface: #1a1d27;
  --surface-2: #242836;
  --border: #2e3348;
  --accent: #6366f1;
  --accent-glow: rgba(99, 102, 241, 0.2);
  --green: #10b981;
  --red: #ef4444;
  --orange: #f59e0b;
  --blue: #3b82f6;
  --purple: #8b5cf6;
  --text: #e8eaf0;
  --text-muted: #8892a8;
  --text-dim: #5a6380;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Inter', sans-serif;
  background: var(--bg);
  color: var(--text);
  overflow: hidden;
  height: 100vh;
}

/* ─── SLIDE CONTAINER ─── */
.presentation {
  height: 100vh;
  display: flex;
  flex-direction: column;
}

.slide {
  display: none;
  flex: 1;
  padding: 60px 80px;
  overflow-y: auto;
  animation: fadeIn 0.4s ease;
}
.slide.active { display: flex; flex-direction: column; }

@keyframes fadeIn {
  from { opacity: 0; transform: translateY(20px); }
  to { opacity: 1; transform: translateY(0); }
}

/* ─── NAVIGATION ─── */
.nav-bar {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  background: rgba(15, 17, 23, 0.95);
  backdrop-filter: blur(20px);
  border-top: 1px solid var(--border);
  padding: 16px 40px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  z-index: 1000;
}

.nav-progress {
  display: flex;
  gap: 6px;
  align-items: center;
}
.nav-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--border);
  cursor: pointer;
  transition: all 0.3s;
}
.nav-dot.active { background: var(--accent); transform: scale(1.4); box-shadow: 0 0 8px var(--accent-glow); }
.nav-dot.visited { background: var(--text-dim); }

.nav-buttons {
  display: flex;
  gap: 12px;
  align-items: center;
}
.nav-btn {
  padding: 10px 24px;
  border-radius: 8px;
  border: 1px solid var(--border);
  background: transparent;
  color: var(--text);
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  gap: 8px;
}
.nav-btn:hover { background: var(--surface); border-color: var(--accent); }
.nav-btn.primary { background: var(--accent); border-color: var(--accent); }
.nav-btn.primary:hover { background: #5558e6; }
.nav-btn:disabled { opacity: 0.3; cursor: not-allowed; }

.slide-counter {
  font-size: 13px;
  color: var(--text-muted);
  font-weight: 500;
}

/* ─── TYPOGRAPHY ─── */
.slide-label {
  font-size: 12px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 2px;
  color: var(--accent);
  margin-bottom: 16px;
}
.slide h1 {
  font-size: clamp(36px, 4vw, 56px);
  font-weight: 800;
  line-height: 1.1;
  margin-bottom: 20px;
}
.slide h2 {
  font-size: clamp(28px, 3vw, 40px);
  font-weight: 700;
  line-height: 1.2;
  margin-bottom: 16px;
}
.slide h3 {
  font-size: 20px;
  font-weight: 600;
  margin-bottom: 12px;
}
.slide p {
  font-size: 18px;
  line-height: 1.7;
  color: var(--text-muted);
  max-width: 800px;
}
.slide p.large {
  font-size: 22px;
}

/* ─── COMPONENTS ─── */
.gradient-text {
  background: linear-gradient(135deg, #fff 0%, var(--accent) 50%, var(--purple) 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 16px;
  padding: 28px;
  transition: all 0.3s;
}
.card:hover { border-color: var(--accent); box-shadow: 0 4px 30px var(--accent-glow); }

.grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; }
.grid-3 { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 20px; }

.stat-card {
  text-align: center;
  padding: 32px 20px;
}
.stat-value {
  font-size: 42px;
  font-weight: 800;
  margin-bottom: 8px;
}
.stat-label {
  font-size: 14px;
  color: var(--text-muted);
}

.comparison-table {
  width: 100%;
  border-collapse: separate;
  border-spacing: 0;
  margin-top: 24px;
  font-size: 15px;
}
.comparison-table th {
  text-align: left;
  padding: 14px 20px;
  background: var(--surface-2);
  color: var(--text-muted);
  font-weight: 600;
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 1px;
}
.comparison-table th:first-child { border-radius: 10px 0 0 0; }
.comparison-table th:last-child { border-radius: 0 10px 0 0; }
.comparison-table td {
  padding: 16px 20px;
  border-bottom: 1px solid var(--border);
  vertical-align: top;
}
.comparison-table tr:last-child td { border-bottom: none; }
.comparison-table .before { color: var(--red); }
.comparison-table .after { color: var(--green); }

.tag {
  display: inline-block;
  padding: 4px 12px;
  border-radius: 20px;
  font-size: 12px;
  font-weight: 600;
}
.tag-red { background: rgba(239, 68, 68, 0.15); color: var(--red); }
.tag-green { background: rgba(16, 185, 129, 0.15); color: var(--green); }
.tag-blue { background: rgba(59, 130, 246, 0.15); color: var(--blue); }
.tag-purple { background: rgba(139, 92, 246, 0.15); color: var(--purple); }
.tag-orange { background: rgba(245, 158, 11, 0.15); color: var(--orange); }

.icon-box {
  width: 48px;
  height: 48px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 22px;
  margin-bottom: 16px;
}

.timeline {
  position: relative;
  padding-left: 32px;
}
.timeline::before {
  content: '';
  position: absolute;
  left: 8px;
  top: 8px;
  bottom: 8px;
  width: 2px;
  background: linear-gradient(to bottom, var(--accent), var(--purple), var(--green));
  border-radius: 2px;
}
.timeline-item {
  position: relative;
  margin-bottom: 28px;
  padding: 20px 24px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 12px;
}
.timeline-item::before {
  content: '';
  position: absolute;
  left: -28px;
  top: 24px;
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: var(--accent);
  border: 3px solid var(--bg);
}
.timeline-item h4 {
  font-size: 15px;
  font-weight: 600;
  margin-bottom: 6px;
  color: var(--accent);
}
.timeline-item p {
  font-size: 14px;
  line-height: 1.5;
}

.diagram {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 16px;
  padding: 32px;
  font-family: 'SF Mono', 'Fira Code', monospace;
  font-size: 13px;
  line-height: 1.8;
  white-space: pre;
  overflow-x: auto;
  color: var(--text-muted);
  margin: 20px 0;
}
.diagram .hl { color: var(--accent); font-weight: 600; }
.diagram .gr { color: var(--green); font-weight: 600; }
.diagram .rd { color: var(--red); }
.diagram .or { color: var(--orange); }

.pain-point {
  display: flex;
  gap: 16px;
  align-items: flex-start;
  padding: 20px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-left: 3px solid var(--red);
  border-radius: 0 12px 12px 0;
  margin-bottom: 16px;
}
.pain-point .number {
  background: rgba(239, 68, 68, 0.15);
  color: var(--red);
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 14px;
  flex-shrink: 0;
}
.pain-point h4 { font-size: 16px; margin-bottom: 4px; }
.pain-point p { font-size: 14px; color: var(--text-muted); }

.solution-point {
  display: flex;
  gap: 16px;
  align-items: flex-start;
  padding: 20px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-left: 3px solid var(--green);
  border-radius: 0 12px 12px 0;
  margin-bottom: 16px;
}
.solution-point .number {
  background: rgba(16, 185, 129, 0.15);
  color: var(--green);
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 14px;
  flex-shrink: 0;
}
.solution-point h4 { font-size: 16px; margin-bottom: 4px; }
.solution-point p { font-size: 14px; color: var(--text-muted); }

.flex-center {
  display: flex;
  align-items: center;
  justify-content: center;
  flex: 1;
}
.flex-col { display: flex; flex-direction: column; }
.gap-24 { gap: 24px; }
.gap-16 { gap: 16px; }
.mt-24 { margin-top: 24px; }
.mt-32 { margin-top: 32px; }
.mt-40 { margin-top: 40px; }
.mb-40 { margin-bottom: 40px; }

.slide-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  justify-content: center;
  padding-bottom: 80px;
}

.two-col {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 40px;
  align-items: start;
}

.highlight-box {
  background: linear-gradient(135deg, rgba(99, 102, 241, 0.1), rgba(139, 92, 246, 0.05));
  border: 1px solid rgba(99, 102, 241, 0.3);
  border-radius: 12px;
  padding: 24px;
  margin-top: 20px;
}

.quote {
  border-left: 3px solid var(--accent);
  padding-left: 20px;
  font-style: italic;
  font-size: 20px;
  color: var(--text);
  margin: 24px 0;
}

.animate-in {
  opacity: 0;
  transform: translateY(30px);
  transition: all 0.5s cubic-bezier(0.16, 1, 0.3, 1);
}
.animate-in.visible {
  opacity: 1;
  transform: translateY(0);
}

.step-list {
  counter-reset: step;
  list-style: none;
  padding: 0;
}
.step-list li {
  counter-increment: step;
  position: relative;
  padding: 16px 20px 16px 60px;
  margin-bottom: 12px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 12px;
  font-size: 15px;
  line-height: 1.5;
}
.step-list li::before {
  content: counter(step);
  position: absolute;
  left: 16px;
  top: 50%;
  transform: translateY(-50%);
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: var(--accent);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 13px;
}

.user-journey {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 16px;
  flex-wrap: wrap;
}
.journey-step {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 10px 16px;
  font-size: 13px;
  color: var(--text-muted);
}
.journey-arrow {
  color: var(--text-dim);
  font-size: 18px;
}

.kbd {
  font-family: 'SF Mono', monospace;
  background: var(--surface-2);
  border: 1px solid var(--border);
  border-radius: 6px;
  padding: 4px 10px;
  font-size: 14px;
  color: var(--green);
}
/* ─── VISUAL DIAGRAMS (replacing ASCII art) ─── */
.vbox {
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 16px 20px;
  background: var(--surface);
}
.vbox-label {
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 1px;
  margin-bottom: 10px;
  opacity: 0.7;
}
.vbox-title {
  font-size: 15px;
  font-weight: 700;
  margin-bottom: 4px;
}
.vbox-items {
  font-size: 13px;
  color: var(--text-muted);
  line-height: 1.7;
}
.arch-container {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 16px;
  padding: 24px;
  margin: 16px 0;
}
.arch-header {
  text-align: center;
  font-size: 14px;
  font-weight: 700;
  margin-bottom: 16px;
  padding-bottom: 12px;
  border-bottom: 1px solid var(--border);
}
.arch-row {
  display: flex;
  gap: 12px;
  margin-bottom: 12px;
}
.arch-row > * { flex: 1; }
.arch-arrow {
  text-align: center;
  font-size: 20px;
  color: var(--text-dim);
  padding: 8px 0;
}
.arch-footer {
  text-align: center;
  font-size: 13px;
  color: var(--text-muted);
  padding-top: 12px;
  border-top: 1px solid var(--border);
  margin-top: 12px;
}
.route-row {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 8px 12px;
  font-size: 13px;
  border-bottom: 1px solid var(--border);
}
.route-row:last-child { border-bottom: none; }
.route-query { flex: 2; color: var(--text-muted); font-style: italic; }
.route-target { flex: 1; font-weight: 600; }
.route-arrow { color: var(--text-dim); }
.color-accent { color: var(--accent); }
.color-green { color: var(--green); }
.color-orange { color: var(--orange); }
.color-red { color: var(--red); }
.color-purple { color: var(--purple); }
.dup-badge {
  display: inline-block;
  background: rgba(239, 68, 68, 0.12);
  color: var(--red);
  font-size: 11px;
  font-weight: 700;
  padding: 2px 8px;
  border-radius: 4px;
  margin-left: 8px;
}
.pipe-line {
  width: 2px;
  height: 24px;
  background: var(--border);
  margin: 0 auto;
}
.pipe-arrow {
  text-align: center;
  font-size: 16px;
  color: var(--text-dim);
  margin: 4px 0;
}
.pipe-branch {
  display: flex;
  gap: 24px;
  justify-content: center;
  position: relative;
}
.pipe-branch::before {
  content: '';
  position: absolute;
  top: 0;
  left: 25%;
  right: 25%;
  height: 2px;
  background: var(--border);
}
</style>
</head>
<body>

<div class="presentation">
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 1: TITLE -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<div class="slide active" id="slide-1">
  <div class="slide-content" style="align-items: center; text-align: center;">
    <h1 class="gradient-text" style="max-width: 900px;">Solutions OS Revamp</h1>
    <p class="large" style="max-width: 700px; margin-top: 16px;">
      From fragmented tools to a unified AI development platform — one repo, one command, every capability.
    </p>

    <!-- <div class="grid-3 mt-40" style="max-width: 700px; width: 100%;">
      <div class="card stat-card">
        <div class="stat-value" style="color: var(--accent);">4</div>
        <div class="stat-label">Key Changes</div>
      </div>
      <div class="card stat-card">
        <div class="stat-value" style="color: var(--green);">< 5 min</div>
        <div class="stat-label">New Onboarding</div>
      </div>
      <div class="card stat-card">
        <div class="stat-value" style="color: var(--purple);">6 wks</div>
        <div class="stat-label">Implementation</div>
      </div>
    </div> -->
  </div>
</div>

<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 2: WHAT IS SOLUTIONS OS TODAY -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<div class="slide" id="slide-2">
  <div class="slide-content">
    <div class="slide-label">Context</div>
    <h2>What is Solutions OS today?</h2>
    <p style="margin-bottom: 32px;">A shared repository that gives AI coding agents deep knowledge about our Appian applications — enabling AI-assisted development, design docs, code review, test data generation, and more.</p>

    <div class="grid-3">
      <div class="card">
        <div class="icon-box" style="background: rgba(99, 102, 241, 0.15);">🧠</div>
        <h3>Knowledge Layer</h3>
        <p style="font-size: 14px;">Product context, feature specs, personas, architecture decisions — organized per product.</p>
      </div>
      <div class="card">
        <div class="icon-box" style="background: rgba(16, 185, 129, 0.15);">🔧</div>
        <h3>AI Tools (MCP Servers)</h3>
        <p style="font-size: 14px;">Cloud Plane, Live Plane, Data Generator — give AI agents real access to our Appian environments.</p>
      </div>
      <div class="card">
        <div class="icon-box" style="background: rgba(139, 92, 246, 0.15);">⚡</div>
        <h3>Powers (Capabilities)</h3>
        <p style="font-size: 14px;">Pre-built AI workflows — developer, product owner, UX designer, SQL forge, and more.</p>
      </div>
    </div>

    <div class="highlight-box mt-32">
      <p style="font-size: 15px; color: var(--text);">
        <strong>20 projects</strong> were built on this platform during SWAT-a-Palooza — spanning accessibility, data generation, design handoff, testing, documentation, and code tooling.
      </p>
    </div>
  </div>
</div>

<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 3: THE PROBLEM — OVERVIEW -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<div class="slide" id="slide-3">
  <div class="slide-content">
    <div class="slide-label">Problem Statement</div>
    <h2>Why we need a revamp</h2>
    <p style="margin-bottom: 32px;">Solutions OS has proven its value — but scaling it to all teams has exposed three structural problems that slow adoption and create maintenance burden.</p>

    <div class="pain-point animate-in">
      <div class="number">1</div>
      <div>
        <h4>Tool Fragmentation</h4>
        <p>Two independent tools (Cloud Plane & Live Plane) solve overlapping problems with different backends, splitting the ecosystem.</p>
      </div>
    </div>
    <div class="pain-point animate-in">
      <div class="number">2</div>
      <div>
        <h4>Painful Onboarding</h4>
        <p>30-60 minutes to get productive. Manual power installation, MCP server configuration, Docker auth, env var setup.</p>
      </div>
    </div>
    <div class="pain-point animate-in">
      <div class="number">3</div>
      <div>
        <h4>Unmaintainable at Scale</h4>
        <p>Each power bundles its own MCP config. 3 powers using the same server = 3 duplicate Docker entries. No central control.</p>
      </div>
    </div>

    <div class="highlight-box mt-24">
      <p style="font-size: 15px; color: var(--text-muted);">
        <strong style="color: var(--red);">Result:</strong> Most users install one power and never explore others. Capabilities remain siloed. Support burden grows with each new power.
      </p>
    </div>
  </div>
</div>

<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 4: PROBLEM DEEP DIVE — FRAGMENTATION -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<div class="slide" id="slide-4">
  <div class="slide-content">
    <div class="slide-label">Problem #1</div>
    <h2>Cloud Plane vs Live Plane: Two tools, one problem</h2>
    <p style="margin-bottom: 24px;">Both tools answer the same question: <em>"Give AI agents structured knowledge about Appian applications."</em> But they solve it differently.</p>

    <table class="comparison-table">
      <thead>
        <tr>
          <th>Dimension</th>
          <th>Cloud Plane (fka Atlas)</th>
          <th>Live Plane (fka Jarvis)</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td><strong>Storage</strong></td>
          <td>GitLab (versioned JSON snapshots)</td>
          <td>Live Appian environment</td>
        </tr>
        <tr>
          <td><strong>Multi-release</strong></td>
          <td style="color: var(--green);">✓ Full version history & diffs</td>
          <td style="color: var(--red);">✗ Current state only</td>
        </tr>
        <tr>
          <td><strong>Write ops</strong></td>
          <td style="color: var(--red);">✗ Read-only</td>
          <td style="color: var(--green);">✓ Create, deploy, evaluate</td>
        </tr>
        <tr>
          <td><strong>Offline analysis</strong></td>
          <td style="color: var(--green);">✓ No connection needed</td>
          <td style="color: var(--red);">✗ Requires live env</td>
        </tr>
        <tr>
          <td><strong>Overlapping tools</strong></td>
          <td colspan="2" style="text-align: center; color: var(--orange);">
            6+ duplicate capabilities (search, dependencies, code, overview, dead code, impact)
          </td>
        </tr>
      </tbody>
    </table>

    <div class="highlight-box mt-24">
      <p style="font-size: 15px;">
        <strong>Key insight:</strong> These aren't competitors — they're <strong>complementary data planes</strong>. Cloud excels at historical analysis. Live excels at real-time operations. The problem is they were built as separate tools, so powers built on one don't benefit from the other.
      </p>
    </div>
  </div>
</div>

<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 5: PROBLEM DEEP DIVE — ONBOARDING -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<div class="slide" id="slide-5">
  <div class="slide-content">
    <div class="slide-label">Problem #2</div>
    <h2>The onboarding experience today</h2>
    <p style="margin-bottom: 32px;">A new team member who wants to use AI-assisted Appian development goes through this:</p>

    <div class="user-journey">
      <div class="journey-step">Clone repo</div>
      <div class="journey-arrow">→</div>
      <div class="journey-step">Navigate complex folder structure</div>
      <div class="journey-arrow">→</div>
      <div class="journey-step">Find the right power</div>
      <div class="journey-arrow">→</div>
      <div class="journey-step">Install power in Kiro</div>
      <div class="journey-arrow">→</div>
      <div class="journey-step">Configure MCP server</div>
      <div class="journey-arrow">→</div>
      <div class="journey-step">Set env vars</div>
      <div class="journey-arrow">→</div>
      <div class="journey-step">Docker login</div>
      <div class="journey-arrow">→</div>
      <div class="journey-step">Docker pull</div>
      <div class="journey-arrow">→</div>
      <div class="journey-step">Verify connection</div>
      <div class="journey-arrow">→</div>
      <div class="journey-step" style="border-color: var(--red); color: var(--red);">Repeat for each additional power</div>
    </div>

    <div class="grid-2 mt-32">
      <div class="card" style="border-color: var(--red);">
        <h3 style="color: var(--red);">⏱️ 30–60 minutes</h3>
        <p style="font-size: 14px;">Time to first useful AI interaction</p>
        <p style="font-size: 13px; margin-top: 8px; color: var(--text-dim);">And that's if nothing goes wrong. SSL errors, Docker auth failures, and wrong env vars are common.</p>
      </div>
      <div class="card" style="border-color: var(--red);">
        <h3 style="color: var(--red);">📦 3+ MCP configs per user</h3>
        <p style="font-size: 14px;">Each power adds its own server entries</p>
        <p style="font-size: 13px; margin-top: 8px; color: var(--text-dim);">Three powers using the same server = three identical Docker containers configured separately. Credentials scattered across configs.</p>
      </div>
    </div>

    <div class="quote mt-32">
      "I installed the developer power but didn't know sql-forge and ux-designer existed. Each one was another 15 minutes of setup."
    </div>
  </div>
</div>

<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 6: PROBLEM DEEP DIVE — MAINTAINABILITY -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<div class="slide" id="slide-6">
  <div class="slide-content">
    <div class="slide-label">Problem #3</div>
    <h2>Unmaintainable architecture</h2>
    <p style="margin-bottom: 24px;">Every power bundles its own MCP server configuration. This creates a cascading maintenance problem.</p>

    <svg viewBox="0 0 800 340" style="width: 100%; max-width: 800px; margin: 0 auto; display: block;" xmlns="http://www.w3.org/2000/svg">
      <!-- Three power boxes at top -->
      <rect x="20" y="20" width="230" height="80" rx="10" fill="#1a1d27" stroke="#ef4444" stroke-width="2"/>
      <text x="135" y="50" text-anchor="middle" fill="#e8eaf0" font-size="14" font-weight="700">developer</text>
      <text x="135" y="72" text-anchor="middle" fill="#ef4444" font-size="11">+ own mcp.json</text>

      <rect x="285" y="20" width="230" height="80" rx="10" fill="#1a1d27" stroke="#ef4444" stroke-width="2"/>
      <text x="400" y="50" text-anchor="middle" fill="#e8eaf0" font-size="14" font-weight="700">sql-forge</text>
      <text x="400" y="72" text-anchor="middle" fill="#ef4444" font-size="11">+ own mcp.json</text>

      <rect x="550" y="20" width="230" height="80" rx="10" fill="#1a1d27" stroke="#ef4444" stroke-width="2"/>
      <text x="665" y="50" text-anchor="middle" fill="#e8eaf0" font-size="14" font-weight="700">locust-forge</text>
      <text x="665" y="72" text-anchor="middle" fill="#ef4444" font-size="11">+ own mcp.json</text>

      <!-- Arrows down -->
      <line x1="135" y1="100" x2="135" y2="140" stroke="#5a6380" stroke-width="2" marker-end="url(#arrowRed)"/>
      <line x1="400" y1="100" x2="400" y2="140" stroke="#5a6380" stroke-width="2" marker-end="url(#arrowRed)"/>
      <line x1="665" y1="100" x2="665" y2="140" stroke="#5a6380" stroke-width="2" marker-end="url(#arrowRed)"/>

      <!-- Result box -->
      <rect x="40" y="145" width="720" height="120" rx="10" fill="#1a1d27" stroke="#ef4444" stroke-width="1.5" stroke-dasharray="6,3"/>
      <text x="400" y="172" text-anchor="middle" fill="#8892a8" font-size="12">~/.kiro/settings/mcp.json</text>
      <text x="80" y="200" fill="#ef4444" font-size="13">→ docker run solutions-server:latest</text>
      <rect x="560" y="188" width="80" height="20" rx="4" fill="rgba(239,68,68,0.15)"/>
      <text x="600" y="202" text-anchor="middle" fill="#ef4444" font-size="10" font-weight="700">DUPLICATE</text>
      <text x="80" y="222" fill="#ef4444" font-size="13">→ docker run solutions-server:latest</text>
      <rect x="560" y="210" width="80" height="20" rx="4" fill="rgba(239,68,68,0.15)"/>
      <text x="600" y="224" text-anchor="middle" fill="#ef4444" font-size="10" font-weight="700">DUPLICATE</text>
      <text x="80" y="244" fill="#ef4444" font-size="13">→ docker run solutions-server:latest</text>
      <rect x="560" y="232" width="80" height="20" rx="4" fill="rgba(239,68,68,0.15)"/>
      <text x="600" y="246" text-anchor="middle" fill="#ef4444" font-size="10" font-weight="700">DUPLICATE</text>

      <!-- Problems summary -->
      <text x="400" y="300" text-anchor="middle" fill="#f59e0b" font-size="13" font-weight="600">Same server image duplicated 3×. Credentials scattered. Updates break.</text>
      <text x="400" y="325" text-anchor="middle" fill="#8892a8" font-size="12">Power authors must understand Docker, MCP protocol, and credential management.</text>

      <defs><marker id="arrowRed" markerWidth="8" markerHeight="8" refX="4" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8" fill="none" stroke="#5a6380" stroke-width="1.5"/></marker></defs>
    </svg>
  </div>
</div>

<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 7: PROBLEM — LIVE PLANE OVERLAP -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<div class="slide" id="slide-7">
  <div class="slide-content">
    <div class="slide-label">Problem #4</div>
    <h2>Three projects, one Live Plane — which one do we use?</h2>
    <p style="margin-bottom: 24px;">Three independent projects give AI agents access to live Appian environments. They overlap significantly but have different foundations.</p>

    <div class="grid-3">
      <div class="card" style="border-top: 3px solid var(--orange);">
        <h3 style="color: var(--orange);">Jarvis</h3>
        <p style="font-size: 13px; color: var(--text-muted); margin-bottom: 12px;"><strong>Custom Appian app</strong> deployed to each environment. Exposes Web APIs.</p>
        <div style="font-size: 12px; color: var(--text-muted); line-height: 1.8;">
          <div>• 42 tools (KB + Live + Deploy)</div>
          <div>• Semantic search, clusters, patterns</div>
          <div>• Dead code analysis, staleness tracking</div>
          <div>• Package create/deploy</div>
          <div style="margin-top: 8px; color: var(--orange); font-weight: 600;">Requires: JAI app deployed on target env</div>
        </div>
      </div>
      <div class="card" style="border-top: 3px solid var(--blue);">
        <h3 style="color: var(--blue);">buildwithclaude</h3>
        <p style="font-size: 13px; color: var(--text-muted); margin-bottom: 12px;"><strong>MCP server</strong> wrapping OOTB LCP Plugin APIs. 150+ tools.</p>
        <div style="font-size: 12px; color: var(--text-muted); line-height: 1.8;">
          <div>• Full CRUD on all design objects</div>
          <div>• SAIL eval, test expressions</div>
          <div>• Record data operations</div>
          <div>• Skills for development guidance</div>
          <div style="margin-top: 8px; color: var(--blue); font-weight: 600;">Requires: LCP plugin enabled on site</div>
        </div>
      </div>
      <div class="card" style="border-top: 3px solid var(--green);">
        <h3 style="color: var(--green);">lcp-api (a!migo)</h3>
        <p style="font-size: 13px; color: var(--text-muted); margin-bottom: 12px;"><strong>Python library</strong> wrapping OOTB LCP APIs. 237 operations.</p>
        <div style="font-size: 12px; color: var(--text-muted); line-height: 1.8;">
          <div>• 130 plugin + 107 beta operations</div>
          <div>• Multi-profile (dev, staging, prod)</div>
          <div>• JWT auth for beta API</div>
          <div>• Data model from Google Sheets workflow</div>
          <div style="margin-top: 8px; color: var(--green); font-weight: 600;">Requires: LCP plugin + feature toggles</div>
        </div>
      </div>
    </div>

    <div class="highlight-box mt-24">
      <p style="font-size: 15px;">
        <strong style="color: var(--red);">The problem:</strong> Three teams built three tools to talk to live Appian environments. Powers built on one can't use the others. Users pick one and miss capabilities from the rest.
      </p>
    </div>
  </div>
</div>

<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 8: LIVE PLANE — DEEP COMPARISON -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<div class="slide" id="slide-8">
  <div class="slide-content">
    <div class="slide-label">Problem #4 — Deep Dive</div>
    <h2>What each tool actually provides</h2>
    <p style="margin-bottom: 24px;">The overlap is large, but each has unique strengths.</p>

    <table class="comparison-table" style="font-size: 13px;">
      <thead>
        <tr><th>Capability</th><th style="color: var(--orange);">Jarvis (custom app)</th><th style="color: var(--blue);">buildwithclaude (MCP)</th><th style="color: var(--green);">lcp-api (library)</th></tr>
      </thead>
      <tbody>
        <tr><td><strong>Get object code/content</strong></td><td>✓</td><td>✓</td><td>✓</td></tr>
        <tr><td><strong>Search objects</strong></td><td>✓</td><td>✓</td><td>✓</td></tr>
        <tr><td><strong>Dependencies/impact</strong></td><td>✓</td><td>✓</td><td>✓</td></tr>
        <tr><td><strong>Create/update objects</strong></td><td>✓ (limited)</td><td>✓ (full)</td><td>✓ (full)</td></tr>
        <tr><td><strong>SAIL/expression evaluation</strong></td><td>✓</td><td>✓</td><td>✓</td></tr>
        <tr><td><strong>SQL queries</strong></td><td>✓</td><td>—</td><td>✓ (beta)</td></tr>
        <tr><td><strong>Package create/deploy</strong></td><td>✓</td><td>—</td><td>❓ (check)</td></tr>
        <tr><td><strong>Multi-environment profiles</strong></td><td>—</td><td>—</td><td>✓</td></tr>
        <tr><td><strong>JWT/beta API access</strong></td><td>—</td><td>—</td><td>✓</td></tr>
        <tr><td><strong>Semantic search</strong></td><td>✓</td><td>—</td><td>—</td></tr>
        <tr><td><strong>Dead code / clusters / patterns</strong></td><td>✓</td><td>—</td><td>—</td></tr>
        <tr><td><strong>Staleness tracking</strong></td><td>✓</td><td>—</td><td>—</td></tr>
        <tr><td><strong>Data model from Google Sheets</strong></td><td>—</td><td>—</td><td>✓</td></tr>
        <tr><td><strong>Bulk rename workflow</strong></td><td>—</td><td>—</td><td>✓</td></tr>
      </tbody>
    </table>
  </div>
</div>

<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 9: LIVE PLANE — THE REAL QUESTION -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<div class="slide" id="slide-9">
  <div class="slide-content">
    <div class="slide-label">Problem #4 — Tradeoffs</div>
    <h2>Each approach has distinct strengths</h2>
    <p style="margin-bottom: 24px;">We need to evaluate which approach best serves each responsibility in the Live Plane.</p>

    <div class="grid-2">
      <div class="card" style="border-color: var(--orange);">
        <h3 style="color: var(--orange);">Jarvis — Custom Appian App</h3>
        <div style="font-size: 14px; color: var(--text-muted); line-height: 1.8; margin-top: 12px;">
          <div>• <strong>We control the roadmap</strong> — add features as we need them</div>
          <div>• <strong>Semantic search</strong> built into the environment</div>
          <div>• <strong>Staleness tracking</strong> and KB registration UI</div>
          <div>• <strong>Package create/deploy</strong> workflow</div>
          <div>• Requires deployment to each target environment</div>
          <div>• 42 tools — purpose-built for our workflows</div>
        </div>
      </div>
      <div class="card" style="border-color: var(--green);">
        <h3 style="color: var(--green);">LCP API — Platform OOTB</h3>
        <div style="font-size: 14px; color: var(--text-muted); line-height: 1.8; margin-top: 12px;">
          <div>• <strong>Appian maintains it</strong> — evolves with each release</div>
          <div>• <strong>Already available</strong> on any 26.2+ site with plugin</div>
          <div>• <strong>237 operations</strong> — broadest coverage</div>
          <div>• <strong>Multi-profile</strong> support for environment switching</div>
          <div>• Standard auth (Basic + JWT) — no app deployment</div>
          <div>• Already proven in 2 production projects</div>
        </div>
      </div>
    </div>

    <div class="highlight-box mt-32">
      <p style="font-size: 15px; margin-bottom: 12px;">
        <strong>Key question to resolve:</strong> Which capabilities belong to which tool?
      </p>
      <p style="font-size: 14px; color: var(--text-muted);">
        Some of Jarvis's unique features (semantic search, clusters, patterns, staleness) are <strong>pre-computed analysis</strong> that could also live in the Cloud Plane. The CRUD and evaluation operations overlap heavily with LCP API. We need to determine the right boundary.
      </p>
    </div>
  </div>
</div>

<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 10: TRANSITION — LIVE PLANE COMMITMENT -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<div class="slide" id="slide-10">
  <div class="slide-content" style="align-items: center; text-align: center;">
    <div class="slide-label">Moving to solutions</div>
    <h2 style="max-width: 700px;">The modular MCP ecosystem</h2>
    <p class="large" style="margin-top: 16px; max-width: 650px;">
      With the Read · Write · Deploy split clear, the following solutions describe how we unify everything into a single, maintainable platform.
    </p>

    <div class="grid-3 mt-32" style="max-width: 800px; width: 100%;">
      <div class="card stat-card" style="border-color: var(--accent);">
        <div style="font-size: 28px; margin-bottom: 8px;">🧠</div>
        <div class="stat-label" style="color: var(--accent); font-weight: 600;">Intelligence</div>
        <div class="stat-label" style="margin-top: 4px;">Read &amp; understand</div>
      </div>
      <div class="card stat-card" style="border-color: var(--green);">
        <div style="font-size: 28px; margin-bottom: 8px;">✏️</div>
        <div class="stat-label" style="color: var(--green); font-weight: 600;">a!migo (lcp-api)</div>
        <div class="stat-label" style="margin-top: 4px;">Create &amp; modify</div>
      </div>
      <div class="card stat-card" style="border-color: var(--purple);">
        <div style="font-size: 28px; margin-bottom: 8px;">🚀</div>
        <div class="stat-label" style="color: var(--purple); font-weight: 600;">Deployment</div>
        <div class="stat-label" style="margin-top: 4px;">Package &amp; ship</div>
      </div>
    </div>

    <p style="margin-top: 32px; font-size: 15px; color: var(--text-muted); max-width: 650px;">
      Plus dedicated servers for data generation, performance testing, Jira, and browser automation — all configured via a single <code>setup.sh</code>.
    </p>
  </div>
</div>

<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 12: SOLUTION OVERVIEW -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<div class="slide" id="slide-11">
  <div class="slide-content">
    <div class="slide-label">The Solution</div>
    <h2>Four interconnected changes</h2>
    <p style="margin-bottom: 32px;">Each change reinforces the others. Together they transform Solutions OS from a fragile tool collection into a production-grade platform.</p>

    <div class="grid-2">
      <div class="solution-point">
        <div class="number">1</div>
        <div>
          <h4>Unify Cloud + Live Planes</h4>
          <p>One unified MCP server with two data planes. Cloud for history, Live for real-time. Auto-routed.</p>
        </div>
      </div>
      <div class="solution-point">
        <div class="number">2</div>
        <div>
          <h4>Single Orchestrator Agent</h4>
          <p>One entry point that routes to specialist sub-agents. No manual power selection needed.</p>
        </div>
      </div>
      <div class="solution-point">
        <div class="number">3</div>
        <div>
          <h4>Global Config Bootstrap</h4>
          <p>One setup script installs everything. MCP = infrastructure. Powers = lightweight knowledge.</p>
        </div>
      </div>
      <div class="solution-point">
        <div class="number">4</div>
        <div>
          <h4>Repository Restructure</h4>
          <p>T.I.M.E. lifecycle folders, enforced conventions, single source of truth.</p>
        </div>
      </div>
    </div>

    <table class="comparison-table mt-32">
      <thead>
        <tr><th>Metric</th><th class="before">Today</th><th class="after">After Revamp</th></tr>
      </thead>
      <tbody>
        <tr><td>Time to first AI interaction</td><td class="before">30-60 min</td><td class="after">< 5 min</td></tr>
        <tr><td>MCP configs to manage</td><td class="before">3+ per user</td><td class="after">1 (unified)</td></tr>
        <tr><td>Powers that use both backends</td><td class="before">0</td><td class="after">All of them</td></tr>
        <tr><td>Adding a new power</td><td class="before">Folder + mcp.json + Docker + docs</td><td class="after">Folder + POWER.md + steering. Done.</td></tr>
      </tbody>
    </table>
  </div>
</div>

<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 8: NAMING & IDENTITY -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<div class="slide" id="slide-12">
  <div class="slide-content">
    <div class="slide-label">Unified Identity</div>
    <h2>One product, one name: Solutions OS</h2>
    <p style="margin-bottom: 16px;">No more "Atlas" and "Jarvis." Every component carries the Solutions OS brand. Clear, consistent, professional.</p>

    <div class="quote">The tool names "Atlas" and "Jarvis" served us well as prototypes. As we go to production, the product deserves a unified identity.</div>

    <table class="comparison-table mt-24">
      <thead>
        <tr><th>Old Name</th><th>New Name</th><th>What It Is</th></tr>
      </thead>
      <tbody>
        <tr>
          <td class="before" style="text-decoration: line-through;">Atlas MCP Server</td>
          <td class="after"><strong>Solutions Intelligence Server</strong></td>
          <td>The unified MCP server (single Docker image)</td>
        </tr>
        <tr>
          <td class="before" style="text-decoration: line-through;">Atlas (Cloud KB)</td>
          <td class="after"><strong>Cloud Plane</strong></td>
          <td>Versioned, offline-capable intelligence layer (GitLab KB)</td>
        </tr>
        <tr>
          <td class="before" style="text-decoration: line-through;">Jarvis (Live Env)</td>
          <td class="after"><strong>Live Plane</strong></td>
          <td>Real-time, per-environment, write-capable layer (Appian APIs)</td>
        </tr>
        <tr>
          <td class="before" style="text-decoration: line-through;">Atlas Parser</td>
          <td class="after"><strong>Solutions Parser</strong></td>
          <td>KB generation engine (parses .zip → JSON)</td>
        </tr>
        <tr>
          <td class="before" style="text-decoration: line-through;">JAI App (Jarvis Appian Intelligence)</td>
          <td class="after"><strong>Solutions KB App</strong></td>
          <td>Appian app for live KB storage, staleness tracking</td>
        </tr>
        <tr>
          <td class="before" style="text-decoration: line-through;">atlas-developer, atlas-sql-forge, etc.</td>
          <td class="after"><strong>developer, sql-forge, etc.</strong></td>
          <td>Powers/agents — named by function, not by backend</td>
        </tr>
        <tr>
          <td class="before" style="text-decoration: line-through;">solutions-atlas-kb (repo)</td>
          <td class="after"><strong>solutions-kb</strong></td>
          <td>GitLab repo holding parsed application data</td>
        </tr>
        <tr>
          <td class="before" style="text-decoration: line-through;">solutions-atlas-mcp-server (repo)</td>
          <td class="after"><strong>solutions-intelligence-server</strong></td>
          <td>Source repo for the unified MCP server</td>
        </tr>
      </tbody>
    </table>

    <div class="highlight-box mt-24">
      <p style="font-size: 15px;">
        <strong>Principle:</strong> Components are named by <em>what they do</em>, not who built them or what codename they started with. This makes the platform self-documenting and approachable to new team members.
      </p>
    </div>
  </div>
</div>

<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 9: UNIFIED MCP -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<div class="slide" id="slide-13">
  <div class="slide-content">
    <div class="slide-label">Solution #1 — Cloud Plane</div>
    <h2>Solutions Intelligence Server: Cloud Plane</h2>
    <p style="margin-bottom: 24px;">The Cloud Plane uses the existing <strong>Atlas architecture</strong> — pre-parsed application data stored as versioned JSON in GitLab. Fast, offline-capable, multi-release.</p>

    <div class="grid-2">
      <div class="card" style="border-left: 3px solid var(--accent);">
        <h3 style="color: var(--accent);">How it works</h3>
        <div style="font-size: 14px; color: var(--text-muted); line-height: 1.8; margin-top: 12px;">
          <div>1. Appian .zip packages exported from environments</div>
          <div>2. <strong>Solutions Parser</strong> extracts code, dependencies, schema, patterns</div>
          <div>3. Structured JSON committed to <code>solutions-kb</code> GitLab repo</div>
          <div>4. Cloud Plane reads from GitLab API (cached, fast)</div>
        </div>
      </div>
      <div class="card" style="border-left: 3px solid var(--accent);">
        <h3 style="color: var(--accent);">What it provides</h3>
        <div style="font-size: 14px; color: var(--text-muted); line-height: 1.8; margin-top: 12px;">
          <div>• Multi-release history &amp; changelogs</div>
          <div>• Cross-release comparison &amp; diffs</div>
          <div>• Pre-computed dependency graphs</div>
          <div>• Dead code / orphan analysis</div>
          <div>• Bundle-based navigation</div>
          <div>• Schema snapshots &amp; relationships</div>
          <div>• Hub objects &amp; dependency paths</div>
        </div>
      </div>
    </div>

    <div class="highlight-box mt-24">
      <p style="font-size: 15px;">
        <strong>Strengths:</strong> Works offline. Shared across team (one GitLab KB serves everyone). Full version history. Pre-computed analysis (no runtime cost). Already operational with 6+ apps indexed.
      </p>
    </div>
  </div>
</div>

<div class="slide" id="slide-14">
  <div class="slide-content">
    <div class="slide-label">Solution #1 — Live Plane</div>
    <h2>Solutions Intelligence Server: Live Plane</h2>
    <p style="margin-bottom: 24px;">The Live Plane uses a <strong>streamlined version of Jarvis</strong> — stripped down to serve only application knowledge from the live environment. All CRUD and deployment tools are removed.</p>

    <div class="grid-2">
      <div class="card" style="border-left: 3px solid var(--green);">
        <h3 style="color: var(--green);">What stays in Jarvis (Live Plane)</h3>
        <div style="font-size: 14px; color: var(--text-muted); line-height: 1.8; margin-top: 12px;">
          <div>• Get real-time object code &amp; content</div>
          <div>• Live dependency chain lookups</div>
          <div>• Live impact analysis</div>
          <div>• App tree &amp; object search</div>
          <div>• Clusters, patterns, architecture</div>
          <div>• Semantic search on live data</div>
          <div>• Data model &amp; entry points</div>
          <div>• Staleness tracking</div>
        </div>
      </div>
      <div class="card" style="border-left: 3px solid var(--red);">
        <h3 style="color: var(--red);">What's removed from Jarvis</h3>
        <div style="font-size: 14px; color: var(--text-muted); line-height: 1.8; margin-top: 12px;">
          <div><s>Object creation (constants, etc.)</s></div>
          <div><s>Object modification/updates</s></div>
          <div><s>Package creation</s></div>
          <div><s>Package deployment</s></div>
          <div><s>SAIL expression evaluation</s></div>
          <div><s>SQL queries</s></div>
          <div style="margin-top: 12px; color: var(--text); font-weight: 600;">→ These move to dedicated MCP servers (next slide)</div>
        </div>
      </div>
    </div>

    <div class="highlight-box mt-24">
      <p style="font-size: 15px;">
        <strong>Result:</strong> The Intelligence Server (Cloud + Live) answers one question: <em>"Help me understand this application."</em> It never modifies anything. Both planes serve knowledge — Cloud from snapshots, Live from the real environment.
      </p>
    </div>
  </div>
</div>

<div class="slide" id="slide-15">
  <div class="slide-content">
    <div class="slide-label">Solution #1 — Complementary MCP Servers</div>
    <h2>The capabilities removed from Jarvis are already solved</h2>
    <p style="margin-bottom: 24px;">We don't reinvent what's already being built and maintained. Dedicated MCP servers handle writes and deployment.</p>

    <div class="grid-2">
      <div class="card" style="border-top: 3px solid var(--green);">
        <h3 style="color: var(--green);">✏️ lcp-api (a!migo)</h3>
        <p style="font-size: 13px; color: var(--text); margin-bottom: 8px;"><strong>Object creation &amp; modification</strong></p>
        <div style="font-size: 13px; color: var(--text-muted); line-height: 1.8;">
          <div>• 237 CRUD operations via platform OOTB APIs</div>
          <div>• Create/update record types, interfaces, rules</div>
          <div>• Modify process models, constants, groups</div>
          <div>• SAIL evaluation &amp; SQL queries</div>
          <div>• Data model from Google Sheets</div>
          <div>• Multi-profile environment switching</div>
        </div>
        <div style="margin-top: 12px; padding-top: 8px; border-top: 1px solid var(--border); font-size: 12px; color: var(--green);">Already maintained by Saurabh · Uses Appian's own OOTB APIs</div>
      </div>
      <div class="card" style="border-top: 3px solid var(--purple);">
        <h3 style="color: var(--purple);">🚀 Appian Deployment MCP</h3>
        <p style="font-size: 13px; color: var(--text); margin-bottom: 8px;"><strong>Package &amp; deploy</strong></p>
        <div style="font-size: 13px; color: var(--text-muted); line-height: 1.8;">
          <div>• Create deployment packages</div>
          <div>• Inspect package contents</div>
          <div>• Deploy to target environment</div>
          <div>• Check deployment results</div>
          <div>• Promote between environments</div>
        </div>
        <div style="margin-top: 12px; padding-top: 8px; border-top: 1px solid var(--border); font-size: 12px; color: var(--purple);">Open source · github.com/kelseymross/appian-deployment-mcp</div>
      </div>
    </div>

    <div class="highlight-box mt-24">
      <p style="font-size: 15px;">
        <strong>Principle:</strong> Don't reinvent. These projects are actively maintained and purpose-built. By splitting concerns, each module stays focused — the Intelligence Server reads, a!migo writes, Deployment MCP ships. The orchestrator routes based on the verb.
      </p>
    </div>
  </div>
</div>

<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 9: SOLUTION 2 — ORCHESTRATOR -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<div class="slide" id="slide-16">
  <div class="slide-content">
    <div class="slide-label">Solution #2</div>
    <h2>Single Orchestrator Agent</h2>
    <p style="margin-bottom: 24px;">Users never need to choose which power to activate. The orchestrator understands the request and either handles it directly or delegates to the right specialist.</p>

    <div class="two-col">
      <div>
        <h3 style="margin-bottom: 16px;">How it routes</h3>
        <div class="card" style="font-size: 14px; line-height: 2;">
          <div>"<em>How does scoring work in GSS?</em>"</div>
          <div style="color: var(--accent);">→ Handles directly (MCP tools)</div>
          <div style="margin-top: 12px;">"<em>Generate a design doc for GAMS-7126</em>"</div>
          <div style="color: var(--purple);">→ Delegates to developer agent</div>
          <div style="margin-top: 12px;">"<em>Create test data for evaluations</em>"</div>
          <div style="color: var(--orange);">→ Delegates to sql-forge agent</div>
          <div style="margin-top: 12px;">"<em>Fix accessibility on this interface</em>"</div>
          <div style="color: var(--green);">→ Delegates to a11y-fixer agent</div>
        </div>
      </div>
      <div>
        <h3 style="margin-bottom: 16px;">Available specialists</h3>
        <div class="flex-col gap-16">
          <div class="card" style="padding: 14px 20px;">
            <div style="display: flex; align-items: center; gap: 12px;">
              <span class="tag tag-blue">ENG</span>
              <span style="font-size: 14px;"><strong>developer</strong> — code exploration, impact analysis, design docs</span>
            </div>
          </div>
          <div class="card" style="padding: 14px 20px;">
            <div style="display: flex; align-items: center; gap: 12px;">
              <span class="tag tag-purple">PRODUCT</span>
              <span style="font-size: 14px;"><strong>product-owner</strong> — feature specs, release summaries</span>
            </div>
          </div>
          <div class="card" style="padding: 14px 20px;">
            <div style="display: flex; align-items: center; gap: 12px;">
              <span class="tag tag-purple">UX</span>
              <span style="font-size: 14px;"><strong>ux-designer</strong> — prototypes, Aurora compliance</span>
            </div>
          </div>
          <div class="card" style="padding: 14px 20px;">
            <div style="display: flex; align-items: center; gap: 12px;">
              <span class="tag tag-orange">DATA</span>
              <span style="font-size: 14px;"><strong>sql-forge</strong> — test data, ERDs, SAIL-to-SQL</span>
            </div>
          </div>
          <div class="card" style="padding: 14px 20px;">
            <div style="display: flex; align-items: center; gap: 12px;">
              <span class="tag tag-green">QE</span>
              <span style="font-size: 14px;"><strong>qe-agent</strong> — test execution, verification</span>
            </div>
          </div>
          <div class="card" style="padding: 14px 20px;">
            <div style="display: flex; align-items: center; gap: 12px;">
              <span class="tag tag-red">A11Y</span>
              <span style="font-size: 14px;"><strong>a11y-fixer</strong> — automated accessibility fixes</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</div>

<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 10: SOLUTION 3 — GLOBAL BOOTSTRAP -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<div class="slide" id="slide-17">
  <div class="slide-content">
    <div class="slide-label">Solution #3 — The Key Architectural Change</div>
    <h2>Global Configuration Bootstrap</h2>
    <p style="margin-bottom: 16px;">Inspired by Appian's <code>buildwithclaude</code> project — a single setup script that separates <strong>infrastructure</strong> from <strong>knowledge</strong>.</p>

    <div class="quote">MCP servers are infrastructure, not power-scoped resources. Powers are lightweight knowledge that references tools already available.</div>

    <svg viewBox="0 0 800 400" style="width: 100%; max-width: 800px; margin: 0 auto; display: block;" xmlns="http://www.w3.org/2000/svg">
      <!-- Infrastructure Layer -->
      <rect x="10" y="10" width="780" height="175" rx="14" fill="#12131a" stroke="#6366f1" stroke-width="2"/>
      <text x="400" y="35" text-anchor="middle" fill="#6366f1" font-size="12" font-weight="700" letter-spacing="1">INFRASTRUCTURE LAYER — MCP SERVERS</text>
      <text x="400" y="52" text-anchor="middle" fill="#5a6380" font-size="11">Set up once by setup.sh. Shared by all sessions. All agents can call any of these.</text>

      <!-- Row 1: Core Appian servers -->
      <rect x="30" y="66" width="175" height="50" rx="8" fill="#1a1d27" stroke="#6366f1" stroke-width="1.5"/>
      <text x="117" y="86" text-anchor="middle" fill="#6366f1" font-size="11" font-weight="700">🧠 intelligence</text>
      <text x="117" y="102" text-anchor="middle" fill="#5a6380" font-size="9">Cloud + Live (read)</text>

      <rect x="215" y="66" width="145" height="50" rx="8" fill="#1a1d27" stroke="#10b981" stroke-width="1.5"/>
      <text x="287" y="86" text-anchor="middle" fill="#10b981" font-size="11" font-weight="700">✏️ a!migo</text>
      <text x="287" y="102" text-anchor="middle" fill="#5a6380" font-size="9">object CRUD (write)</text>

      <rect x="370" y="66" width="145" height="50" rx="8" fill="#1a1d27" stroke="#8b5cf6" stroke-width="1.5"/>
      <text x="442" y="86" text-anchor="middle" fill="#8b5cf6" font-size="11" font-weight="700">🚀 deployment</text>
      <text x="442" y="102" text-anchor="middle" fill="#5a6380" font-size="9">package &amp; deploy</text>

      <rect x="525" y="66" width="125" height="50" rx="8" fill="#1a1d27" stroke="#f59e0b" stroke-width="1.5"/>
      <text x="587" y="86" text-anchor="middle" fill="#f59e0b" font-size="11" font-weight="700">📊 data-gen</text>
      <text x="587" y="102" text-anchor="middle" fill="#5a6380" font-size="9">test data</text>

      <rect x="660" y="66" width="115" height="50" rx="8" fill="#1a1d27" stroke="#f59e0b" stroke-width="1.5"/>
      <text x="717" y="86" text-anchor="middle" fill="#f59e0b" font-size="11" font-weight="700">🦗 locust</text>
      <text x="717" y="102" text-anchor="middle" fill="#5a6380" font-size="9">perf tests</text>

      <!-- Row 2: Supporting servers -->
      <rect x="30" y="126" width="120" height="40" rx="8" fill="#1a1d27" stroke="#5a6380" stroke-width="1"/>
      <text x="90" y="150" text-anchor="middle" fill="#8892a8" font-size="11" font-weight="600">jira</text>

      <rect x="160" y="126" width="120" height="40" rx="8" fill="#1a1d27" stroke="#5a6380" stroke-width="1"/>
      <text x="220" y="150" text-anchor="middle" fill="#8892a8" font-size="11" font-weight="600">playwright</text>

      <rect x="290" y="126" width="120" height="40" rx="8" fill="#1a1d27" stroke="#5a6380" stroke-width="1"/>
      <text x="350" y="150" text-anchor="middle" fill="#8892a8" font-size="11" font-weight="600">google</text>

      <rect x="420" y="126" width="120" height="40" rx="8" fill="#1a1d27" stroke="#5a6380" stroke-width="1" stroke-dasharray="4,3"/>
      <text x="480" y="150" text-anchor="middle" fill="#5a6380" font-size="11">+ more...</text>

      <!-- Arrow -->
      <line x1="400" y1="185" x2="400" y2="210" stroke="#5a6380" stroke-width="2"/>
      <polygon points="394,207 400,217 406,207" fill="#5a6380"/>

      <!-- Knowledge Layer -->
      <rect x="10" y="220" width="780" height="170" rx="14" fill="#12131a" stroke="#10b981" stroke-width="2"/>
      <text x="400" y="245" text-anchor="middle" fill="#10b981" font-size="12" font-weight="700" letter-spacing="1">KNOWLEDGE LAYER — POWERS, SKILLS, AGENTS</text>
      <text x="400" y="262" text-anchor="middle" fill="#5a6380" font-size="11">Symlinked by setup.sh. Lightweight prompts + steering. No bundled MCP configs.</text>

      <!-- Power boxes -->
      <rect x="40" y="278" width="160" height="55" rx="8" fill="#1a1d27" stroke="#10b981" stroke-width="1.5"/>
      <text x="120" y="298" text-anchor="middle" fill="#e8eaf0" font-size="12" font-weight="700">developer</text>
      <text x="120" y="316" text-anchor="middle" fill="#5a6380" font-size="10">POWER.md + steering/</text>
      <text x="120" y="329" text-anchor="middle" fill="#10b981" font-size="9">calls: intelligence, a!migo</text>

      <rect x="220" y="278" width="160" height="55" rx="8" fill="#1a1d27" stroke="#10b981" stroke-width="1.5"/>
      <text x="300" y="298" text-anchor="middle" fill="#e8eaf0" font-size="12" font-weight="700">sql-forge</text>
      <text x="300" y="316" text-anchor="middle" fill="#5a6380" font-size="10">POWER.md + steering/</text>
      <text x="300" y="329" text-anchor="middle" fill="#10b981" font-size="9">calls: intelligence, data-gen</text>

      <rect x="400" y="278" width="160" height="55" rx="8" fill="#1a1d27" stroke="#10b981" stroke-width="1.5"/>
      <text x="480" y="298" text-anchor="middle" fill="#e8eaf0" font-size="12" font-weight="700">qe-agent</text>
      <text x="480" y="316" text-anchor="middle" fill="#5a6380" font-size="10">POWER.md + steering/</text>
      <text x="480" y="329" text-anchor="middle" fill="#10b981" font-size="9">calls: intelligence, playwright</text>

      <rect x="580" y="278" width="160" height="55" rx="8" fill="#1a1d27" stroke="#10b981" stroke-width="1.5" stroke-dasharray="4,3"/>
      <text x="660" y="305" text-anchor="middle" fill="#5a6380" font-size="12">+ more...</text>

      <text x="400" y="365" text-anchor="middle" fill="#10b981" font-size="12" font-weight="600">Powers don't bundle MCP configs — they call infrastructure tools directly</text>
      <text x="400" y="383" text-anchor="middle" fill="#5a6380" font-size="11">Adding a power = add a folder with POWER.md. Re-run setup.sh. Done.</text>
    </svg>
  </div>
</div>

<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 11: BOOTSTRAP — HOW IT WORKS -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<div class="slide" id="slide-18">
  <div class="slide-content">
    <div class="slide-label">Solution #3 — In Practice</div>
    <h2>One command does everything</h2>
    <p style="margin-bottom: 24px;">The new onboarding experience:</p>

    <div class="user-journey" style="margin-bottom: 32px;">
      <div class="journey-step" style="border-color: var(--green); color: var(--green);">git clone</div>
      <div class="journey-arrow">→</div>
      <div class="journey-step" style="border-color: var(--green); color: var(--green);">./setup.sh</div>
      <div class="journey-arrow">→</div>
      <div class="journey-step" style="border-color: var(--green); color: var(--green);">Start coding with AI</div>
    </div>

    <div class="two-col">
      <div>
        <h3 style="margin-bottom: 16px;">What <span class="kbd">./setup.sh</span> does</h3>
        <ol class="step-list">
          <li>Checks prerequisites (Docker, Kiro CLI)</li>
          <li>Creates <code>.env</code> from template, validates credentials</li>
          <li>Pulls Docker images for all MCP servers</li>
          <li>Writes unified MCP config to <code>~/.kiro/settings/mcp.json</code></li>
          <li>Symlinks all powers into <code>~/.kiro/powers/installed/</code></li>
          <li>Registers powers in Kiro's <code>installed.json</code></li>
          <li>Symlinks skills, agents, and steering files</li>
          <li>Verifies everything works</li>
        </ol>
      </div>
      <div>
        <h3 style="margin-bottom: 16px;">Maintenance commands</h3>
        <div class="card" style="font-family: 'SF Mono', monospace; font-size: 13px; line-height: 2.2;">
          <div><span style="color: var(--green);">./setup.sh</span>                <span style="color: var(--text-dim);"># Full install</span></div>
          <div><span style="color: var(--green);">./setup.sh --update</span>       <span style="color: var(--text-dim);"># After git pull</span></div>
          <div><span style="color: var(--green);">./setup.sh --verify</span>       <span style="color: var(--text-dim);"># Health check</span></div>
          <div><span style="color: var(--green);">./setup.sh --uninstall</span>    <span style="color: var(--text-dim);"># Clean removal</span></div>
          <div><span style="color: var(--green);">./setup.sh --profile eng</span>  <span style="color: var(--text-dim);"># Eng only</span></div>
        </div>

        <h3 style="margin-top: 24px; margin-bottom: 16px;">Why this works</h3>
        <div class="card" style="font-size: 14px; line-height: 1.8;">
          <div>✓ <strong>Idempotent</strong> — safe to re-run anytime</div>
          <div>✓ <strong>No drift</strong> — symlinks point to repo (git pull = updated)</div>
          <div>✓ <strong>No orphans</strong> — uninstall removes everything</div>
          <div>✓ <strong>Declarative</strong> — manifest file drives what's installed</div>
          <div>✓ <strong>Credential isolation</strong> — secrets in .env only</div>
        </div>
      </div>
    </div>
  </div>
</div>

<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 12: BOOTSTRAP — IMPACT ON POWER AUTHORS -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<div class="slide" id="slide-19">
  <div class="slide-content">
    <div class="slide-label">Solution #3 — Impact</div>
    <h2>What changes for power authors</h2>
    <p style="margin-bottom: 32px;">Powers become dramatically simpler to create and maintain.</p>

    <div class="grid-2">
      <div class="card" style="border-color: var(--red);">
        <h3 style="color: var(--red);">Before: Heavy powers</h3>
        <div style="font-family: monospace; font-size: 13px; margin-top: 16px; line-height: 1.8; color: var(--text-muted);">
          <div>my-power/</div>
          <div>├── POWER.md</div>
          <div>├── steering/</div>
          <div>│   └── workflow.md</div>
          <div style="color: var(--red);">├── mcp.json          ← Docker config</div>
          <div style="color: var(--red);">│   ├── cloud server   ← credentials</div>
          <div style="color: var(--red);">│   ├── live server    ← credentials</div>
          <div style="color: var(--red);">│   └── data-gen server← credentials</div>
          <div>└── ...</div>
          <div style="margin-top: 12px; color: var(--red);">Author must understand: Docker, MCP protocol,</div>
          <div style="color: var(--red);">registry auth, credential management, image tags</div>
        </div>
      </div>
      <div class="card" style="border-color: var(--green);">
        <h3 style="color: var(--green);">After: Lightweight powers</h3>
        <div style="font-family: monospace; font-size: 13px; margin-top: 16px; line-height: 1.8; color: var(--text-muted);">
          <div>my-power/</div>
          <div>├── POWER.md</div>
          <div>└── steering/</div>
          <div>    └── workflow.md</div>
          <div style="margin-top: 12px; color: var(--green);">That's it.</div>
          <div style="margin-top: 24px; color: var(--green);">Steering just says:</div>
          <div style="color: var(--green);">"Use get_app_overview to understand apps"</div>
          <div style="color: var(--green);">"Use search_objects to find code"</div>
          <div style="color: var(--green);">"Use get_dependencies to trace impact"</div>
          <div style="margin-top: 12px; color: var(--green);">Tools are already running. No config needed.</div>
          <div style="color: var(--green);">Author only needs to know: prompting.</div>
        </div>
      </div>
    </div>

    <div class="highlight-box mt-32">
      <p style="font-size: 15px;">
        <strong>Adding a new power to Solutions OS:</strong> Create a folder with POWER.md + steering, add one line to the manifest, re-run <code>./setup.sh</code>. No Docker knowledge. No MCP expertise. No credential handling.
      </p>
    </div>
  </div>
</div>

<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 13: SOLUTION 4 — REPO STRUCTURE + T.I.M.E. -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<div class="slide" id="slide-20">
  <div class="slide-content">
    <div class="slide-label">Solution #4</div>
    <h2>Repository Restructure + T.I.M.E. Framework</h2>
    <p style="margin-bottom: 24px;">Products organized by lifecycle stage. The folder structure itself becomes a workflow signal — AI agents know what to do based on where a file lives.</p>

    <div class="two-col">
      <div>
        <h3 style="margin-bottom: 16px;">T.I.M.E. Lifecycle per Product</h3>
        <div class="card" style="font-family: monospace; font-size: 13px; line-height: 2; color: var(--text-muted);">
          <div>products/&lt;product&gt;/</div>
          <div>├── <span style="color: var(--text-dim);">00-context/</span>     <span style="color: var(--text-dim);">← Ground truth</span></div>
          <div>├── <span style="color: var(--blue);">01-discovery/</span>   <span style="color: var(--text-dim);">← Raw ideas</span></div>
          <div>├── <span style="color: var(--purple);">02-refinement/</span>  <span style="color: var(--text-dim);">← Specs + prototypes</span></div>
          <div>├── <span style="color: var(--orange);">03-planning/</span>    <span style="color: var(--text-dim);">← Committed work</span></div>
          <div>├── <span style="color: var(--accent);">04-delivery/</span>    <span style="color: var(--text-dim);">← Active dev</span></div>
          <div>└── <span style="color: var(--green);">05-shipped/</span>     <span style="color: var(--text-dim);">← Released</span></div>
        </div>
      </div>
      <div>
        <h3 style="margin-bottom: 16px;">AI acts on transitions</h3>
        <div class="flex-col gap-16">
          <div class="card" style="padding: 14px 20px; font-size: 14px;">
            <span class="tag tag-blue">→ discovery</span>
            <span style="margin-left: 8px;">Scan for duplicates, flag dependencies</span>
          </div>
          <div class="card" style="padding: 14px 20px; font-size: 14px;">
            <span class="tag tag-purple">→ refinement</span>
            <span style="margin-left: 8px;">Expand into spec, draft prototype</span>
          </div>
          <div class="card" style="padding: 14px 20px; font-size: 14px;">
            <span class="tag tag-orange">→ planning</span>
            <span style="margin-left: 8px;">Break into tickets, estimate complexity</span>
          </div>
          <div class="card" style="padding: 14px 20px; font-size: 14px;">
            <span class="tag tag-purple" style="background: rgba(99, 102, 241, 0.15); color: var(--accent);">→ delivery</span>
            <span style="margin-left: 8px;">Generate design doc, create task breakdown</span>
          </div>
          <div class="card" style="padding: 14px 20px; font-size: 14px;">
            <span class="tag tag-green">→ shipped</span>
            <span style="margin-left: 8px;">Write release notes, archive</span>
          </div>
        </div>
      </div>
    </div>

    <div class="highlight-box mt-24">
      <p style="font-size: 15px;">Users just move files between folders. AI responds automatically. No commands to memorize.</p>
    </div>
  </div>
</div>

<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 14: EXTENSIBILITY — LIVING ECOSYSTEM -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<div class="slide" id="slide-21">
  <div class="slide-content">
    <div class="slide-label">Key Advantage #1</div>
    <h2>A living, extensible ecosystem</h2>
    <p style="margin-bottom: 16px;">Solutions OS isn't just powers. It's a central repository for <strong>every type of AI capability</strong> — powers, skills, agents, steering. Teams contribute incrementally; everyone benefits immediately.</p>

    <svg viewBox="0 0 800 360" style="width: 100%; max-width: 800px; margin: 0 auto; display: block;" xmlns="http://www.w3.org/2000/svg">
      <!-- Repo container -->
      <rect x="10" y="10" width="780" height="150" rx="14" fill="#12131a" stroke="#2e3348" stroke-width="2"/>
      <text x="400" y="35" text-anchor="middle" fill="#e8eaf0" font-size="13" font-weight="700">solutions-os repo (central, shared by all teams)</text>

      <!-- 4 capability columns -->
      <rect x="30" y="50" width="170" height="95" rx="8" fill="#1a1d27" stroke="#6366f1" stroke-width="1.5"/>
      <text x="115" y="72" text-anchor="middle" fill="#6366f1" font-size="12" font-weight="700">⚡ Powers</text>
      <text x="115" y="90" text-anchor="middle" fill="#5a6380" font-size="10">developer, sql-forge,</text>
      <text x="115" y="104" text-anchor="middle" fill="#5a6380" font-size="10">ux-designer, ...</text>
      <text x="115" y="132" text-anchor="middle" fill="#5a6380" font-size="9" font-style="italic">AI workflows</text>

      <rect x="215" y="50" width="170" height="95" rx="8" fill="#1a1d27" stroke="#10b981" stroke-width="1.5"/>
      <text x="300" y="72" text-anchor="middle" fill="#10b981" font-size="12" font-weight="700">📚 Skills</text>
      <text x="300" y="90" text-anchor="middle" fill="#5a6380" font-size="10">sail-reference, aurora,</text>
      <text x="300" y="104" text-anchor="middle" fill="#5a6380" font-size="10">a11y-audit, ...</text>
      <text x="300" y="132" text-anchor="middle" fill="#5a6380" font-size="9" font-style="italic">shared reference docs</text>

      <rect x="400" y="50" width="170" height="95" rx="8" fill="#1a1d27" stroke="#f59e0b" stroke-width="1.5"/>
      <text x="485" y="72" text-anchor="middle" fill="#f59e0b" font-size="12" font-weight="700">🤖 Agents</text>
      <text x="485" y="90" text-anchor="middle" fill="#5a6380" font-size="10">orchestrator, developer,</text>
      <text x="485" y="104" text-anchor="middle" fill="#5a6380" font-size="10">qe-agent, ...</text>
      <text x="485" y="132" text-anchor="middle" fill="#5a6380" font-size="9" font-style="italic">specialist sub-agents</text>

      <rect x="585" y="50" width="170" height="95" rx="8" fill="#1a1d27" stroke="#8892a8" stroke-width="1.5"/>
      <text x="670" y="72" text-anchor="middle" fill="#8892a8" font-size="12" font-weight="700">📋 Steering</text>
      <text x="670" y="90" text-anchor="middle" fill="#5a6380" font-size="10">git-workflow, naming,</text>
      <text x="670" y="104" text-anchor="middle" fill="#5a6380" font-size="10">code-standards, ...</text>
      <text x="670" y="132" text-anchor="middle" fill="#5a6380" font-size="9" font-style="italic">global directives</text>

      <!-- Arrow down -->
      <rect x="310" y="172" width="180" height="30" rx="15" fill="#242836" stroke="#10b981" stroke-width="1.5"/>
      <text x="400" y="192" text-anchor="middle" fill="#10b981" font-size="12" font-weight="700">./setup.sh</text>
      <line x1="400" y1="202" x2="400" y2="225" stroke="#10b981" stroke-width="2"/>
      <polygon points="394,222 400,232 406,222" fill="#10b981"/>

      <!-- User machine -->
      <rect x="10" y="235" width="780" height="115" rx="14" fill="#12131a" stroke="#10b981" stroke-width="2"/>
      <text x="400" y="258" text-anchor="middle" fill="#10b981" font-size="12" font-weight="700">User's machine (~/.kiro/)</text>
      <text x="400" y="275" text-anchor="middle" fill="#5a6380" font-size="11">Everything symlinked — always in sync with git pull</text>

      <!-- Symlink arrows -->
      <text x="120" y="302" text-anchor="middle" fill="#6366f1" font-size="11">powers/ →</text>
      <text x="300" y="302" text-anchor="middle" fill="#10b981" font-size="11">skills/ →</text>
      <text x="480" y="302" text-anchor="middle" fill="#f59e0b" font-size="11">agents/ →</text>
      <text x="660" y="302" text-anchor="middle" fill="#8892a8" font-size="11">steering/ →</text>

      <!-- Key message -->
      <text x="400" y="335" text-anchor="middle" fill="#e8eaf0" font-size="12" font-weight="600">Orchestrator invokes skills &amp; agents on demand — including ones added after it was written</text>
    </svg>

    <div class="grid-2 mt-24">
      <div class="card">
        <h3>🧩 Incremental growth</h3>
        <p style="font-size: 14px;">Anyone on the team creates a new skill or agent → adds it to the repo → next <code>./setup.sh --update</code> and it's available to everyone. No deployment. No coordination.</p>
      </div>
      <div class="card">
        <h3>🤖 Orchestrator-driven invocation</h3>
        <p style="font-size: 14px;">The orchestrator sees all registered agents and skills. When a user's request matches a specialist capability, it delegates automatically — <em>including capabilities that didn't exist when the orchestrator was written.</em></p>
      </div>
      <div class="card">
        <h3>📚 Skills as shared knowledge</h3>
        <p style="font-size: 14px;">Skills are reusable reference docs (SAIL patterns, a11y rules, Aurora specs) that any agent or power can load on demand. Write once, used by all 8+ agents.</p>
      </div>
      <div class="card">
        <h3>🔄 Agents as composable units</h3>
        <p style="font-size: 14px;">Sub-agents can invoke other sub-agents. The developer agent can call sql-forge for data model questions. The QE agent can call a11y-fixer when it finds violations. Modular composition.</p>
      </div>
    </div>

    <div class="highlight-box mt-24">
      <p style="font-size: 15px;">
        <strong>The compound effect:</strong> Every new skill or agent added to Solutions OS makes every <em>other</em> agent smarter. A new "performance-patterns" skill instantly improves the developer, code-reviewer, and qe-agent — without touching their code.
      </p>
    </div>
  </div>
</div>

<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 15: PLATFORM AGNOSTICISM -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<div class="slide" id="slide-22">
  <div class="slide-content">
    <div class="slide-label">Key Advantage #2</div>
    <h2>Platform agnostic — write once, configure anywhere</h2>
    <p style="margin-bottom: 16px;">The entire Solutions OS knowledge layer (powers, skills, agents, product context, workflows) is <strong>platform-independent</strong>. Only the setup script is platform-specific.</p>

    <svg viewBox="0 0 800 350" style="width: 100%; max-width: 800px; margin: 0 auto; display: block;" xmlns="http://www.w3.org/2000/svg">
      <!-- The Product (top) -->
      <rect x="10" y="10" width="780" height="110" rx="14" fill="#12131a" stroke="#6366f1" stroke-width="2"/>
      <text x="400" y="38" text-anchor="middle" fill="#6366f1" font-size="14" font-weight="700">Solutions OS Repository (THE PRODUCT)</text>
      <text x="400" y="60" text-anchor="middle" fill="#e8eaf0" font-size="12" font-weight="600">This NEVER changes regardless of which AI platform we use</text>
      <text x="400" y="82" text-anchor="middle" fill="#5a6380" font-size="11">Powers · Skills · Agents · Products · MCP Servers · T.I.M.E. folders</text>
      <text x="400" y="102" text-anchor="middle" fill="#5a6380" font-size="11">All knowledge, all workflows, all product context</text>

      <!-- Arrows -->
      <line x1="200" y1="120" x2="150" y2="165" stroke="#6366f1" stroke-width="2"/>
      <polygon points="145,161 150,172 156,163" fill="#6366f1"/>
      <line x1="400" y1="120" x2="400" y2="165" stroke="#f59e0b" stroke-width="2"/>
      <polygon points="394,161 400,172 406,163" fill="#f59e0b"/>
      <line x1="600" y1="120" x2="650" y2="165" stroke="#10b981" stroke-width="2"/>
      <polygon points="645,161 650,172 656,163" fill="#10b981"/>

      <text x="400" y="148" text-anchor="middle" fill="#8892a8" font-size="10">one thin adapter script per platform</text>

      <!-- Three platform boxes -->
      <rect x="30" y="175" width="220" height="160" rx="12" fill="#1a1d27" stroke="#6366f1" stroke-width="2"/>
      <text x="140" y="200" text-anchor="middle" fill="#6366f1" font-size="14" font-weight="700">Kiro</text>
      <text x="140" y="218" text-anchor="middle" fill="#6366f1" font-size="11">(today)</text>
      <rect x="60" y="230" width="160" height="28" rx="6" fill="#242836" stroke="#6366f1" stroke-width="1"/>
      <text x="140" y="249" text-anchor="middle" fill="#6366f1" font-size="11" font-weight="600">setup-kiro.sh</text>
      <text x="140" y="278" text-anchor="middle" fill="#5a6380" font-size="10">→ ~/.kiro/powers/</text>
      <text x="140" y="294" text-anchor="middle" fill="#5a6380" font-size="10">→ ~/.kiro/skills/</text>
      <text x="140" y="310" text-anchor="middle" fill="#5a6380" font-size="10">→ ~/.kiro/agents/</text>

      <rect x="290" y="175" width="220" height="160" rx="12" fill="#1a1d27" stroke="#f59e0b" stroke-width="2"/>
      <text x="400" y="200" text-anchor="middle" fill="#f59e0b" font-size="14" font-weight="700">Claude Code</text>
      <text x="400" y="218" text-anchor="middle" fill="#f59e0b" font-size="11">(proven by buildwithclaude)</text>
      <rect x="320" y="230" width="160" height="28" rx="6" fill="#242836" stroke="#f59e0b" stroke-width="1"/>
      <text x="400" y="249" text-anchor="middle" fill="#f59e0b" font-size="11" font-weight="600">setup-claude.sh</text>
      <text x="400" y="278" text-anchor="middle" fill="#5a6380" font-size="10">→ ~/.claude/skills/</text>
      <text x="400" y="294" text-anchor="middle" fill="#5a6380" font-size="10">→ ~/.claude/settings/</text>
      <text x="400" y="310" text-anchor="middle" fill="#5a6380" font-size="10">→ .mcp.json</text>

      <rect x="550" y="175" width="220" height="160" rx="12" fill="#1a1d27" stroke="#10b981" stroke-width="2"/>
      <text x="660" y="200" text-anchor="middle" fill="#10b981" font-size="14" font-weight="700">Gemini CLI</text>
      <text x="660" y="218" text-anchor="middle" fill="#10b981" font-size="11">(already have .gemini/ in repo)</text>
      <rect x="580" y="230" width="160" height="28" rx="6" fill="#242836" stroke="#10b981" stroke-width="1"/>
      <text x="660" y="249" text-anchor="middle" fill="#10b981" font-size="11" font-weight="600">setup-gemini.sh</text>
      <text x="660" y="278" text-anchor="middle" fill="#5a6380" font-size="10">→ ~/.gemini/commands/</text>
      <text x="660" y="294" text-anchor="middle" fill="#5a6380" font-size="10">→ ~/.gemini/settings/</text>
      <text x="660" y="310" text-anchor="middle" fill="#5a6380" font-size="10">→ .mcp.json</text>
    </svg>

    <div class="grid-2 mt-24">
      <div class="card" style="border-left: 3px solid var(--accent);">
        <h3>What stays constant (the product)</h3>
        <ul style="font-size: 14px; color: var(--text-muted); line-height: 2; list-style: none; padding: 0;">
          <li>✓ All product knowledge and context</li>
          <li>✓ All power steering and workflows</li>
          <li>✓ All skill reference documentation</li>
          <li>✓ All agent definitions and prompts</li>
          <li>✓ MCP server Docker images (standard protocol)</li>
          <li>✓ T.I.M.E. lifecycle structure</li>
          <li>✓ The manifest file (what's installable)</li>
        </ul>
      </div>
      <div class="card" style="border-left: 3px solid var(--green);">
        <h3>What changes per platform (thin adapter)</h3>
        <ul style="font-size: 14px; color: var(--text-muted); line-height: 2; list-style: none; padding: 0;">
          <li>→ Where configs are written (~/.kiro vs ~/.claude)</li>
          <li>→ Config file format (JSON shape varies)</li>
          <li>→ How MCP servers are registered</li>
          <li>→ How skills/powers are loaded</li>
          <li>→ Platform-specific naming conventions</li>
          <li style="margin-top: 8px; color: var(--green); font-weight: 600;">= One script per platform. That's it.</li>
        </ul>
      </div>
    </div>

    <div class="highlight-box mt-24">
      <p style="font-size: 15px;">
        <strong>Why this matters:</strong> AI tooling moves fast. If a better platform emerges next quarter, we don't rewrite Solutions OS — we write a 100-line setup script for the new platform. All knowledge, all workflows, all product context carries forward. <strong>Zero vendor lock-in.</strong>
      </p>
    </div>
  </div>
</div>

<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 16: ENVIRONMENT REGISTRY -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<div class="slide" id="slide-23">
  <div class="slide-content">
    <div class="slide-label">Supporting Infrastructure</div>
    <h2>Centralized Environment Registry</h2>
    <p style="margin-bottom: 24px;">Teams work across multiple Appian environments. Today credentials are scattered across individual configs. The registry centralizes this.</p>

    <div class="two-col">
      <div>
        <h3 style="margin-bottom: 16px;">Shared registry (committed to repo)</h3>
        <div class="card" style="font-family: 'SF Mono', monospace; font-size: 12px; line-height: 1.8; color: var(--text-muted);">
          <div style="color: var(--accent);">// environments.json</div>
          <div>{</div>
          <div>  "<span style="color: var(--green);">gam-dev2</span>": {</div>
          <div>    "url": "https://...dev2.appianpreview.com",</div>
          <div>    "products": ["source-selection", "vendor-mgmt"],</div>
          <div>    "type": "development"</div>
          <div>  },</div>
          <div>  "<span style="color: var(--green);">cms-dev</span>": {</div>
          <div>    "url": "https://...cms-dev.appianpreview.com",</div>
          <div>    "products": ["case-management-studio"],</div>
          <div>    "type": "development"</div>
          <div>  },</div>
          <div>  "<span style="color: var(--green);">solutions-global</span>": { ... }</div>
          <div>}</div>
        </div>
      </div>
      <div>
        <h3 style="margin-bottom: 16px;">How agents use it</h3>
        <div class="flex-col gap-16">
          <div class="card" style="padding: 14px 20px; font-size: 14px;">
            <span class="tag tag-green">Auto-select</span>
            <span style="margin-left: 8px;">Working on CMS? Agent picks cms-dev automatically</span>
          </div>
          <div class="card" style="padding: 14px 20px; font-size: 14px;">
            <span class="tag tag-blue">Multi-env</span>
            <span style="margin-left: 8px;">"Compare schema between dev and staging" → queries both</span>
          </div>
          <div class="card" style="padding: 14px 20px; font-size: 14px;">
            <span class="tag tag-purple">Secure</span>
            <span style="margin-left: 8px;">URLs in registry (safe). API keys in ~/.credentials (private).</span>
          </div>
          <div class="card" style="padding: 14px 20px; font-size: 14px;">
            <span class="tag tag-orange">Switching</span>
            <span style="margin-left: 8px;">"Deploy to staging" → resolves env by name/type</span>
          </div>
        </div>

        <div class="highlight-box mt-24">
          <p style="font-size: 14px;">No more hardcoded URLs in power configs. No more "which environment am I pointed at?"</p>
        </div>
      </div>
    </div>
  </div>
</div>

<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 17: KNOWLEDGE BASE STRATEGY -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<div class="slide" id="slide-24">
  <div class="slide-content">
    <div class="slide-label">Knowledge Architecture</div>
    <h2>Two knowledge layers, one platform</h2>
    <p style="margin-bottom: 32px;">Solutions OS serves two distinct types of intelligence — and they answer fundamentally different questions.</p>

    <div class="grid-2">
      <div class="card" style="border-top: 3px solid var(--purple);">
        <h3 style="color: var(--purple);">📚 Product Knowledge</h3>
        <p style="font-size: 14px; margin-bottom: 12px; color: var(--text);">"What should we build and why?"</p>
        <div style="font-size: 13px; color: var(--text-muted); line-height: 1.8;">
          <div><strong>Source:</strong> <code>products/</code> folders (T.I.M.E. structure)</div>
          <div><strong>Contains:</strong> Vision, personas, feature specs, decisions, competitive analysis</div>
          <div><strong>Indexed by:</strong> Kiro's knowledge base engine (auto-updates on git pull)</div>
          <div><strong>Used by:</strong> Orchestrator, product-owner agent</div>
        </div>
      </div>
      <div class="card" style="border-top: 3px solid var(--blue);">
        <h3 style="color: var(--blue);">🔧 Application Knowledge</h3>
        <p style="font-size: 14px; margin-bottom: 12px; color: var(--text);">"What exists in the code and how does it work?"</p>
        <div style="font-size: 13px; color: var(--text-muted); line-height: 1.8;">
          <div><strong>Source:</strong> Solutions Parser → GitLab KB (JSON)</div>
          <div><strong>Contains:</strong> Parsed code, objects, dependencies, schema, bundles, versions</div>
          <div><strong>Accessed via:</strong> Unified MCP tools (queried on demand, not pre-indexed)</div>
          <div><strong>Used by:</strong> Developer, sql-forge, code-reviewer agents</div>
        </div>
      </div>
    </div>

    <svg viewBox="0 0 700 280" style="width: 100%; max-width: 700px; margin: 20px auto; display: block;" xmlns="http://www.w3.org/2000/svg">
      <!-- Source -->
      <rect x="200" y="5" width="300" height="40" rx="8" fill="#1a1d27" stroke="#5a6380" stroke-width="1.5"/>
      <text x="350" y="30" text-anchor="middle" fill="#8892a8" font-size="12">Appian .zip packages (test environments)</text>

      <!-- Arrow -->
      <line x1="350" y1="45" x2="350" y2="70" stroke="#5a6380" stroke-width="2"/>
      <polygon points="344,67 350,77 356,67" fill="#5a6380"/>

      <!-- Parser -->
      <rect x="200" y="80" width="300" height="45" rx="10" fill="#1a1d27" stroke="#6366f1" stroke-width="2"/>
      <text x="350" y="105" text-anchor="middle" fill="#6366f1" font-size="14" font-weight="700">Solutions Parser</text>
      <text x="350" y="120" text-anchor="middle" fill="#5a6380" font-size="10">single KB generation engine</text>

      <!-- Split arrows -->
      <line x1="280" y1="125" x2="180" y2="165" stroke="#6366f1" stroke-width="2"/>
      <polygon points="174,161 180,172 186,163" fill="#6366f1"/>
      <line x1="420" y1="125" x2="520" y2="165" stroke="#10b981" stroke-width="2"/>
      <polygon points="514,161 520,172 526,163" fill="#10b981"/>

      <!-- Cloud output -->
      <rect x="30" y="175" width="300" height="90" rx="10" fill="#1a1d27" stroke="#6366f1" stroke-width="1.5"/>
      <text x="180" y="200" text-anchor="middle" fill="#6366f1" font-size="13" font-weight="700">☁️ GitLab KB (Cloud Plane)</text>
      <text x="180" y="220" text-anchor="middle" fill="#5a6380" font-size="11">Versioned JSON snapshots</text>
      <text x="180" y="238" text-anchor="middle" fill="#5a6380" font-size="10">bundles · objects · code · graph</text>
      <text x="180" y="254" text-anchor="middle" fill="#5a6380" font-size="10">versions · schema</text>

      <!-- Live output -->
      <rect x="370" y="175" width="300" height="90" rx="10" fill="#1a1d27" stroke="#10b981" stroke-width="1.5"/>
      <text x="520" y="200" text-anchor="middle" fill="#10b981" font-size="13" font-weight="700">⚡ Solutions KB App (Live)</text>
      <text x="520" y="220" text-anchor="middle" fill="#5a6380" font-size="11">Optional — per-environment</text>
      <text x="520" y="238" text-anchor="middle" fill="#5a6380" font-size="10">clusters · patterns · architecture</text>
      <text x="520" y="254" text-anchor="middle" fill="#5a6380" font-size="10">staleness tracking</text>
    </svg>
  </div>
</div>

<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 18: SWAT-A-PALOOZA INTEGRATION -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<div class="slide" id="slide-25">
  <div class="slide-content">
    <div class="slide-label">Proven Feasibility</div>
    <h2>20 SWAT-a-Palooza projects — all fit</h2>
    <p style="margin-bottom: 24px;">Every hackathon project maps cleanly into the revamped architecture. This isn't theoretical — it's designed to accommodate real work already built.</p>

    <div class="grid-3" style="grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));">
      <div class="card" style="padding: 20px;">
        <div style="display: flex; align-items: center; gap: 10px; margin-bottom: 12px;">
          <span class="tag tag-red">A11Y</span>
          <span style="font-size: 13px; font-weight: 600;">2 projects</span>
        </div>
        <div style="font-size: 13px; color: var(--text-muted); line-height: 1.7;">
          A11Y Fixer → <strong>a11y-fixer agent</strong><br>
          A11y Audit → <strong>skill</strong> (shared by 3 agents)
        </div>
      </div>
      <div class="card" style="padding: 20px;">
        <div style="display: flex; align-items: center; gap: 10px; margin-bottom: 12px;">
          <span class="tag tag-orange">DATA</span>
          <span style="font-size: 13px; font-weight: 600;">2 projects</span>
        </div>
        <div style="font-size: 13px; color: var(--text-muted); line-height: 1.7;">
          SQL Forge → <strong>sql-forge agent</strong><br>
          DataForge → <strong>sql-forge capability</strong>
        </div>
      </div>
      <div class="card" style="padding: 20px;">
        <div style="display: flex; align-items: center; gap: 10px; margin-bottom: 12px;">
          <span class="tag tag-purple">UX</span>
          <span style="font-size: 13px; font-weight: 600;">4 projects</span>
        </div>
        <div style="font-size: 13px; color: var(--text-muted); line-height: 1.7;">
          UX Enhancements → <strong>ux-designer agent</strong><br>
          Kiro→FigJam, Spec→Slides, SAIL Canvas → <strong>agent capabilities</strong>
        </div>
      </div>
      <div class="card" style="padding: 20px;">
        <div style="display: flex; align-items: center; gap: 10px; margin-bottom: 12px;">
          <span class="tag tag-blue">DEV</span>
          <span style="font-size: 13px; font-weight: 600;">5 projects</span>
        </div>
        <div style="font-size: 13px; color: var(--text-muted); line-height: 1.7;">
          Sweep, Perf-Profiler, LCP/a!migo, SAIL-to-SQL, Assert → <strong>developer agent capabilities</strong>
        </div>
      </div>
      <div class="card" style="padding: 20px;">
        <div style="display: flex; align-items: center; gap: 10px; margin-bottom: 12px;">
          <span class="tag tag-green">QE</span>
          <span style="font-size: 13px; font-weight: 600;">2 projects</span>
        </div>
        <div style="font-size: 13px; color: var(--text-muted); line-height: 1.7;">
          Test Execution Agent → <strong>qe-agent</strong><br>
          Expression Assert → <strong>developer capability</strong>
        </div>
      </div>
      <div class="card" style="padding: 20px;">
        <div style="display: flex; align-items: center; gap: 10px; margin-bottom: 12px;">
          <span class="tag tag-purple" style="background: rgba(245, 158, 11, 0.15); color: var(--orange);">DOCS</span>
          <span style="font-size: 13px; font-weight: 600;">5 projects</span>
        </div>
        <div style="font-size: 13px; color: var(--text-muted); line-height: 1.7;">
          Feature Doc Genie, ERD Gen → <strong>agent capabilities</strong><br>
          T.I.M.E. → <strong>core structure</strong><br>
          KB Maintenance, Sprint Report → <strong>skill + automation</strong>
        </div>
      </div>
    </div>

    <div class="highlight-box mt-24">
      <p style="font-size: 15px;">
        <strong>Why every project fits:</strong> Unified MCP gives all agents access to both data planes. The orchestrator auto-routes to the right specialist. Environment registry handles multi-env targeting. Skills share reference knowledge across all agents. No project needs to be rewritten — just repositioned.
      </p>
    </div>
  </div>
</div>

<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 19: OWNERSHIP + RISKS + METRICS -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<div class="slide" id="slide-26">
  <div class="slide-content">
    <div class="slide-label">Governance</div>
    <h2>Ownership, risks, and success metrics</h2>

    <div class="two-col" style="margin-bottom: 24px;">
      <div>
        <h3 style="margin-bottom: 16px;">Ownership model</h3>
        <table class="comparison-table" style="font-size: 13px;">
          <thead><tr><th>Component</th><th>Owner</th></tr></thead>
          <tbody>
            <tr><td>Solutions Parser + Cloud Plane</td><td><strong>Ram</strong></td></tr>
            <tr><td>Live Plane + Solutions KB App</td><td><strong>Soma</strong></td></tr>
            <tr><td>Unified MCP Server</td><td><strong>Joint</strong></td></tr>
            <tr><td>Data Generator</td><td><strong>Ram</strong></td></tr>
            <tr><td>Orchestrator + Setup</td><td><strong>Ram</strong></td></tr>
            <tr><td>Product folder conventions</td><td><strong>All teams</strong></td></tr>
          </tbody>
        </table>
      </div>
      <div>
        <h3 style="margin-bottom: 16px;">Success metrics</h3>
        <table class="comparison-table" style="font-size: 13px;">
          <thead><tr><th>Metric</th><th>Target</th></tr></thead>
          <tbody>
            <tr><td>Onboarding time</td><td style="color: var(--green);"><strong>< 5 min</strong></td></tr>
            <tr><td>Users with 3+ capabilities</td><td style="color: var(--green);"><strong>> 70%</strong></td></tr>
            <tr><td>Power install support tickets</td><td style="color: var(--green);"><strong>0</strong></td></tr>
            <tr><td>Duplicated powers</td><td style="color: var(--green);"><strong>0</strong></td></tr>
            <tr><td>Products with steering files</td><td style="color: var(--green);"><strong>100%</strong></td></tr>
            <tr><td>Sub-agent delegation success</td><td style="color: var(--green);"><strong>> 90%</strong></td></tr>
          </tbody>
        </table>
      </div>
    </div>

    <h3 style="margin-bottom: 16px;">Risk assessment</h3>
    <div class="grid-2" style="grid-template-columns: 1fr 1fr;">
      <div class="card" style="padding: 16px 20px;">
        <div style="display: flex; align-items: center; gap: 10px; margin-bottom: 8px;">
          <span class="tag tag-orange">MEDIUM</span>
          <strong style="font-size: 14px;">Dev resistance to merge</strong>
        </div>
        <p style="font-size: 13px;">Mitigation: Clear ownership model — neither tool "loses." Both devs retain their domain.</p>
      </div>
      <div class="card" style="padding: 16px 20px;">
        <div style="display: flex; align-items: center; gap: 10px; margin-bottom: 8px;">
          <span class="tag tag-orange">MEDIUM</span>
          <strong style="font-size: 14px;">Breaking existing workflows</strong>
        </div>
        <p style="font-size: 13px;">Mitigation: Old powers kept running until new agents are verified. Parallel operation.</p>
      </div>
      <div class="card" style="padding: 16px 20px;">
        <div style="display: flex; align-items: center; gap: 10px; margin-bottom: 8px;">
          <span class="tag tag-orange">MEDIUM</span>
          <strong style="font-size: 14px;">Context window bloat (too many tools)</strong>
        </div>
        <p style="font-size: 13px;">Mitigation: Dynamic tool registration — agents only see tools for their configured planes.</p>
      </div>
      <div class="card" style="padding: 16px 20px;">
        <div style="display: flex; align-items: center; gap: 10px; margin-bottom: 8px;">
          <span class="tag tag-red">HIGH LIKELIHOOD</span>
          <strong style="font-size: 14px;">Teams don't update product folders</strong>
        </div>
        <p style="font-size: 13px;">Mitigation: CI enforcement, workshops, champion per product team.</p>
      </div>
    </div>
  </div>
</div>

<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 20: IMPLEMENTATION TIMELINE -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 16: IMPLEMENTATION TIMELINE -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 20: IMPLEMENTATION TIMELINE -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<div class="slide" id="slide-27">
  <div class="slide-content">
    <div class="slide-label">Implementation</div>
    <h2>6-week rollout plan</h2>
    <p style="margin-bottom: 32px;">Phased delivery with clear exit criteria at each stage. No big bang — incremental value delivery.</p>

    <div class="timeline">
      <div class="timeline-item">
        <h4>Phase 1: Unified MCP Server (Weeks 1–3)</h4>
        <p>Unify Cloud + Live + Data Gen planes into single Docker image. Smart router. CI pipeline for builds.</p>
        <div style="margin-top: 8px;"><span class="tag tag-blue">Ram</span> <span class="tag tag-green">Soma</span></div>
        <div style="margin-top: 8px; font-size: 13px; color: var(--text-dim);">Exit: <code>docker run solutions-intelligence</code> → all tools available via single connection</div>
      </div>
      <div class="timeline-item">
        <h4>Phase 2: Orchestrator + Bootstrap (Weeks 2–4)</h4>
        <p>Orchestrator agent, sub-agents, setup.sh, manifest, credential sync hook. Remove mcp.json from powers.</p>
        <div style="margin-top: 8px;"><span class="tag tag-blue">Ram</span> <span class="tag tag-green">Soma</span></div>
        <div style="margin-top: 8px; font-size: 13px; color: var(--text-dim);">Exit: <code>./setup.sh && kiro-cli --agent solutions-os</code> → everything works, no power carries mcp.json</div>
      </div>
      <div class="timeline-item">
        <h4>Phase 3: Repo Restructure (Weeks 4–5)</h4>
        <p>T.I.M.E. folders, enforced conventions, CI checks, remove deprecated paths, update docs.</p>
        <div style="margin-top: 8px;"><span class="tag tag-blue">Ram</span> <span class="tag tag-orange">All teams</span></div>
        <div style="margin-top: 8px; font-size: 13px; color: var(--text-dim);">Exit: Repo matches new structure. CI passes. No references to old power paths.</div>
      </div>
      <div class="timeline-item">
        <h4>Phase 4: Migration & Deprecation (Weeks 5–6)</h4>
        <p>Migration guide, workshop, verify SWAT projects, remove old images, update documentation.</p>
        <div style="margin-top: 8px;"><span class="tag tag-blue">Ram</span> <span class="tag tag-green">Soma</span> <span class="tag tag-orange">All teams</span></div>
        <div style="margin-top: 8px; font-size: 13px; color: var(--text-dim);">Exit: Zero users on old workflow. All teams using orchestrator.</div>
      </div>
    </div>
  </div>
</div>

<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 15: REFERENCE — BUILDWITHCLAUDE -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<div class="slide" id="slide-28">
  <div class="slide-content">
    <div class="slide-label">Reference Architecture</div>
    <h2>Proven pattern: <code>buildwithclaude</code></h2>
    <p style="margin-bottom: 24px;">John Rogers' project demonstrates this exact approach for Claude Code + Appian. We're adapting the same principles for Kiro + Solutions OS at larger scale.</p>

    <table class="comparison-table">
      <thead>
        <tr><th>Aspect</th><th>buildwithclaude (Claude)</th><th>Solutions OS (Kiro)</th></tr>
      </thead>
      <tbody>
        <tr><td><strong>Setup</strong></td><td><code>./setup.sh</code></td><td><code>./setup.sh</code></td></tr>
        <tr><td><strong>Credentials</strong></td><td>.env → .claude/settings.local.json</td><td>.env → ~/.kiro/settings/mcp.json</td></tr>
        <tr><td><strong>Knowledge</strong></td><td>Skills symlinked to ~/.claude/skills/</td><td>Powers + skills symlinked to ~/.kiro/</td></tr>
        <tr><td><strong>MCP servers</strong></td><td>1 unified (150+ tools)</td><td>1 unified (60+ tools) + Jira + Playwright</td></tr>
        <tr><td><strong>Adding capabilities</strong></td><td>Add skill folder → re-run setup</td><td>Add power folder → re-run setup</td></tr>
        <tr><td><strong>Credential refresh</strong></td><td>PostToolUse hook auto-syncs</td><td>PostToolUse hook auto-syncs</td></tr>
        <tr><td><strong>Selective install</strong></td><td>N/A (all skills always on)</td><td>--profile engineering/product/minimal</td></tr>
        <tr><td><strong>Teardown</strong></td><td>Manual</td><td><code>./setup.sh --uninstall</code></td></tr>
      </tbody>
    </table>

    <div class="highlight-box mt-24">
      <p style="font-size: 15px;">
        <strong>buildwithclaude</strong> proves this works at Appian. We're scaling it from "one MCP server for one tool" to "one MCP server for an entire AI development platform." Same pattern, bigger scope.
      </p>
    </div>
  </div>
</div>

<!-- ═══════════════════════════════════════════════════════════════════════ -->
<!-- SLIDE 16: CLOSING -->
<!-- ═══════════════════════════════════════════════════════════════════════ -->
<div class="slide" id="slide-29">
  <div class="slide-content" style="align-items: center; text-align: center;">
    <div class="slide-label">Summary</div>
    <h1 class="gradient-text" style="max-width: 800px;">One repo. One command. Every capability.</h1>
    <p class="large" style="margin-top: 16px; max-width: 700px;">
      Solutions OS becomes a platform that's as easy to install as it is powerful to use.
    </p>

    <div class="grid-2 mt-40" style="max-width: 800px; width: 100%;">
      <div class="card stat-card" style="border-color: var(--red);">
        <div style="font-size: 14px; color: var(--red); font-weight: 600; margin-bottom: 12px;">TODAY</div>
        <div class="stat-value" style="color: var(--red); font-size: 32px;">30-60 min</div>
        <div class="stat-label">to first interaction</div>
        <div style="margin-top: 12px; font-size: 13px; color: var(--text-dim);">3+ MCP configs · manual power install · scattered credentials</div>
      </div>
      <div class="card stat-card" style="border-color: var(--green);">
        <div style="font-size: 14px; color: var(--green); font-weight: 600; margin-bottom: 12px;">AFTER REVAMP</div>
        <div class="stat-value" style="color: var(--green); font-size: 32px;">< 5 min</div>
        <div class="stat-label">to first interaction</div>
        <div style="margin-top: 12px; font-size: 13px; color: var(--text-dim);">1 command · all powers · centralized · maintainable</div>
      </div>
    </div>

    <div class="mt-40" style="display: flex; gap: 16px; flex-wrap: wrap; justify-content: center;">
      <span class="tag tag-green" style="font-size: 14px; padding: 8px 16px;">✓ Unified MCP</span>
      <span class="tag tag-blue" style="font-size: 14px; padding: 8px 16px;">✓ Orchestrator Agent</span>
      <span class="tag tag-purple" style="font-size: 14px; padding: 8px 16px;">✓ One-Command Setup</span>
      <span class="tag tag-orange" style="font-size: 14px; padding: 8px 16px;">✓ T.I.M.E. Framework</span>
    </div>

    <p style="margin-top: 40px; font-size: 16px; color: var(--text-muted);">
      6 weeks · 4 phases · Clear ownership · Proven pattern
    </p>
  </div>
</div>


<div class="nav-bar">
  <div class="nav-progress" id="nav-progress"></div>
  <div class="nav-buttons">
    <span class="slide-counter" id="slide-counter">1 / 29</span>
    <button class="nav-btn" id="btn-prev" disabled>← Back</button>
    <button class="nav-btn primary" id="btn-next">Next →</button>
  </div>
</div>

<script>
const slides = document.querySelectorAll('.slide');
const totalSlides = slides.length;
let currentSlide = 0;

const progress = document.getElementById('nav-progress');
const counter = document.getElementById('slide-counter');
const btnPrev = document.getElementById('btn-prev');
const btnNext = document.getElementById('btn-next');

// Build dots
for (let i = 0; i < totalSlides; i++) {
  const dot = document.createElement('div');
  dot.className = 'nav-dot' + (i === 0 ? ' active' : '');
  dot.addEventListener('click', () => goToSlide(i));
  progress.appendChild(dot);
}

function goToSlide(n) {
  slides[currentSlide].classList.remove('active');
  currentSlide = Math.max(0, Math.min(n, totalSlides - 1));
  slides[currentSlide].classList.add('active');
  updateNav();
  animateSlideContent();
}

function updateNav() {
  counter.textContent = `${currentSlide + 1} / ${totalSlides}`;
  btnPrev.disabled = currentSlide === 0;
  btnNext.textContent = currentSlide === totalSlides - 1 ? 'Done ✓' : 'Next →';
  
  const dots = progress.querySelectorAll('.nav-dot');
  dots.forEach((dot, i) => {
    dot.className = 'nav-dot';
    if (i === currentSlide) dot.classList.add('active');
    else if (i < currentSlide) dot.classList.add('visited');
  });
}

function animateSlideContent() {
  const items = slides[currentSlide].querySelectorAll('.animate-in');
  items.forEach((item, i) => {
    item.classList.remove('visible');
    setTimeout(() => item.classList.add('visible'), 150 * (i + 1));
  });
}

btnNext.addEventListener('click', () => {
  if (currentSlide < totalSlides - 1) goToSlide(currentSlide + 1);
});
btnPrev.addEventListener('click', () => {
  if (currentSlide > 0) goToSlide(currentSlide - 1);
});

// Keyboard navigation
document.addEventListener('keydown', (e) => {
  if (e.key === 'ArrowRight' || e.key === ' ') { e.preventDefault(); goToSlide(currentSlide + 1); }
  if (e.key === 'ArrowLeft') { e.preventDefault(); goToSlide(currentSlide - 1); }
  if (e.key === 'Home') { e.preventDefault(); goToSlide(0); }
  if (e.key === 'End') { e.preventDefault(); goToSlide(totalSlides - 1); }
});

// Initial animation
animateSlideContent();
</script>

</body>
</html>
