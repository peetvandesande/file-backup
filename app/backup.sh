#!/bin/sh
set -eu
# ------------------------------------------------------------
# file-backup :: backup.sh
# - Creates a timestamped tar archive of one or more paths.
# - Busybox/Alpine/GNU-tar friendly.
# - Booleans are 1/0 (VERIFY_SHA256, PRESERVE_TIMES).
# - chown/chmod apply automatically if CHOWN_UID/GID or CHMOD_MODE are provided.
# ------------------------------------------------------------
# Env vars:
#   BACKUP_NAME_PREFIX   (required)  e.g., "nextcloud-data"
#   BACKUP_PATHS         (required)  space-separated absolute paths
#   BACKUPS_DIR          (default=/backups)
#   COMPRESS             (default=gz) one of: gz | bz2 | zst | none
#   COMPRESS_LEVEL       (optional) compression level:
#                         - gz: use env GZIP=-<level>
#                         - bz2: use env BZIP2=-<level>
#                         - zst: ZSTD_CLEVEL=<level> (best-effort)
#   VERIFY_SHA256        (default=1) 1=write/verify .sha256; 0=skip
#   PRESERVE_TIMES       (default=1) 1=preserve mtimes; 0=do not
#   CHOWN_UID            (optional) chown archive owner uid
#   CHOWN_GID            (optional) chown archive owner gid
#   CHMOD_MODE           (optional) chmod mode, e.g. 0640
#   EXCLUDE_PATTERNS     (optional) space-separated patterns (tar --exclude=PAT)
#   DATE_FMT             (default=%Y%m%d) used in backup filename
# ------------------------------------------------------------

# Simple logger with ISO timestamp
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

