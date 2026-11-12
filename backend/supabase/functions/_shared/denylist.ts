// Port of core/mogcore/denylist.py. Same JSON (core/data/denylist.json, copied in by sync-data.sh),
// same semantics: case-insensitive; `word` → \b boundaries; `regex` → raw pattern; `allow_in_info`
// terms are skipped only for info cards. Tested in tests/denylist.test.mjs with the same assertions
// as the Python suite.

export interface DenyTerm { pattern: string; word?: boolean; allow_in_info?: boolean; regex?: boolean; reason: string }
export interface DenyHit { pattern: string; reason: string; match: string }

function escapeRegex(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

export class Denylist {
  private compiled: { rx: RegExp; label: string; reason: string; allowInfo: boolean }[];
  readonly allowedInProfessional: string[];

  constructor(raw: { terms: DenyTerm[]; allowed_in_tier_3_4_copy?: string[] }) {
    this.compiled = raw.terms.map((t) => {
      let pat = t.pattern;
      if (!t.regex) {
        // mirror Python: escape, then restore the optional-space "?" the source patterns use
        pat = escapeRegex(pat).replace(/\\\?/g, "?");
        if (t.word) pat = `\\b${pat}\\b`;
      }
      return { rx: new RegExp(pat, "i"), label: t.pattern, reason: t.reason, allowInfo: !!t.allow_in_info };
    });
    this.allowedInProfessional = raw.allowed_in_tier_3_4_copy ?? [];
  }

  scan(text: string, infoCard = false): DenyHit[] {
    const hits: DenyHit[] = [];
    for (const c of this.compiled) {
      if (infoCard && c.allowInfo) continue;
      const m = c.rx.exec(text);
      if (m) hits.push({ pattern: c.label, reason: c.reason, match: m[0] });
    }
    return hits;
  }

  isClean(text: string, infoCard = false): boolean {
    return this.scan(text, infoCard).length === 0;
  }
}
