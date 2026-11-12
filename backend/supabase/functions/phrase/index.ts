// phrase — rewords pre-approved plan copy in natural language. Used ONLY when on-device
// Foundation Models are unavailable; the app falls back to static copy if this returns 204.
//
// Contract (eng doc, "LLM phrasing — text only, schema-constrained"):
//   * input is structured findings and goals: metric ids + categories, rule ids, the static copy.
//     NEVER a score, a value, an image, a landmark, a coordinate, or free text from the user.
//   * the model may reword; it may not add a recommendation, a number, a drug, a dose, a product,
//     or a comparison. The schema and the denylist enforce that, in that order.
//   * temperature 0, fixed model string, output validated against a strict schema, then scanned.
//     Any failure → 204 No Content. The client never sees an error, only its own static copy.
//
// Deno runtime (Supabase Edge). Pure logic lives in ./logic.ts so it can be tested with Node.

import { buildPrompt, validateAndScan, PhraseRequest } from "./logic.ts";
import denylistJson from "../_shared/denylist.json" with { type: "json" };
import { Denylist } from "../_shared/denylist.ts";

const MODEL = Deno.env.get("PHRASE_MODEL") ?? "claude-haiku-5-5";
const API_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
const denylist = new Denylist(denylistJson as any);

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response(null, { status: 405 });
  if (!API_KEY) return new Response(null, { status: 204 });
  let body: PhraseRequest;
  try { body = await req.json(); } catch { return new Response(null, { status: 400 }); }

  const prompt = buildPrompt(body);
  if (!prompt) return new Response(null, { status: 400 });

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "content-type": "application/json", "x-api-key": API_KEY, "anthropic-version": "2023-06-01" },
    body: JSON.stringify({ model: MODEL, max_tokens: 600, temperature: 0, system: prompt.system, messages: [{ role: "user", content: prompt.user }] }),
  });
  if (!res.ok) return new Response(null, { status: 204 });
  const data = await res.json();
  const text: string = data?.content?.[0]?.text ?? "";
  const out = validateAndScan(text, body, denylist);
  if (!out) return new Response(null, { status: 204 });
  return new Response(JSON.stringify(out), { headers: { "content-type": "application/json", "cache-control": "no-store" } });
});
