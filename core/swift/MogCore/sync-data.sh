#!/usr/bin/env bash
# Copies the shared JSON tables and fixtures into the package so SwiftPM can bundle them.
# Run after any change to ../../data or ../../fixtures. The Python side is the source of truth.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
DST="$HERE/Sources/MogCore/Resources"
mkdir -p "$DST"
cp "$HERE/../../data/"{metrics,rules,references,denylist,composite_reference}.json "$DST/"
cp "$HERE/../../fixtures/scoring_cases.json" "$DST/"
echo "synced → $DST"; ls -1 "$DST"