# Strip optional surrounding double quotes, e.g. when BACKUP_PATHS is defined as
# BACKUP_PATHS="/var/www/html /etc/nginx/nginx.conf /usr/local/etc/php/php.ini"
case "$PATHS" in
  \"*\" )
    PATHS=${PATHS#\"}   # remove leading "
    PATHS=${PATHS%\"}   # remove trailing "
    ;;
esac

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
# Use tar with relative path names (no leading "/") to avoid absolute paths in the archive.
if [ "$PRESERVE_TIMES" = "1" ]; then
  TAR_BASE_OPTS="-cp"     # create, preserve perms/times
else
  TAR_BASE_OPTS="-cpm"    # -m: don't preserve mtimes
fi

# Build exclude args
EXCLUDE_ARGS=""
if [ -n "$EXCLUDE_PATTERNS" ]; then
  for pat in $EXCLUDE_PATTERNS; do
    # Allow excludes to be specified as absolute ("/var/log") or relative ("var/log").
    case "$pat" in
      /*) pat="${pat#/}" ;;
    esac
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
    # For zstd we prefer to call tar without built-in compression and let
    # ZSTD_CLEVEL adjust the zstd level when tar uses it via -I/--use-compress-program.
    COMPRESS_ARGS="--zstd"
    ;;
  none)
    COMPRESS_ARGS=""
    ;;
esac

# ---- handle existing archive -----------------------------------------------
if [ -e "$ARCHIVE" ]; then
  log "WARNING: Archive already exists, overwriting: $ARCHIVE"
  rm -f "$ARCHIVE"
fi

# ---- Build tar command args -------------------------------------------------
# We always back up from filesystem root (/) but store *relative* paths in the archive
# (e.g. /etc → etc, /var/lib/mysql → var/lib/mysql). restore.sh then uses -C DEST
# (default DEST=/) so restores go to the right place without absolute paths baked in.
set -- $TAR_BASE_OPTS $EXCLUDE_ARGS $COMPRESS_ARGS -C / -f "$ARCHIVE"

# Convert absolute source paths to relative paths under /
for src in $PATHS; do
  if [ ! -e "$src" ]; then
    log "WARNING: source path does not exist, skipping: $src"
    continue
  fi

  case "$src" in
    /*) rel="${src#/}" ;;  # strip leading "/"
    *)
      log "ERROR: BACKUP_PATHS must contain absolute paths, got: $src"
      exit 1
      ;;
  esac

  # Special case: backing up "/" itself → archive "."
  [ -z "$rel" ] && rel="."

  set -- "$@" "$rel"
done

# ---- run tar ----------------------------------------------------------------
# shellcheck disable=SC2086
if [ "$COMPRESS" = "zst" ] && [ -n "${ZSTD_ARG:-best-effort}" ]; then
  # Inject level for zstd by setting ZSTD_CLEVEL and using tar's zstd integration.
  # Many tar builds support: tar -I 'zstd -T0', or --use-compress-program=zstd.
  # We try a couple of common forms; if they fail, fall back to uncompressed tar.
  if command -v zstd >/dev/null 2>&1; then
    if tar --help 2>/dev/null | grep -q -- "--use-compress-program"; then
      log "INFO: zstd option 1"
      ZSTD_CLEVEL="${COMPRESS_LEVEL}" tar --use-compress-program=zstd "$@" || { log "ERROR: tar+zstd failed"; exit 1; }
    elif tar --help 2>/dev/null | grep -q -- "-I"; then
      log "INFO: zstd option 2"
      ZSTD_CLEVEL="${COMPRESS_LEVEL}" tar -I zstd "$@" || { log "ERROR: tar -I zstd failed"; exit 1; }
    else
      # Fallback: let tar write to stdout and pipe to zstd
      log "INFO: zstd option 3"
      tmp="${ARCHIVE}.tmp"
      rm -f "$tmp"
      ZSTD_CLEVEL="${COMPRESS_LEVEL}" tar $TAR_BASE_OPTS $EXCLUDE_ARGS -f - $PATHS | zstd -o "$tmp"
      mv "$tmp" "$ARCHIVE"
    fi
  else
    log "WARNING: zstd not found; creating uncompressed tar instead."
    tar $TAR_BASE_OPTS $EXCLUDE_ARGS -f "$ARCHIVE" $PATHS
  fi
elif [ "$COMPRESS" = "zst" ] && [ -z "${ZSTD_ARG:-}" ]; then
  # If we don't have a specific level arg, still try zstd in a simple way
  if command -v zstd >/dev/null 2>&1 && tar --help 2>/dev/null | grep -q -- "--use-compress-program"; then
    log "INFO: zstd option 4"
    ZSTD_CLEVEL="${COMPRESS_LEVEL}" tar --use-compress-program=zstd "$@" || { log "ERROR: tar+zstd failed"; exit 1; }
  else
    log "WARNING: zstd integration not available; creating uncompressed tar instead."
    tar "$@" || { log "ERROR: tar failed"; exit 1; }
  fi
else
  tar "$@" || { log "ERROR: tar failed"; exit 1; }
fi

log "Archive created: $ARCHIVE"

# ---- checksum ---------------------------------------------------------------
if [ "$VERIFY_SHA256" = "1" ]; then
  log "Computing SHA-256 checksum..."
  sha256sum "$ARCHIVE" > "$SHA_FILE"
  log "Wrote checksum file: $SHA_FILE"
fi

# ---- post-processing: chown/chmod -------------------------------------------
if [ -n "$CHOWN_UID" ] || [ -n "$CHOWN_GID" ]; then
  target_uid="${CHOWN_UID:-}"
  target_gid="${CHOWN_GID:-}"
  # If only UID or only GID is provided, try to keep the other unchanged
  if [ -z "$target_uid" ] && [ -n "$target_gid" ]; then
    target_uid="$(id -u)"
  elif [ -n "$target_uid" ] && [ -z "$target_gid" ]; then
    target_gid="$(id -g)"
  fi

  if [ -n "$target_uid" ] && [ -n "$target_gid" ]; then
    chown "$target_uid:$target_gid" "$ARCHIVE" 2>/dev/null || true
    [ -f "$SHA_FILE" ] && chown "$target_uid:$target_gid" "$SHA_FILE" 2>/dev/null || true
    log "Set ownership to ${target_uid}:${target_gid}"
  fi
fi

# Apply chmod if provided
if [ -n "${CHMOD_MODE}" ]; then
  chmod "$CHMOD_MODE" "$ARCHIVE" 2>/dev/null || true
  [ -f "$SHA_FILE" ] && chmod "$CHMOD_MODE" "$SHA_FILE" 2>/dev/null || true
  log "Set permissions to ${CHMOD_MODE}"
fi

log "Backup completed successfully."
