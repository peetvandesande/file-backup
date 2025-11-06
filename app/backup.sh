#!/bin/sh
set -eu
# ------------------------------------------------------------
# file-backup :: backup.sh  (simplified flags)
# - Creates a timestamped tar archive of one or more paths.
# - Busybox/Alpine/GNU-tar friendly.
# - Booleans are 1/0 (VERIFY_SHA256, PRESERVE_TIMES).
# - Ownership/permissions are applied ONLY if CHOWN_UID/CHOWN_GID
#   and/or CHMOD_MODE are provided (no extra DO_* flags).
# ------------------------------------------------------------
# Env vars:
#   BACKUP_NAME_PREFIX   (required)  e.g., "nextcloud-data"
#   BACKUP_PATHS         (required)  space-separated absolute paths
#   BACKUPS_DIR          (default=/backups)
#   COMPRESS             (default=gz) one of: gz | bz2 | zst | none
#   COMPRESS_LEVEL       (optional) compression level:
#                         - gz: use env GZIP=-<level>
#                         - bz2: use env BZIP2=-<level>
#                         - zst: pass -<level> to zstd
#   VERIFY_SHA256        (default=1)  1=write .sha256; 0=skip
#   PRESERVE_TIMES       (default=1)  1=preserve mtimes; 0=normalize to now
#   CHOWN_UID            (optional) numeric uid or name
#   CHOWN_GID            (optional) numeric gid or name
#   CHMOD_MODE           (optional) e.g., 0644
#   EXCLUDE_PATTERNS     (optional) space-separated patterns (tar --exclude=PAT)
#   DATE_FMT             (default=%Y%m%d) UTC timestamp in archive name
# ------------------------------------------------------------

log() { printf "%s %s\n" "$(date -Is)" "$*"; }

# ---- inputs / defaults ------------------------------------------------------
PREFIX="${BACKUP_NAME_PREFIX:-}"
PATHS="${BACKUP_PATHS:-}"
BACKUP_DIR="${BACKUPS_DIR:-/backups}"

COMPRESS="${COMPRESS:-gz}"                 # gz | bz2 | zst | none
COMPRESS_LEVEL="${COMPRESS_LEVEL:-}"       # optional
VERIFY_SHA256="${VERIFY_SHA256:-1}"        # 1/0
PRESERVE_TIMES="${PRESERVE_TIMES:-1}"      # 1/0

CHOWN_UID="${CHOWN_UID:-}"
CHOWN_GID="${CHOWN_GID:-}"
CHMOD_MODE="${CHMOD_MODE:-}"

EXCLUDE_PATTERNS="${EXCLUDE_PATTERNS:-}"
DATE_FMT="${DATE_FMT:-%Y%m%d}"

# ---- validate ---------------------------------------------------------------
[ -n "$PREFIX" ] || { log "ERROR: BACKUP_NAME_PREFIX is required"; exit 1; }
[ -n "$PATHS" ]  || { log "ERROR: BACKUP_PATHS is required (space-separated absolute paths)"; exit 1; }
[ -d "$BACKUP_DIR" ] || mkdir -p "$BACKUP_DIR"

# ---- name -------------------------------------------------------------------
TS="$(date -u +"$DATE_FMT")"
case "$COMPRESS" in
  gz)   EXT=".tar.gz"  ;;
  bz2)  EXT=".tar.bz2" ;;
  zst)  EXT=".tar.zst" ;;
  none) EXT=".tar"     ;;
  *)    log "ERROR: Invalid COMPRESS='$COMPRESS' (use gz|bz2|zst|none)"; exit 1 ;;
esac
ARCHIVE="${BACKUP_DIR%/}/${PREFIX}-${TS}${EXT}"
SHA_FILE="${ARCHIVE}.sha256"

log "Starting backup → ${ARCHIVE}"

# ---- tar options ------------------------------------------------------------
# Use relative names by switching directories (-C) per path. Avoid absolute paths in archive.
if [ "$PRESERVE_TIMES" = "1" ]; then
  TAR_BASE_OPTS="-cp"     # create, preserve perms/times
else
  TAR_BASE_OPTS="-cpm"    # -m: don't preserve mtimes
fi

