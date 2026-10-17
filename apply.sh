#!/usr/bin/env bash
# Applies migrations in version order with psql (Flyway alternative). Usage: ./apply.sh [--seed] [--security] [--test]
#   --seed      demo data (seeds/seed_data.sql)
#   --security  least-privilege role for the backend (security/rol_aplicacion.sql; needs a role-creating user)
#   --test      every tests/*_test.sql, schema_test.sql first (each one stops at its first failed assertion)
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
    --security) psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f security/rol_aplicacion.sql ;;
    --test)
      for test in tests/schema_test.sql $(ls tests/*_test.sql | grep -v schema_test.sql | sort); do
        echo "Testing $test"
        psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -o /dev/null -f "$test"
      done
      ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done
