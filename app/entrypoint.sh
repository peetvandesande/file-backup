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
  file-backup
  exit 0
fi

# Detect environment (Alpine vs Debian)
if [ -d /etc/crontabs ]; then
  # Alpine / dcron
  echo "[entrypoint] Starting dcron..."
  exec crond -f -l 2
else
  # Debian / cron
  echo "[entrypoint] Starting cron..."
  service cron start
  tail -f /var/log/syslog /var/log/cron 2>/dev/null || tail -f /dev/null
fi

