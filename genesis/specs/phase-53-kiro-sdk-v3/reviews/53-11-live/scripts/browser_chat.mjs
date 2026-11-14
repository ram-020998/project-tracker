// 53-11 A3b browser checks on the real 53-11 serve (:8770), real kiro-cli:
//  (1) the browser's Stop: /cancel first, the turn's stream kept open until its own end; "Stopped" live and after a
//      reload; the stopped turn's credits; a steer typed during the turn and left unread returns to the composer;
//  (2) the "/" palette lists each skill once; a pick sends "Use the <id> skill." (+ the text typed after the id).
// Usage: node browser_chat.mjs <session_id> <outdir>
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
  const u = r.url();
  if (/\/api\/chat\/sessions\/[^/]+\/(messages|cancel|steer)$/.test(u)) note("request", { url: u.replace(BASE, ""), body: r.postData() });
});
page.on("requestfinished", (r) => {
  const u = r.url();
  if (/\/api\/chat\/sessions\/[^/]+\/(messages|cancel|steer)$/.test(u)) note("finished", { url: u.replace(BASE, "") });
});
page.on("pageerror", (e) => note("pageerror", { msg: String(e) }));

await page.goto(`${BASE}/chat/${sid}`);
const box = page.getByRole("textbox", { name: "Message" });
await box.waitFor();

const stopBtn = page.getByRole("button", { name: "Stop", exact: true });
const sendBtn = page.getByRole("button", { name: "Send", exact: true });
async function turnEnd(timeout = 300000) {
  await stopBtn.waitFor({ state: "visible", timeout: 15000 }).catch(() => {});
  await stopBtn.waitFor({ state: "hidden", timeout });
}
async function sendAndWait(text) {
  await box.fill(text);
  await sendBtn.click();
  await turnEnd();
  await page.waitForTimeout(500);
}

// warm the session (no cold start in the Stop below)
await sendAndWait("Reply with the single word READY.");
note("warm_done", {});

// (1) Stop: a finished tool round first, so the aborted turn can carry a credit entry (53-02 W5)
await box.fill("First use the genesis-kb tools to list the applications. Then write a 600-word essay about what that "
  + "application might do.");
await sendBtn.click();
await stopBtn.waitFor({ state: "visible", timeout: 15000 });
// the tool round (~2.5 s) and some essay text first, then type a steer and stop at once (the steer is left unread)
await page.waitForTimeout(9000);
await box.fill("Make it about rivers only.");
await box.press("Enter");
note("steer_typed", {});
await page.waitForTimeout(150);
await stopBtn.click();
note("stop_clicked", {});
await stopBtn.waitFor({ state: "hidden", timeout: 30000 });
note("turn_ended_in_ui", {});
await page.waitForTimeout(800);
const composerAfterStop = await box.inputValue();
note("composer_after_stop", { value: composerAfterStop });
const stoppedLive = await page.getByText("Stopped", { exact: true }).count();
note("stopped_label_live", { count: stoppedLive });
await page.screenshot({ path: path.join(OUT, "stop-live-1440.png"), fullPage: false });
await page.reload();
await box.waitFor();
await page.waitForTimeout(1500);
const stoppedReload = await page.getByText("Stopped", { exact: true }).count();
note("stopped_label_after_reload", { count: stoppedReload });
await page.screenshot({ path: path.join(OUT, "stop-reload-1440.png"), fullPage: false });

// (2) the palette
await box.fill("/");
const lb = page.getByRole("listbox", { name: "Commands" });
await lb.waitFor({ timeout: 10000 });
const rows = await lb.getByRole("option").allInnerTexts();
note("palette_rows", { rows });
await page.screenshot({ path: path.join(OUT, "palette-1440.png"), fullPage: false });
// pick the gam skill row
await lb.getByRole("option").filter({ hasText: /\bgam\b/ }).first().click();
await turnEnd();
await page.waitForTimeout(1000);
// a typed "/gam <text>" keeps the row; picking it sends the text after the id
await box.fill("/gam in five words");
await lb.waitFor({ timeout: 10000 });
const rows2 = await lb.getByRole("option").allInnerTexts();
note("palette_rows_with_text", { rows: rows2 });
await lb.getByRole("option").first().click();
await turnEnd();
await page.waitForTimeout(1500);
await page.screenshot({ path: path.join(OUT, "after-picks-1440.png"), fullPage: false });

fs.writeFileSync(path.join(OUT, "browser-chat-log.json"), JSON.stringify(log, null, 1));
await browser.close();
