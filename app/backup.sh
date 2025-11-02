#!/bin/sh
set -eu

# Simple logger with ISO timestamp
log() { printf "%s %s\n" "$(date -Is)" "$*" ; }

# Required

# Optional
OUT_DIR="${BACKUP_DEST:-/backups}"
FORMAT="${BACKUP_FORMAT:-tar.gz}"
HN="$(hostname 2>/dev/null || echo container)"
HN="${HN%%.*}"
PREFIX="${BACKUP_NAME_PREFIX:-$HN}"
ONEFS="${BACKUP_ONEFS:-false}"
CHOWN_TARGET="${BACKUP_CHOWN:-}"
CHMOD_TARGET="${BACKUP_CHMOD:-}"

# Deduct and sanitise values
case "$CHOWN_TARGET" in
  *[!A-Za-z0-9:._-]* ) log "WARN: ignoring unsafe BACKUP_CHOWN='$CHOWN_TARGET'"; CHOWN_TARGET="";;
esac
case "$CHMOD_TARGET" in
  ""|[0-7][0-7][0-7]|[0-7][0-7][0-7][0-7]) : ;;
  * ) log "WARN: ignoring unsafe BACKUP_CHMOD='$CHMOD_TARGET'"; CHMOD_TARGET="";;
esac
DATE="$(date +%Y%m%d)"
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

OUT_PATH="${OUT_DIR}/${PREFIX}-${DATE}.${EXT}"

log "Starting backup → ${OUT_PATH}"
tar "$@" --file "$OUT_PATH"

# Create checksum
sha256sum "$OUT_PATH" > "${OUT_PATH}.sha256"
log "Checksum written: ${OUT_PATH}.sha256"

# Apply ownership / permissions
if [ -n "${CHOWN_TARGET}" ]; then
  log "Setting ownership to ${CHOWN_TARGET}"
  chown -h "${CHOWN_TARGET}" "${OUT_PATH}" "${OUT_PATH}.sha256" 2>/dev/null || true
fi

if [ -n "${CHMOD_TARGET}" ]; then
  log "Setting permissions to ${CHMOD_TARGET}"
  chmod "${CHMOD_TARGET}" "${OUT_PATH}" "${OUT_PATH}.sha256" 2>/dev/null || true
fi

SIZE="$(du -h "$OUT_PATH" | awk '{print $1}')"
log "Backup complete (${SIZE})"
