"""Tier-X denylist. Runs at authoring time (tests scan every rule's copy) and at
render time (over LLM-generated text). A hit at render time discards the
generation and the client falls back to the rule's static copy."""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class Hit:
    pattern: str
    reason: str
    match: str


class Denylist:
    def __init__(self, raw: dict[str, Any]):
        self._compiled: list[tuple[re.Pattern[str], str, str, bool]] = []
        for t in raw["terms"]:
            pat = t["pattern"]
            if not t.get("regex", False):
                pat = re.escape(pat).replace(r"\ \?", r" ?").replace(r"\?", "?")
                # re.escape turns "bone ?smash" into "bone\ \?smash"; restore the optional space
                pat = pat.replace(r"\ ", " ")
                if t.get("word", False):
                    pat = rf"\b{pat}\b"
            self._compiled.append((re.compile(pat, re.IGNORECASE), t["pattern"], t["reason"], bool(t.get("allow_in_info", False))))
        self.allowed_in_professional = tuple(raw.get("allowed_in_tier_3_4_copy", []))

    def scan(self, text: str, *, info_card: bool = False) -> list[Hit]:
        hits: list[Hit] = []
        for rx, label, reason, allow_info in self._compiled:
            if info_card and allow_info:
                continue
            m = rx.search(text)
            if m:
                hits.append(Hit(pattern=label, reason=reason, match=m.group(0)))
        return hits

    def is_clean(self, text: str, *, info_card: bool = False) -> bool:
        return not self.scan(text, info_card=info_card)
