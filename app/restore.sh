#!/bin/sh
set -eu

# Simple logger with ISO timestamp
log() { printf "%s %s\n" "$(date -Is)" "$*"; }

# ---- Inputs / env -----------------------------------------------------------
DEST="${2:-/}"                                 # optional 2nd arg = restore destination
BACKUP_DIR="${BACKUPS_DIR:-/backups}"          # env override; default /backups
PREFIX="${BACKUP_NAME_PREFIX:-}"               # optional filter prefix
VERIFY="${VERIFY_SHA256:-1}"                   # 1 = verify when .sha256 present
PRESERVE_TIMES="${PRESERVE_TIMES:-1}"          # 1 = preserve mtimes, 0 = ignore mtimes

# ---- Helpers ----------------------------------------------------------------
is_supported() {
  case "$1" in
    *.tar|*.tar.gz|*.tar.bz2|*.tar.zst) return 0 ;;
    *) return 1 ;;
  esac
}

# Busybox/Alpine-friendly newest-file resolver (no 'find -printf')
find_latest() {
  tmp="$(mktemp)"
  p1="$BACKUP_DIR/${PREFIX}*.tar.gz"
  p2="$BACKUP_DIR/${PREFIX}*.tar.bz2"
  p3="$BACKUP_DIR/${PREFIX}*.tar.zst"
  p4="$BACKUP_DIR/${PREFIX}*.tar"

  for pat in "$p1" "$p2" "$p3" "$p4"; do
    # shell expands; if no match, pat stays literal -> skip
    for f in $pat; do
      [ -e "$f" ] || continue
      printf '%s\0' "$f" >> "$tmp"
    done
  done

  if [ -s "$tmp" ]; then
    CANDIDATE="$(xargs -0 ls -1t 2>/dev/null <"$tmp" | head -n1 || true)"
    rm -f "$tmp"
    [ -n "${CANDIDATE:-}" ] && printf '%s\n' "$CANDIDATE" || return 1
  else
    rm -f "$tmp"
    return 1
  fi
}

# ---- Resolve backup file ----------------------------------------------------
ARG_FILE="${1:-}"
BACKUP_FILE=""

if [ -n "$ARG_FILE" ]; then
  if [ -f "$ARG_FILE" ]; then
    BACKUP_FILE="$ARG_FILE"
    log "Using explicit backup file: $BACKUP_FILE"
  else
    log "ERROR: Provided file does not exist: $ARG_FILE" >&2
    exit 1
  fi
else
  log "PREFIX: ${PREFIX:-<none>}"
  log "Scanning for newest archive in: $BACKUP_DIR"
  CANDIDATE="$(find_latest || true)"
  if [ -n "${CANDIDATE:-}" ] && [ -f "$CANDIDATE" ]; then
    BACKUP_FILE="$CANDIDATE"
    log "Selected newest archive: $BACKUP_FILE"
  else
    log "ERROR: Backup file '' not found. Provide a file path or ensure historical backups exist." >&2
    exit 1
  fi
fi

# ---- Validate extension -----------------------------------------------------
if ! is_supported "$BACKUP_FILE"; then
  log "ERROR: Unsupported archive type: $BACKUP_FILE" >&2
  exit 1
fi

# ---- Verify checksum (if requested and .sha256 exists) ----------------------
if [ "$VERIFY" = "1" ] && [ -f "${BACKUP_FILE}.sha256" ]; then
  log "Verifying checksum: ${BACKUP_FILE}.sha256"
  if ! sha256sum -c "${BACKUP_FILE}.sha256"; then
    log "ERROR: SHA-256 verification failed for ${BACKUP_FILE}" >&2
    exit 1
  fi
fi

# ---- Build tar options (respect PRESERVE_TIMES=1/0) -------------------------
if [ "$PRESERVE_TIMES" = "1" ]; then
  TAR_OPTS="-xp"         # preserve perms and times
else
  TAR_OPTS="-xpm"        # -m: do not preserve modification times
fi

# ---- Extract ----------------------------------------------------------------
log "Restoring to: $DEST"
case "$BACKUP_FILE" in
  *.tar.gz)  tar $TAR_OPTS -z -f "$BACKUP_FILE" -C "$DEST" ;;
  *.tar.bz2) tar $TAR_OPTS -j -f "$BACKUP_FILE" -C "$DEST" ;;
  *.tar.zst) tar --use-compress-program=zstd $TAR_OPTS -f "$BACKUP_FILE" -C "$DEST" ;;
  *.tar)     tar $TAR_OPTS    -f "$BACKUP_FILE" -C "$DEST" ;;
esac

log "Restore completed successfully."
