#!/usr/bin/env bash
set -euo pipefail

# Apply timezone if provided
if [ -n "${TZ:-}" ]; then
  ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime || true
  echo "$TZ" > /etc/timezone || true
fi

# Run once and exit (useful for manual or Kubernetes CronJob)
if [ "${RUN_ONCE:-false}" = "true" ]; then
  echo "[entrypoint] Running single backup..."
  exec /usr/local/bin/file-backup
  exit 0
fi

# Otherwise, start cron in foreground mode
echo "[entrypoint] Starting crond..."
exec /usr/bin/crond -f -l 2
