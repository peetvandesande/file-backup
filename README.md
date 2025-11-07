# file-backup

[![Docker Pulls](https://img.shields.io/docker/pulls/peetvandesande/file-backup)](https://hub.docker.com/r/peetvandesande/file-backup)
[![Image Size](https://img.shields.io/docker/image-size/peetvandesande/file-backup/alpine)](https://hub.docker.com/r/peetvandesande/file-backup)
[![License](https://img.shields.io/badge/license-GPL--3.0-blue)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/peetvandesande/file-backup)](https://github.com/peetvandesande/file-backup/commits/main)
[![GitHub Stars](https://img.shields.io/github/stars/peetvandesande/file-backup?style=flat)](https://github.com/peetvandesande/file-backup/stargazers)

Minimal. Deterministic. Boring in the *good* way.

`file-backup` is a dead-simple backup container that creates timestamped tar archives from one or more paths.
No pruning. No cleverness. No surprises.
---

## How it Works (at a glance)

```
backup.sh   → create timestamped archive from paths (relative, not absolute)
restore.sh  → restore the newest matching archive (or a supplied one)
entrypoint.sh → coordinates cron or one-shot backup workflows
```

Everything is POSIX `sh`, Alpine-compatible, and inspectable. No Python, no Go binary, no sidecar services, no daemon.

---

## Documentation

- **Nextcloud Backup & Restore Guide** → `docs/nextcloud-backup-restore.md`
- **Full Disaster Recovery Guide** → `docs/full-disaster-recovery.md`
- Runtime usage & environment reference: https://hub.docker.com/r/peetvandesande/file-backup

---

## Tag & Version Strategy

| Branch        | Tags Published                                              |
|---------------|------------------------------------------------------------|
| `main`        | `latest`, `<version>`, `<version>-alpine`, `<sha>`         |
| `dev`         | `dev`, `dev-alpine`, `dev-<sha>`                           |
| Feature Branches | `<branch>`, `<branch>-alpine`, `<branch>-<sha>`        |

You always know exactly what image you are running.

---

## Local Development

Clone and build:

```bash
git clone https://github.com/peetvandesande/file-backup.git
cd file-backup
make print       # Show build metadata and tags
make build       # Build image locally
make push        # Buildx multi-arch push
```

Test backup locally:

```bash
docker run --rm \
  -v $PWD/testdata:/data:ro \
  -v $PWD/out:/backups \
  -e BACKUP_NAME_PREFIX=test \
  -e BACKUP_PATHS="/data" \
  -e RUN_ONCE=1 \
  peetvandesande/file-backup:dev
```

---

## Philosophy

> Simplicity scales. Complexity fails.

If you want encryption, deduplication, snapshot rotation or replication, layer those **on top**.  
This container stays small, clear, and auditable.

---

## License

GPL-3.0 — see `LICENSE`

---

## Maintainer

**Peet van de Sande**  
https://github.com/peetvandesande
