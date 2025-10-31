FROM alpine:3

RUN apk add --no-cache \
      bash ca-certificates coreutils dcron findutils gzip shadow tar tzdata zstd \
  && addgroup -S backup && adduser -S -G backup backup

COPY --chmod=0755 app/entrypoint.sh /entrypoint.sh
COPY --chmod=0755 app/file-backup.sh /usr/local/bin/file-backup
COPY --chmod=0755 app/file-restore.sh /usr/local/bin/file-restore

# Install cron job
COPY --chmod=0644 alpine/crontab /etc/crontabs/root

VOLUME ["/backups", "/config"]

ENV BACKUP_DEST=/backups \
    BACKUP_FORMAT=tar.gz \
    RUN_ONCE=false \
    TZ=UTC

ENTRYPOINT ["/entrypoint.sh"]

