#!/bin/sh
# In-container backup script — used by the `backup` service in docker-compose.yml.
# Runs INSIDE a postgres:16-alpine container, so pg_dump is local and
# connects to the sibling `postgres` service over the compose network.
#
# Host version of this script is backup.sh — it does the same job but
# shells out to `docker exec` from the host. Don't confuse the two.
set -eu

TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
OUT="/var/backups/crm_${TIMESTAMP}.sql.gz"

KEEP_DAYS="${BACKUP_KEEP_DAYS:-7}"

# Ensure target dir exists (volume mount is /var/backups)
mkdir -p /var/backups

# Run pg_dump. -h is the compose service name; user/db from env.
pg_dump -h "${POSTGRES_HOST:-postgres}" \
        -U "${POSTGRES_USER:-crm}" \
        -d "${POSTGRES_DB:-crm_system}" \
        --no-owner --clean --if-exists \
  | gzip -c > "${OUT}"

SIZE=$(du -h "${OUT}" | cut -f1)
echo "[$(date -Iseconds)] backup ok: ${OUT} (${SIZE})"

# Retention
DELETED=$(find /var/backups -maxdepth 1 -type f -name 'crm_*.sql.gz' -mtime "+${KEEP_DAYS}" -print -delete | wc -l)
if [ "${DELETED}" -gt 0 ]; then
  echo "[$(date -Iseconds)] trimmed ${DELETED} old backup(s)"
fi
