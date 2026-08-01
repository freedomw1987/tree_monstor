#!/bin/bash
# migration-lint.sh — fail build if a new Prisma migration uses
# PascalCase identifiers where the init migration uses snake_case
# with explicit double-quotes.
#
# Context: crm-system RG-007 (2026-06-08) — Day 17's
# `20260609000002_day17_ai_tool_confirmation` migration used
# `ALTER TABLE "ConversationMessage"` (PascalCase) but the table is
# actually named `"conversation_messages"` (snake_case, init
# migration). PG throws `42P01 relation does not exist` at
# deploy time on case-sensitive collations.
#
# US-OPS-1 backlog: hook this into `bun run lint` pre-commit.
#
# Usage:
#   bash skills/prisma-migrate-private-rds/scripts/migration-lint.sh [migrations-dir]
#
# Default migrations dir: packages/db/prisma/migrations

set -euo pipefail

MIGRATIONS_DIR="${1:-packages/db/prisma/migrations}"
INIT_MIGRATION_NAME="20260605014842_init"  # crm-system-specific; adjust per project

if [ ! -d "$MIGRATIONS_DIR" ]; then
  echo "❌ migrations dir not found: $MIGRATIONS_DIR"
  exit 1
fi

# Get the convention from the init migration (crm-system uses
# snake_case with explicit double-quotes; if your project uses
# PascalCase as the on-disk convention, the grep below will not
# match anything and the lint is a no-op — that's correct, the
# check only fires on PascalCase).
INIT="$MIGRATIONS_DIR/$INIT_MIGRATION_NAME/migration.sql"
if [ ! -f "$INIT" ]; then
  echo "⚠️  init migration not found at $INIT — skipping lint (crm-system-only check)"
  exit 0
fi

failed=0
for f in "$MIGRATIONS_DIR"/*/migration.sql; do
  [ "$f" = "$INIT" ] && continue
  # Detect: ALTER TABLE "CamelCase"  or  CREATE TABLE "CamelCase"
  if grep -E '(ALTER|CREATE)\s+TABLE\s+"[A-Z]' "$f" >/dev/null 2>&1; then
    echo "❌ $f uses PascalCase identifier"
    grep -nE '(ALTER|CREATE)\s+TABLE\s+"[A-Z]' "$f" | sed 's/^/    /'
    failed=1
  fi
done

if [ "$failed" -ne 0 ]; then
  echo ""
  echo "Fix: replace PascalCase identifiers with the on-disk name (snake_case, quoted)."
  echo "Verify the on-disk name with: docker exec -i <postgres> psql -U <user> -d <db> -c '\\d <table>'"
  exit 1
fi

echo "✅ migration-lint: no PascalCase drift in $MIGRATIONS_DIR"
