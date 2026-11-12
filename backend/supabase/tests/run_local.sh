#!/usr/bin/env bash
# Runs migrations + tests against a local Postgres. Usage: tests/run_local.sh "host=/tmp port=5499 user=postgres"
set -euo pipefail
CONN="${1:-host=localhost user=postgres}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
psql "$CONN" -v ON_ERROR_STOP=1 -q -c "drop database if exists mog_test;" -c "create database mog_test;"
psql "$CONN dbname=mog_test" -v ON_ERROR_STOP=1 -q -f "$HERE/tests/shim_auth.sql"
for m in "$HERE"/migrations/*.sql; do psql "$CONN dbname=mog_test" -v ON_ERROR_STOP=1 -q -f "$m"; done
psql "$CONN dbname=mog_test" -v ON_ERROR_STOP=1 -q -f "$HERE/tests/deletion_test.sql"
