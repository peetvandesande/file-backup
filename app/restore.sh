#!/bin/sh
set -eu

# Simple logger with ISO timestamp
log() { printf "%s %s\n" "$(date -Is)" "$*"; }

# Required

# Optional
DEST="${2:-/}"
BACKUP_DIR="${BACKUPS_DIR:-/backups}"
VERIFY="${VERIFY_SHA256:-1}"   # 1 = verify if .sha256 exists; 0 = skip

# Resolve backup file:
# - Arg 1 if given
if [ -n "${1:-}" ]; then
  BACKUP_FILE="$1"
else
  TODAY="$(date +%Y%m%d)"
  BACKUP_FILE="$(ls -1 ${BACKUP_DIR}/${POSTGRES_DB}-*.sql.gz 2>/dev/null \
    | sed -n 's#.*-\([0-9]\{8\}\)\.sql\.gz$#\1 \0#p' \
    | sort \
    | awk -v t="$TODAY" '$1 != t {print $2}' \
    | tail -n1 || true)"
fi

if [ -z "${BACKUP_FILE:-}" ] || [ ! -f "${BACKUP_FILE}" ]; then
  log "ERROR: Backup file not found. Provide a file path or ensure historical backups exist." >&2
  exit 1
fi

log "Restoring ${BACKUP_FILE} to ${DEST}"

# Verify checksum if file exists and VERIFY is true
if [ "${VERIFY}" != "0" ] && [ -f "${BACKUP_FILE}.sha256" ]; then
  log "Verifying checksum: ${BACKUP_FILE}.sha256"
  if ! sha256sum -c "${BACKUP_FILE}.sha256"; then
    log "ERROR: SHA-256 verification failed for ${BACKUP_FILE}" >&2
    exit 1
  fi
fi

case "$BACKUP_FILE" in
  *.tar.gz)  tar -xzp -f "$BACKUP_FILE" -C "$DEST" ;;
  *.tar.bz2) tar -xjp -f "$BACKUP_FILE" -C "$DEST" ;;
  *.tar.zst) tar --use-compress-program=zstd -xp -f "$BACKUP_FILE" -C "$DEST" ;;
  *.tar)     tar -xp -f "$BACKUP_FILE" -C "$DEST" ;;
  *) log "Restore FAILED due to unsupported archive type: $BACKUP_FILE" >&2; exit 1 ;;
esac
log "Restore completed successfully."
