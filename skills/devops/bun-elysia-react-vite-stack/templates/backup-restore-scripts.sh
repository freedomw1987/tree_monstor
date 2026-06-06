#!/usr/bin/env bash
# CRM PostgreSQL backup script (host-side)
#
# Usage:
#   ./scripts/backup.sh              # backup to ./backups/crm_YYYY-MM-DD_HHMMSS.sql.gz (auto-retention 7 days)
#   ./scripts/backup.sh --keep 30    # keep 30 days of backups
#   ./scripts/backup.sh --no-trim    # skip old backup cleanup
#
# Runs pg_dump from inside the crm-postgres container (no need to install psql on host).
# Customize CONTAINER_NAME / DB_NAME / DB_USER if your docker-compose uses different names.

set -euo pipefail

# --- Defaults ---
KEEP_DAYS=7
TRIM=true
COMPOSE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER_NAME="${POSTGRES_CONTAINER:-crm-postgres}"
DB_NAME="${POSTGRES_DB:-crm_system}"
DB_USER="${POSTGRES_USER:-crm}"
BACKUP_ROOT="${BACKUP_ROOT:-${COMPOSE_DIR}/backups}"

# --- Args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep) KEEP_DAYS="$2"; shift 2;;
    --no-trim) TRIM=false; shift;;
    -h|--help)
      sed -n '2,15p' "$0"
      exit 0;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

mkdir -p "$BACKUP_ROOT"
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
BACKUP_FILE="${BACKUP_ROOT}/crm_${TIMESTAMP}.sql.gz"

# --- Sanity checks ---
if ! command -v docker >/dev/null 2>&1; then
  echo "❌ docker not found in PATH" >&2
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
  echo "❌ postgres container '$CONTAINER_NAME' is not running" >&2
  echo "   Start it: docker compose up -d postgres" >&2
  exit 1
fi

# --- Run pg_dump inside container, stream to gzip on host ---
echo "📦 Backing up ${DB_NAME}@${CONTAINER_NAME} → ${BACKUP_FILE}"
if ! docker exec -i "$CONTAINER_NAME" \
    pg_dump -U "$DB_USER" -d "$DB_NAME" --no-owner --clean --if-exists \
  | gzip -c > "$BACKUP_FILE"; then
  echo "❌ backup failed" >&2
  rm -f "$BACKUP_FILE"
  exit 1
fi

SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "✅ Backup complete: ${BACKUP_FILE} (${SIZE})"

# --- Retention ---
if $TRIM; then
  echo "🧹 Trimming backups older than ${KEEP_DAYS} days from ${BACKUP_ROOT}"
  DELETED=$(find "$BACKUP_ROOT" -maxdepth 1 -type f -name 'crm_*.sql.gz' -mtime +${KEEP_DAYS} -print -delete | wc -l | tr -d ' ')
  echo "   deleted ${DELETED} old backup(s)"
fi

# --- Summary ---
TOTAL=$(find "$BACKUP_ROOT" -maxdepth 1 -type f -name 'crm_*.sql.gz' | wc -l | tr -d ' ')
TOTAL_SIZE=$(du -sh "$BACKUP_ROOT" 2>/dev/null | cut -f1)
echo "📂 ${TOTAL} backup(s) in ${BACKUP_ROOT} (${TOTAL_SIZE} total)"
