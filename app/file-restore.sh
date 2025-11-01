#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: file-restore /backups/prefix-YYYYmmdd.tar[.gz|.bz2|.zst] [DEST_DIR]"
  exit 1
fi

ARCHIVE="$1"
DEST="${2:-/}"

echo "[restore] Restoring $ARCHIVE to $DEST"
case "$ARCHIVE" in
  *.tar.gz)  tar -xzp -f "$ARCHIVE" -C "$DEST" ;;
  *.tar.bz2) tar -xjp -f "$ARCHIVE" -C "$DEST" ;;
  *.tar.zst) tar --use-compress-program=zstd -xp -f "$ARCHIVE" -C "$DEST" ;;
  *.tar)     tar -xp -f "$ARCHIVE" -C "$DEST" ;;
  *) echo "Unsupported archive type: $ARCHIVE"; exit 1 ;;
esac
echo "[restore] Done."
