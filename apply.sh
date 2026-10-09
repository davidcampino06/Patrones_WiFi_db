#!/usr/bin/env bash
# Applies migrations in version order with psql (Flyway alternative). Usage: ./apply.sh [--seed] [--test]
set -euo pipefail

: "${DATABASE_URL:?Set DATABASE_URL, e.g. postgresql://wifisense:secret@localhost:5432/wifisense}"
cd "$(dirname "$0")"

for file in $(ls migrations/V*__*.sql | sort -V); do
  echo "Applying $file"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f "$file"
done

for arg in "$@"; do
  case "$arg" in
    --seed) psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -o /dev/null -f seeds/seed_data.sql ;;
    --test) psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -o /dev/null -f tests/schema_test.sql ;;
  esac
done
