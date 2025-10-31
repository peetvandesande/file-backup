FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash bzip2 ca-certificates coreutils cron tar tzdata xz-utils zstd \
 && rm -rf /var/lib/apt/lists/*

COPY --chmod=0755 app/entrypoint.sh /entrypoint.sh
COPY --chmod=0755 app/file-backup.sh /usr/local/bin/file-backup
COPY --chmod=0755 app/file-restore.sh /usr/local/bin/file-restore

# Install cron job
COPY --chmod=0644 debian/crontab /etc/cron.d/file-backup

VOLUME ["/backups", "/config"]

ENV BACKUP_DEST=/backups \
    BACKUP_FORMAT=tar.gz \
    RUN_ONCE=false \
    TZ=UTC

ENTRYPOINT ["/entrypoint.sh"]

