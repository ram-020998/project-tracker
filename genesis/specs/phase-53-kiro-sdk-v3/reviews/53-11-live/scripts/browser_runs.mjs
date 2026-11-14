// 53-11 A1: run detail of each A1 run on the 53-11 serve, with its agent node selected (the inspector shows that
// node's conversation). Records the inspector text length and whether the agent's answer text is on the page.
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";

const require = createRequire("/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/playwright-appian/package.json");
const { chromium } = require("playwright");
const OUT = process.argv[2];
fs.mkdirSync(OUT, { recursive: true });
const BASE = "http://127.0.0.1:8770";
const RUNS = [["r-d19a1e33212d", "make_result", "Make result"], ["r-c4a4b6de1e02", "synthesize_capabilities", "Synthesize capabilities (B)"],
  ["r-78442ab0531c", "extract", "Extract memories"], ["r-9880c13825c9", "reflect", "Reflect (synthesize)"]];
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
const errors = [];
page.on("pageerror", (e) => errors.push(String(e)));
const res = [];
for (const [rid, node, label] of RUNS) {
  const evs = await (await fetch(`${BASE}/api/runs/${rid}/events?limit=20000`)).json();
  const list = Array.isArray(evs) ? evs : evs.events;
  const msg = list.filter((e) => e.kind === "agent.message" && e.node === node).map((e) => e.payload?.text || "").join("");
  const probe = msg.replace(/\s+/g, " ").trim().slice(0, 40);
  await page.goto(`${BASE}/runs/${rid}/node/${node}`);
  await page.waitForTimeout(1500);
  await page.getByRole("tab", { name: "Flow" }).click();
  await page.waitForTimeout(1000);
  await page.getByText("List", { exact: true }).first().click();
  await page.waitForTimeout(800);
  await page.getByText(label, { exact: true }).first().click();
  await page.waitForTimeout(2000);
  await page.getByRole("button", { name: "View details" }).click();
  await page.waitForTimeout(3000);
  const dlg = page.getByRole("dialog");
  const dtext = (await dlg.innerText().catch(() => "")).replace(/\s+/g, " ");
  res.push({ run: rid, node, dialog_has_conversation_section: /Conversation/.test(dtext),
    dialog_has_prompt: /prompt/i.test(dtext), dialog_has_answer: probe.length > 0 && dtext.includes(probe.slice(0, 25)),
    dialog_tool_ids: ["execute_bash", "fs_write", "str_replace", "list_directory", "Write File", "Run Command"].filter((x) => dtext.includes(x)),
    dialog_chars: dtext.length });
  const body = await page.locator("body").innerText();
  const flat = body.replace(/\s+/g, " ");
  res.push({ run: rid, node, answer_probe: probe, answer_on_page: probe.length > 0 && flat.includes(probe.slice(0, 25)),
    has_credits_text: /credit/i.test(body) || /\b0\.\d\d\b/.test(body), body_chars: body.length });
  await page.screenshot({ path: path.join(OUT, `run-${rid}-${node}.png`) });
}
fs.writeFileSync(path.join(OUT, "runs.json"), JSON.stringify({ res, errors }, null, 1));
console.log(JSON.stringify({ res, errors }, null, 1));
await browser.close();
