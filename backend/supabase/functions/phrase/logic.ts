// Pure logic for the phrase function. No Deno, no network — testable with Node (tests/phrase.test.mjs).

import type { Denylist } from "../_shared/denylist.ts";

export interface PhraseCard {
  rule_id: string;
  headline: string;      // static, pre-approved
  body: string;          // static, pre-approved
  why_this: string;      // static, pre-approved
  evidence_grade: "strong" | "moderate" | "weak" | "community" | "contradicted";
  finding_categories: { metric_id: string; category: "low" | "typical" | "high" }[];
  is_info_card?: boolean;
}

export interface PhraseRequest {
  goals: string[];           // goal ids
  time_budget_min: 5 | 15 | 30;
  cards: PhraseCard[];       // ≤ 6
}

export interface PhraseResponse { cards: { rule_id: string; body: string; why_this: string }[] }

const GOAL_IDS = new Set(["sharper_jawline", "better_skin", "look_leaner", "hair", "eye_area", "better_photos", "general"]);
const ID_RX = /^[a-z0-9_]{1,64}$/;
const MAX_CARDS = 6;
const MAX_BODY_CHARS = 700;
const MAX_WHY_CHARS = 240;

/** Rejects anything that is not structured, categorical input. Returns null on any violation. */
export function validateRequest(r: unknown): PhraseRequest | null {
  if (!r || typeof r !== "object") return null;
  const q = r as any;
  if (!Array.isArray(q.goals) || q.goals.length === 0 || q.goals.length > 3 || !q.goals.every((g: unknown) => typeof g === "string" && GOAL_IDS.has(g))) return null;
  if (![5, 15, 30].includes(q.time_budget_min)) return null;
  if (!Array.isArray(q.cards) || q.cards.length === 0 || q.cards.length > MAX_CARDS) return null;
  for (const c of q.cards) {
    if (!c || typeof c !== "object") return null;
    if (typeof c.rule_id !== "string" || !ID_RX.test(c.rule_id)) return null;
    for (const k of ["headline", "body", "why_this"]) if (typeof c[k] !== "string" || c[k].length > 1200) return null;
    if (!["strong", "moderate", "weak", "community", "contradicted"].includes(c.evidence_grade)) return null;
    if (!Array.isArray(c.finding_categories) || c.finding_categories.length > 6) return null;
    for (const f of c.finding_categories) {
      if (typeof f?.metric_id !== "string" || !ID_RX.test(f.metric_id)) return null;
      if (!["low", "typical", "high"].includes(f.category)) return null;
    }
    // the one thing we must never receive: numbers that look like measurements or scores
    const blob = JSON.stringify(c);
    if (/"(value|score|percentile|z|landmarks?|coords?|image|pixels?)"\s*:/i.test(blob)) return null;
  }
  return q as PhraseRequest;
}

export function buildPrompt(req: unknown): { system: string; user: string } | null {
  const r = validateRequest(req);
  if (!r) return null;
  const system = [
    "You rewrite short self-care guidance so that it reads naturally and specifically for one person. You are an editor, not an adviser.",
    "Rules, all absolute:",
    "- Keep every factual claim exactly as given. Do not add a recommendation, a product, a brand, a drug, a dose, a number, a timeline, a calorie or weight figure, or a comparison to other people.",
    "- Do not mention the person's score, rank, tier, percentile or attractiveness. Do not use the words 'mog', 'mogged', 'subhuman', 'incel', or any comparative slang.",
    "- Do not reference bone or facial structure as changeable. Do not mention surgery, fillers, injections, or any procedure.",
    "- Tone: a precise technician. No exclamation marks. No encouragement, no pity, no 'unfortunately'. Second person.",
    "- Length: body ≤ 90 words, why_this ≤ 35 words. Keep headlines unchanged.",
    "Output ONLY a JSON object: {\"cards\":[{\"rule_id\":\"...\",\"body\":\"...\",\"why_this\":\"...\"}]} with the same rule_ids in the same order. No prose before or after.",
  ].join("\n");
  const user = JSON.stringify({
    goals: r.goals, time_budget_min: r.time_budget_min,
    cards: r.cards.map((c) => ({ rule_id: c.rule_id, headline: c.headline, body: c.body, why_this: c.why_this, evidence_grade: c.evidence_grade, findings: c.finding_categories })),
  });
  return { system, user };
}

/** Parses the model output, enforces the schema (same ids, same order, bounded lengths),
 *  then scans every string against the denylist. Returns null on ANY problem. */
export function validateAndScan(text: string, req: PhraseRequest, denylist: Denylist): PhraseResponse | null {
  let parsed: any;
  try {
    const start = text.indexOf("{"), end = text.lastIndexOf("}");
    if (start < 0 || end <= start) return null;
    parsed = JSON.parse(text.slice(start, end + 1));
  } catch { return null; }
  if (!parsed || !Array.isArray(parsed.cards) || parsed.cards.length !== req.cards.length) return null;
  const out: PhraseResponse = { cards: [] };
  for (let i = 0; i < req.cards.length; i++) {
    const want = req.cards[i], got = parsed.cards[i];
    if (!got || got.rule_id !== want.rule_id) return null;
    if (typeof got.body !== "string" || typeof got.why_this !== "string") return null;
    if (got.body.length === 0 || got.body.length > MAX_BODY_CHARS || got.why_this.length > MAX_WHY_CHARS) return null;
    if (/[!]/.test(got.body + got.why_this)) return null;
    if (/\d+(\.\d+)?\s?(mg|mcg|ml|iu|kcal|cal|lb|lbs|kg|%)/i.test(got.body + got.why_this)) return null;   // belt and braces; denylist also catches these
    const info = !!want.is_info_card;
    if (!denylist.isClean(got.body, info) || !denylist.isClean(got.why_this, info)) return null;
    out.cards.push({ rule_id: want.rule_id, body: got.body, why_this: got.why_this });
  }
  return out;
}
