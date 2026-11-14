// 53-11 A7 (L-090) on the real 53-11 serve, real data: at 1280/1440/1920, light and dark:
//  - the steered bubble + its "sent during the turn" label (session from a3b_steer.py);
//  - the MCP notice card (a new chat per combination; the instance's appian-dev is a fake install that exits 1);
//  - the Skills Update action (/catalog/skills, installed library skills).
// "answered by" needs a real model fallback, which did not occur; the 53-10 mock probe covers it.
// Per element: its box inside the viewport and its parent column, no own horizontal overflow; the page has no
// horizontal scroll. Usage: node browser_a7.mjs <steer_session> <outdir>
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";

const require = createRequire("/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/playwright-appian/package.json");
const { chromium } = require("playwright");
const [steerSid, OUT] = process.argv.slice(2);
fs.mkdirSync(OUT, { recursive: true });
const BASE = "http://127.0.0.1:8770";
const results = [];
const browser = await chromium.launch();

async function geom(page, loc, name) {
  const n = await loc.count();
  const items = [];
  for (let i = 0; i < n; i++) {
    const h = loc.nth(i);
    await h.scrollIntoViewIfNeeded().catch(() => {});
    const g = await h.evaluate((el) => {
      const r = el.getBoundingClientRect();
      const p = el.parentElement?.getBoundingClientRect();
      return { left: r.left, right: r.right, width: r.width, vw: window.innerWidth,
        ownOverflowX: el.scrollWidth - el.clientWidth,
        outsideParent: p ? (r.left < p.left - 1 || r.right > p.right + 1) : false,
        text: (el.innerText || el.getAttribute("aria-label") || "").slice(0, 60) };
    });
    g.ok = g.left >= 0 && g.right <= g.vw && g.ownOverflowX <= 1 && !g.outsideParent;
    items.push(g);
  }
  const pageX = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  return { element: name, count: n, pageHScroll: pageX, ok: n > 0 && pageX <= 0 && items.every((x) => x.ok), items };
}

for (const theme of ["light", "dark"]) {
  for (const w of [1280, 1440, 1920]) {
    const ctx = await browser.newContext({ viewport: { width: w, height: 900 } });
    await ctx.addInitScript((t) => window.localStorage.setItem("genesis.theme", t), theme);
    const page = await ctx.newPage();
    const tag = `${w}-${theme}`;
    // steered bubble
    await page.goto(`${BASE}/chat/${steerSid}`);
    await page.getByRole("textbox", { name: "Message" }).waitFor();
    await page.waitForTimeout(1500);
    const label = page.getByText("sent during the turn", { exact: true });
    const bubble = page.locator("div", { hasText: /^Also end your reply with the word KIWI\.$/ }).last();
    results.push({ tag, ...(await geom(page, label, "steer label")) });
    results.push({ tag, ...(await geom(page, bubble, "steered bubble")) });
    await label.first().scrollIntoViewIfNeeded();
    await page.screenshot({ path: path.join(OUT, `steer-${tag}.png`) });
    // MCP notice: a new chat, first turn
    const sid = (await (await fetch(`${BASE}/api/chat/sessions`, { method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ title: `53-11 A7 notice ${tag}` }) })).json()).id;
    await page.goto(`${BASE}/chat/${sid}`);
    const box = page.getByRole("textbox", { name: "Message" });
    await box.waitFor();
    await box.fill("Reply with the single word OK.");
    await page.getByRole("button", { name: "Send", exact: true }).click();
    const card = page.getByRole("status").filter({ hasText: "did not start" });
    await card.first().waitFor({ timeout: 120000 }).catch(() => {});
    await page.getByRole("button", { name: "Stop", exact: true }).waitFor({ state: "hidden", timeout: 120000 }).catch(() => {});
    await page.waitForTimeout(800);
    results.push({ tag, ...(await geom(page, card, "MCP notice card")) });
    await page.screenshot({ path: path.join(OUT, `notice-${tag}.png`) });
    // Skills Update
    await page.goto(`${BASE}/catalog/skills`);
    await page.waitForTimeout(2000);
    const upd = page.getByRole("button", { name: /^Update / });
    results.push({ tag, ...(await geom(page, upd, "Skills Update button")) });
    await page.screenshot({ path: path.join(OUT, `skills-${tag}.png`) });
    await ctx.close();
  }
}
fs.writeFileSync(path.join(OUT, "a7-result.json"), JSON.stringify(results, null, 1));
for (const r of results) console.log(r.tag.padEnd(11), r.element.padEnd(22), "count", r.count, "pageH", r.pageHScroll, r.ok ? "OK" : "FAIL");
await browser.close();
