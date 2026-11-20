// Generates the Exact app's copies of core's source of truth. Exact bundles nothing outside app/.
//   app/strings/en.json  flat keys (Exact's strings table) from core/copy/strings.json; "" = not rendered, no key
//   app/data/*.json      the data tables and golden fixtures the TS port reads, byte for byte
//   node scripts/sync-app.mjs            → writes them
//   node scripts/sync-app.mjs --check    → exits 1 if any is stale
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const read = (p) => readFileSync(join(root, p), "utf8");

const strings = {};
const walk = (node, prefix) => {
  for (const [k, v] of Object.entries(node)) {
    if (k.startsWith("$")) continue;
    if (typeof v === "object") walk(v, `${prefix}${k}.`);
    else if (v !== "") strings[`${prefix}${k}`] = v;
  }
};
walk(JSON.parse(read("core/copy/strings.json")), "");

const outputs = { "app/strings/en.json": JSON.stringify(strings, null, 2) + "\n" };
for (const t of ["metrics", "rules", "references", "denylist", "composite_reference"]) outputs[`app/data/${t}.json`] = read(`core/data/${t}.json`);
outputs["app/data/scoring_cases.json"] = read("core/fixtures/scoring_cases.json");

const check = process.argv.includes("--check");
const stale = [];
for (const [dest, text] of Object.entries(outputs)) {
  const path = join(root, dest);
  if (check) {
    if (!existsSync(path) || readFileSync(path, "utf8") !== text) stale.push(dest);
    continue;
  }
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, text);
}
if (check && stale.length) { console.error(`stale: ${stale.join(", ")}. Run node scripts/sync-app.mjs`); process.exit(1); }
console.log(check ? "app copies up to date" : `wrote ${Object.keys(outputs).length} files (${Object.keys(strings).length} strings)`);
