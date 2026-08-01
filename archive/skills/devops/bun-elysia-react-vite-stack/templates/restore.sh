#!/usr/bin/env bash
# CRM PostgreSQL restore script (host-side)
#
# Usage:
#   ./scripts/restore.sh                            # interactive: list backups, pick one
#   ./scripts/restore.sh <backup-file>              # restore specific file directly
#   ./scripts/restore.sh <backup-file> --no-confirm # skip confirmation (CI mode)
#
# IMPORTANT: this script will DROP the entire CRM database and rebuild from
# the SQL dump. It stops the API service so no live connections are open.

set -euo pipefail

COMPOSE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER_NAME="${POSTGRES_CONTAINER:-crm-postgres}"
DB_NAME="${POSTGRES_DB:-crm_system}"
DB_USER="${POSTGRES_USER:-crm}"
BACKUP_ROOT="${BACKUP_ROOT:-${COMPOSE_DIR}/backups}"
CONFIRM=true
SPECIFIC_FILE=""

# --- Args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-confirm) CONFIRM=false; shift;;
    -h|--help)
      sed -n '2,15p' "$0"
      exit 0;;
    --*) echo "Unknown flag: $1" >&2; exit 1;;
    *)
      if [[ -n "$SPECIFIC_FILE" ]]; then
        echo "Only one backup file argument allowed" >&2
        exit 1
      fi
      SPECIFIC_FILE="$1"
      shift;;
  esac
done

# --- Sanity checks ---
if ! command -v docker >/dev/null 2>&1; then
  echo "❌ docker not found in PATH" >&2
  exit 1
fi
if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
  echo "❌ postgres container '$CONTAINER_NAME' is not running" >&2
  exit 1
fi

# --- Pick backup file ---
if [[ -n "$SPECIFIC_FILE" ]]; then
  if [[ ! -f "$SPECIFIC_FILE" ]]; then
    echo "❌ file not found: $SPECIFIC_FILE" >&2
    exit 1
  fi
  BACKUP_FILE="$SPECIFIC_FILE"
else
  echo "📂 Available backups in ${BACKUP_ROOT}:"
  mapfile -t BACKUPS < <(find "$BACKUP_ROOT" -maxdepth 1 -type f -name 'crm_*.sql.gz' | sort)
  if [[ ${#BACKUPS[@]} -eq 0 ]]; then
    echo "   (none — run ./scripts/backup.sh first)" >&2
    exit 1
  fi
  for i in "${!BACKUPS[@]}"; do
    SIZE=$(du -h "${BACKUPS[$i]}" | cut -f1)
    MTIME=$(stat -f '%Sm' "${BACKUPS[$i]}" 2>/dev/null || stat -c '%y' "${BACKUPS[$i]}" 2>/dev/null)
    printf "   [%d] %s   %s   %s\n" "$((i+1))" "$MTIME" "$SIZE" "$(basename "${BACKUPS[$i]}")"
  done
  read -r -p "   Pick a backup [1-${#BACKUPS[@]}]: " PICK
  if ! [[ "$PICK" =~ ^[0-9]+$ ]] || (( PICK < 1 || PICK > ${#BACKUPS[@]} )); then
    echo "❌ invalid choice" >&2
    exit 1
  fi
  BACKUP_FILE="${BACKUPS[$((PICK-1))]}"
fi

SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo ""
echo "⚠️  About to:"
echo "    1. Stop API service (no live connections)"
echo "    2. DROP and recreate database '${DB_NAME}'"
echo "    3. Restore from: ${BACKUP_FILE} (${SIZE})"
echo "    4. Restart API service"
echo ""
if $CONFIRM; then
  read -r -p "   Type 'yes' to continue: " RESP
  if [[ "$RESP" != "yes" ]]; then
    echo "❌ cancelled"
    exit 1
  fi
fi

# --- Stop API ---
echo "⏹  Stopping API service..."
( cd "$COMPOSE_DIR" && docker compose stop api ) >/dev/null

# --- Drop & recreate DB ---
echo "🗑  Dropping and recreating ${DB_NAME}..."
docker exec "$CONTAINER_NAME" \
  psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS \"${DB_NAME}\";" >/dev/null
docker exec "$CONTAINER_NAME" \
  psql -U "$DB_USER" -d postgres -c "CREATE DATABASE \"${DB_NAME}\" OWNER \"${DB_USER}\";" >/dev/null

# --- Restore ---
echo "♻️  Restoring (this may take a minute)..."
if ! gunzip -c "$BACKUP_FILE" | docker exec -i "$CONTAINER_NAME" \
     psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1; then
  echo "❌ restore failed" >&2
  echo "   Database is empty. API will fail to start until you fix or restore another backup." >&2
  ( cd "$COMPOSE_DIR" && docker compose start api ) >/dev/null
  exit 1
fi

# --- Restart API ---
echo "▶️  Starting API service..."
( cd "$COMPOSE_DIR" && docker compose start api ) >/dev/null

echo ""
echo "✅ Restore complete!"
echo "   Database: ${DB_NAME}@${CONTAINER_NAME}"
echo "   Source:   ${BACKUP_FILE}"
echo ""
echo "   Wait ~10s for API to come up, then check:"
echo "   curl http://localhost/api/health"
