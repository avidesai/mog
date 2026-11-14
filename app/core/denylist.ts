// Port of core/mogcore/denylist.py. Plain terms are literal except " ?" and "?", which stay
// optional, as Python's escape-then-restore leaves them.

export interface Hit { pattern: string; reason: string; match: string }

interface Compiled { rx: RegExp; label: string; reason: string; allowInInfo: boolean }

const escapeLiteral = (s: string): string => s.replace(/[.*+^${}()|[\]\\]/g, '\\$&');

export class Denylist {
  private readonly compiled: Compiled[];
  readonly allowedInProfessional: string[];

  constructor(raw: any) {
    this.compiled = raw.terms.map((t: any) => {
      let pat: string = t.pattern;
      if (!t.regex) {
        pat = escapeLiteral(pat);
        if (t.word) pat = `\\b${pat}\\b`;
      }
      return { rx: new RegExp(pat, 'i'), label: t.pattern, reason: t.reason, allowInInfo: Boolean(t.allow_in_info) };
    });
    this.allowedInProfessional = raw.allowed_in_tier_3_4_copy ?? [];
  }

  scan(text: string, infoCard = false): Hit[] {
    const hits: Hit[] = [];
    for (const { rx, label, reason, allowInInfo } of this.compiled) {
      if (infoCard && allowInInfo) continue;
      const m = rx.exec(text);
      if (m) hits.push({ pattern: label, reason, match: m[0] });
    }
    return hits;
  }

  isClean(text: string, infoCard = false): boolean {
    return this.scan(text, infoCard).length === 0;
  }
}