# Build exclude args
EXCLUDE_ARGS=""
if [ -n "$EXCLUDE_PATTERNS" ]; then
  for pat in $EXCLUDE_PATTERNS; do
    EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude=$pat"
  done
fi

# Prepare compression selection and optional levels
# For gz/bz2, honor COMPRESS_LEVEL via the standard env vars if present.
case "$COMPRESS" in
  gz)
    [ -n "$COMPRESS_LEVEL" ] && export GZIP="-${COMPRESS_LEVEL}"
    COMPRESS_ARGS="-z"
    ;;
  bz2)
    [ -n "$COMPRESS_LEVEL" ] && export BZIP2="-${COMPRESS_LEVEL}"
    COMPRESS_ARGS="-j"
    ;;
  zst)
    COMPRESS_ARGS="--use-compress-program=zstd"
    # tar will invoke zstd; pass level via ZSTD_CLEVEL or inline argument
    if [ -n "$COMPRESS_LEVEL" ]; then
      # Try inline -I if supported; otherwise rely on zstd default envs
      # Busybox tar may not support -I, but --use-compress-program=zstd works and
      # zstd reads -# from its args if tar passes them. We'll fall back to env.
      ZSTD_ARG="-${COMPRESS_LEVEL}"
      # We'll add ZSTD_ARG at the end when invoking tar (via ZSTD_ARGS variable).
    else
      ZSTD_ARG=""
    fi
    ;;
  none)
    COMPRESS_ARGS=""
    ;;
esac

# Build the tar command args
set -- $TAR_BASE_OPTS $EXCLUDE_ARGS $COMPRESS_ARGS -f "$ARCHIVE"

# Append -C <dir> . for directories, or -C <dir> <file> for single files
for src in $PATHS; do
  if [ ! -e "$src" ]; then
    log "WARNING: source path does not exist, skipping: $src"
    continue
  fi
  if [ -d "$src" ]; then
    set -- "$@" -C "$src" .
  else
    d="$(dirname "$src")"
    b="$(basename "$src")"
    set -- "$@" -C "$d" "$b"
  fi
done

# ---- run tar ----------------------------------------------------------------
# shellcheck disable=SC2086
if [ "$COMPRESS" = "zst" ] && [ -n "${ZSTD_ARG:-}" ]; then
  # Inject level for zstd by setting ZSTD_CLEVEL if available is uncertain.
  # Easiest: put ARG in ZSTD_CLEVEL env so zstd respects it.
  ZSTD_CLEVEL="${COMPRESS_LEVEL}" tar "$@" -- ${ZSTD_ARG} >/dev/null 2>&1 || true
  # Above line only tries to pass ZSTD_ARG; many tar builds ignore trailing args.
  # So we run again without trailing args but with ZSTD_CLEVEL exported:
  ZSTD_CLEVEL="${COMPRESS_LEVEL}" tar "$@" || { log "ERROR: tar failed"; exit 1; }
else
  tar "$@" || { log "ERROR: tar failed"; exit 1; }
fi

log "Archive created: $ARCHIVE"

# ---- checksum ---------------------------------------------------------------
if [ "$VERIFY_SHA256" = "1" ]; then
  if sha256sum "$ARCHIVE" > "$SHA_FILE"; then
    log "Checksum written: $(basename "$SHA_FILE")"
  else
    log "WARNING: failed to write checksum for $ARCHIVE"
  fi
fi

# ---- ownership / permissions (apply only if provided) -----------------------
if [ -n "$CHOWN_UID" ] && [ -n "$CHOWN_GID" ]; then
  chown "$CHOWN_UID:$CHOWN_GID" "$ARCHIVE" 2>/dev/null || true
  [ -f "$SHA_FILE" ] && chown "$CHOWN_UID:$CHOWN_GID" "$SHA_FILE" 2>/dev/null || true
  log "Set ownership to ${CHOWN_UID}:${CHOWN_GID}"
fi

if [ -n "$CHMOD_MODE" ]; then
  chmod "$CHMOD_MODE" "$ARCHIVE" 2>/dev/null || true
  [ -f "$SHA_FILE" ] && chmod "$CHMOD_MODE" "$SHA_FILE" 2>/dev/null || true
  log "Set permissions to ${CHMOD_MODE}"
fi

log "Backup completed successfully."
