#!/bin/sh
set -eu

# Apply timezone
if [ -n "${TZ:-}" ]; then
  if [ -e "/usr/share/zoneinfo/$TZ" ]; then
    ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime || true
    echo "$TZ" > /etc/timezone || true
  fi
fi

# One-shot mode (explicit)
if [ "${RUN_ONCE:-false}" = "true" ]; then
  echo "[entrypoint] Running single backup..."
  exec /usr/local/bin/file-backup
fi

# Default: run cron in foreground
CROND_BIN="$(command -v crond)"
echo "[entrypoint] Starting crond ($CROND_BIN)…"
exec "$CROND_BIN" -f -l 2
