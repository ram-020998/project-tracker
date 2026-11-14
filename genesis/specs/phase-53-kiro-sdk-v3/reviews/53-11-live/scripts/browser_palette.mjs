// 53-11 A3b: the "/" palette on the real 53-11 serve lists each skill once; a pick sends "Use the <id> skill." (plus
// the text typed after the id). Usage: node browser_palette.mjs <session_id> <outdir>
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";

const require = createRequire("/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/playwright-appian/package.json");
const { chromium } = require("playwright");
const [sid, OUT] = process.argv.slice(2);
fs.mkdirSync(OUT, { recursive: true });
const BASE = "http://127.0.0.1:8770";
const log = [];
const t0 = Date.now();
const note = (k, v) => { const e = { t: (Date.now() - t0) / 1000, k, ...v }; log.push(e); console.log(JSON.stringify(e)); };

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
page.on("request", (r) => {
  if (/\/api\/chat\/sessions\/[^/]+\/(messages|cancel|steer)$/.test(r.url())) note("request", { url: r.url().replace(BASE, ""), body: r.postData() });
});
page.on("pageerror", (e) => note("pageerror", { msg: String(e) }));
await page.goto(`${BASE}/chat/${sid}`);
const box = page.getByRole("textbox", { name: "Message" });
await box.waitFor();
const stopBtn = page.getByRole("button", { name: "Stop", exact: true });
async function turnEnd() {
  await stopBtn.waitFor({ state: "visible", timeout: 15000 }).catch(() => {});
  await stopBtn.waitFor({ state: "hidden", timeout: 300000 });
}
const lb = page.getByRole("listbox", { name: "Commands" });

async function pickRow(typed, id) {
  await box.fill(typed);
  await lb.waitFor({ timeout: 10000 });
  const rows = await lb.getByRole("option").allInnerTexts();
  note("palette_rows", { typed, rows });
  const i = rows.findIndex((r) => r === `${id}${id}` || r.startsWith(`${id}\n`) || r === id);
  note("pick", { id, index: i });
  await lb.getByRole("option").nth(i).click();
  await turnEnd();
  await page.waitForTimeout(1000);
}

await box.fill("/");
await lb.waitFor({ timeout: 10000 });
await page.screenshot({ path: path.join(OUT, "palette-1440.png") });
await pickRow("/", "gam");
await pickRow("/gam in five words", "gam");
await page.screenshot({ path: path.join(OUT, "after-picks-1440.png") });
fs.writeFileSync(path.join(OUT, "browser-palette-log.json"), JSON.stringify(log, null, 1));
await browser.close();
