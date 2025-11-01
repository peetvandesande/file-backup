#!/bin/sh
set -eu

timestamp() { date +"%Y%m%d"; }
log() { echo "[$(date -Iseconds)] $*"; }

DEST="${BACKUP_DEST:-/backups}"
FORMAT="${BACKUP_FORMAT:-tar.gz}"
HN="$(hostname 2>/dev/null || echo container)"
HN="${HN%%.*}"
PREFIX="${BACKUP_NAME_PREFIX:-$HN}"
ONEFS="${BACKUP_ONEFS:-false}"

mkdir -p "$DEST"

TMPDIR="$(mktemp -d)"
SRC_FILE="$TMPDIR/sources.txt"
EXC_FILE="$TMPDIR/excludes.txt"
trap 'rm -rf "$TMPDIR"' EXIT

# Sources
if [ -f /config/sources.txt ]; then
  cp /config/sources.txt "$SRC_FILE"
elif [ -n "${BACKUP_SOURCES:-}" ]; then
  printf "%s" "$BACKUP_SOURCES" | tr ',' '\n' > "$SRC_FILE"
else
  log "ERROR: No sources defined. Provide /config/sources.txt or BACKUP_SOURCES."
  exit 1
fi

# Excludes
if [ -f /config/excludes.txt ]; then
  cp /config/excludes.txt "$EXC_FILE"
elif [ -n "${BACKUP_EXCLUDES:-}" ]; then
  printf "%s" "$BACKUP_EXCLUDES" | tr ',' '\n' > "$EXC_FILE"
else
  : > "$EXC_FILE"
fi

# Clean up comments / blanks / CRLFs
sed -i -e 's/\r$//' -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$SRC_FILE" || true
sed -i -e 's/\r$//' -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$EXC_FILE" || true

# Build tar arguments
set -- \
  --create \
  --absolute-names \
  --xattrs --xattrs-include='*' \
  --acls \
  --numeric-owner \
  --warning=no-file-changed

if [ "$ONEFS" = "true" ]; then
  set -- "$@" --one-file-system
fi

# Exclude must come before file list
set -- "$@" --exclude-from="$EXC_FILE" --files-from="$SRC_FILE"

EXT="tar"
case "$FORMAT" in
  tar.gz)  EXT="tar.gz";  set -- "$@" --gzip ;;
  tar.zst) EXT="tar.zst"; set -- "$@" --use-compress-program=zstd ;;
  tar.bz2) EXT="tar.bz2"; set -- "$@" --bzip2 ;;
  tar)     EXT="tar" ;;
  *) log "ERROR: Unsupported BACKUP_FORMAT: $FORMAT"; exit 1 ;;
esac

STAMP="$(timestamp)"
OUT_BASENAME="${PREFIX}-${STAMP}.${EXT}"
OUT_PATH="${DEST}/${OUT_BASENAME}"

log "Starting backup → ${OUT_PATH}"
tar "$@" --file "$OUT_PATH"

# Create checksum
if command -v sha256sum >/dev/null 2>&1; then
  (cd "$DEST" && sha256sum "$OUT_BASENAME" > "${OUT_BASENAME}.sha256") || true
fi

# Apply ownership / permissions
if [ -n "${BACKUP_CHOWN:-}" ]; then
  log "Setting ownership to ${BACKUP_CHOWN}"
  chown "${BACKUP_CHOWN}" "$OUT_PATH" 2>/dev/null || true
  [ -f "${OUT_PATH}.sha256" ] && chown "${BACKUP_CHOWN}" "${OUT_PATH}.sha256" 2>/dev/null || true
fi

if [ -n "${BACKUP_CHMOD:-}" ]; then
  log "Setting permissions to ${BACKUP_CHMOD}"
  chmod "${BACKUP_CHMOD}" "$OUT_PATH" 2>/dev/null || true
  [ -f "${OUT_PATH}.sha256" ] && chmod "${BACKUP_CHMOD}" "${OUT_PATH}.sha256" 2>/dev/null || true
fi

SIZE="$(du -h "$OUT_PATH" | awk '{print $1}')"
log "Backup complete (${SIZE})"
