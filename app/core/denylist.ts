// Port of core/mogcore/denylist.py. Plain terms are literal except " ?" and "?", which stay
// optional, as Python's escape-then-restore leaves them. Python's \d and \b are Unicode-aware and
// JavaScript's are not, even under the u flag, so both are rewritten.

export interface Hit { pattern: string; reason: string; match: string }

interface Compiled { rx: RegExp; label: string; reason: string; allowInInfo: boolean }

const escapeLiteral = (s: string): string => s.replace(/[.*+^${}()|[\]\\]/g, '\\$&');
const W = '[\\p{L}\\p{N}_]'; // Python's \w on str
const BOUNDARY = `(?:(?<=${W})(?!${W})|(?<!${W})(?=${W}))`;
const unicodeAware = (pat: string): string => pat.replace(/\\d/g, '\\p{Nd}').replace(/\\b/g, BOUNDARY);

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
      return { rx: new RegExp(unicodeAware(pat), 'iu'), label: t.pattern, reason: t.reason, allowInInfo: Boolean(t.allow_in_info) };
    });
    this.allowedInProfessional = raw.allowed_in_tier_3_4_copy ?? [];
  }

  scan(text: string, infoCard = false): Hit[] {
    const hits: Hit[] = [];
    text = text.normalize('NFKC');
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
