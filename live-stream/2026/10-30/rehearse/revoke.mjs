// Revoke and re-grant rehearsal, headless: alice signs in once through Cloudflare Access and Keycloak, then
// /ledger/ is polled while her fin attribute is dropped and restored with the ziti CLI. Prints how long each change
// took to show up.
//
//   cd rehearse && npm install
//   node revoke.mjs
//
// Needs Chrome, a logged-in `ziti edge login`, and ../.env (ALICE, ZAB_HOST). KC_USER and KC_PASSWORD override the
// Keycloak login, default alice and .env KC_ALICE.
import { chromium } from "playwright-core";
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const episode = join(dirname(fileURLToPath(import.meta.url)), "..");
const env = Object.fromEntries(
  readFileSync(join(episode, ".env"), "utf8")
    .split(/\r?\n/)
    .filter((l) => /^[A-Z_]+=/.test(l))
    .map((l) => [l.slice(0, l.indexOf("=")), l.slice(l.indexOf("=") + 1)]),
);
const ziti = join(episode, "bin", process.platform === "win32" ? "ziti.exe" : "ziti");
const chrome = process.env.CHROME ?? "C:/Program Files/Google/Chrome/Application/chrome.exe";
const ledger = `https://${env.ZAB_HOST}/ledger/`;
const setAttrs = (a) => execFileSync(ziti, ["edge", "update", "identity", env.ALICE, "--role-attributes", a]);

const browser = await chromium.launch({ executablePath: chrome });
const page = await browser.newPage();
await page.goto(ledger, { waitUntil: "networkidle" });
await page.waitForSelector("#username", { timeout: 20000 });
await page.fill("#username", process.env.KC_USER ?? "alice");
await page.fill("#password", process.env.KC_PASSWORD ?? env.KC_ALICE);
await Promise.all([page.waitForURL((u) => u.host === env.ZAB_HOST, { timeout: 30000 }), page.click("#kc-login")]);

// the ledger page has an h1 "Ledger". Anything else (a 502, then the wiki) means the ledger route is gone
const state = async () => {
  const r = await page.request.get(ledger);
  return `${r.status()} ${/<h1[^>]*>\s*Ledger/i.test(await r.text()) ? "LEDGER" : "not-ledger"}`;
};
const waitFor = async (want, limitS) => {
  const t0 = Date.now();
  for (;;) {
    const s = await state();
    const el = ((Date.now() - t0) / 1000).toFixed(1);
    if (s.endsWith(` ${want}`) || el > limitS) return { s, el };
    await new Promise((r) => setTimeout(r, 1000));
  }
};

console.log("baseline:", await state());
setAttrs("eng");
console.log("revoked (eng):", JSON.stringify(await waitFor("not-ledger", 60)));
setAttrs("eng,fin");
console.log("re-granted (eng,fin):", JSON.stringify(await waitFor("LEDGER", 420)));
await browser.close();
