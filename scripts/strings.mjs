// Generates app/strings/en.json (flat keys, Exact's strings table) from core/copy/strings.json.
// core/copy/strings.json stays the source of truth: it is what the denylist and clean-copy tests read.
//   node scripts/strings.mjs            → writes app/strings/en.json
//   node scripts/strings.mjs --check    → exits 1 if the generated file is stale
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const src = JSON.parse(readFileSync(join(root, "core/copy/strings.json"), "utf8"));
const out = {};
const walk = (node, prefix) => {
  for (const [k, v] of Object.entries(node)) {
    if (k.startsWith("$")) continue;
    if (typeof v === "object") walk(v, `${prefix}${k}.`);
    else if (v !== "") out[`${prefix}${k}`] = v;          // "" = element not rendered; no key
  }
};
walk(src, "");
const text = JSON.stringify(out, null, 2) + "\n";
const dest = join(root, "app/strings/en.json");
if (process.argv.includes("--check")) {
  const current = existsSync(dest) ? readFileSync(dest, "utf8") : "";
  if (current !== text) { console.error("app/strings/en.json is stale: run node scripts/strings.mjs"); process.exit(1); }
  console.log("strings up to date"); process.exit(0);
}
mkdirSync(dirname(dest), { recursive: true });
writeFileSync(dest, text);
console.log(`wrote ${dest} (${Object.keys(out).length} strings)`);
