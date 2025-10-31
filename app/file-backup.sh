#!/usr/bin/env bash
set -euo pipefail

timestamp() { date +"%Y%m%d"; }
log() { echo "[$(date -Iseconds)] $*"; }

DEST="${BACKUP_DEST:-/backups}"
FORMAT="${BACKUP_FORMAT:-tar.gz}"
PREFIX="${BACKUP_NAME_PREFIX:-$(hostname -s)}"
ONEFS="${BACKUP_ONEFS:-false}"

mkdir -p "$DEST"

TMPDIR="$(mktemp -d)"
SRC_FILE="$TMPDIR/sources.txt"
EXC_FILE="$TMPDIR/excludes.txt"
trap 'rm -rf "$TMPDIR"' EXIT

# Resolve sources
if [ -f /config/sources.txt ]; then
  cp /config/sources.txt "$SRC_FILE"
elif [ -n "${BACKUP_SOURCES:-}" ]; then
  # allow comma or newline separated
  printf "%s\n" "${BACKUP_SOURCES//,/\\n}" > "$SRC_FILE"
else
  log "ERROR: No sources defined. Provide /config/sources.txt or BACKUP_SOURCES."
  exit 1
fi

# Resolve excludes
if [ -f /config/excludes.txt ]; then
  cp /config/excludes.txt "$EXC_FILE"
elif [ -n "${BACKUP_EXCLUDES:-}" ]; then
  printf "%s\n" "${BACKUP_EXCLUDES//,/\\n}" > "$EXC_FILE"
else
  : > "$EXC_FILE"
fi

# Clean up comments/blank lines and CRLFs
sed -i -e 's/\r$//' -e '/^\s*#/d' -e '/^\s*$/d' "$SRC_FILE" || true
sed -i -e 's/\r$//' -e '/^\s*#/d' -e '/^\s*$/d' "$EXC_FILE" || true

# Build tar options
EXT="tar"
TAR_OPTS=(--create --absolute-names --xattrs --xattrs-include='*' --acls --numeric-owner --warning=no-file-changed)
[ "$ONEFS" = "true" ] && TAR_OPTS+=(--one-file-system)
TAR_OPTS+=(--exclude-from="$EXC_FILE" --files-from="$SRC_FILE")


case "$FORMAT" in
  tar.gz)  EXT="tar.gz";  TAR_OPTS+=(--gzip) ;;
  tar.zst) EXT="tar.zst"; TAR_OPTS+=(--use-compress-program=zstd) ;;
  tar.bz2) EXT="tar.bz2"; TAR_OPTS+=(--bzip2) ;;
  tar)     EXT="tar" ;;
  *) log "ERROR: Unsupported BACKUP_FORMAT: $FORMAT"; exit 1 ;;
esac

STAMP="$(timestamp)"
OUT_BASENAME="${PREFIX}-${STAMP}.${EXT}"
OUT_PATH="${DEST}/${OUT_BASENAME}"

log "Starting backup → ${OUT_PATH}"
tar "${TAR_OPTS[@]}" --file "$OUT_PATH"

# Checksum (best-effort)
if command -v sha256sum >/dev/null 2>&1; then
  (cd "$DEST" && sha256sum "$OUT_BASENAME" > "${OUT_BASENAME}.sha256") || true
fi

# Optional ownership
if [ -n "${BACKUP_UID:-}" ] || [ -n "${BACKUP_GID:-}" ]; then
  chown "${BACKUP_UID:-0}:${BACKUP_GID:-0}" "$OUT_PATH" "${OUT_PATH}.sha256" 2>/dev/null || true
fi

SIZE=$(du -h "$OUT_PATH" | awk '{print $1}')
log "Backup complete (${SIZE})"

