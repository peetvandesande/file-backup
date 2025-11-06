# file-backup

[![Docker Pulls](https://img.shields.io/docker/pulls/peetvandesande/file-backup)](https://hub.docker.com/r/peetvandesande/file-backup)
[![Image Size](https://img.shields.io/docker/image-size/peetvandesande/file-backup/alpine)](https://hub.docker.com/r/peetvandesande/file-backup)
[![License](https://img.shields.io/badge/license-GPL--3.0-blue)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/peetvandesande/file-backup)](https://github.com/peetvandesande/file-backup/commits/main)
[![GitHub Stars](https://img.shields.io/github/stars/peetvandesande/file-backup?style=flat)](https://github.com/peetvandesande/file-backup/stargazers)



Minimal. Deterministic. Boring in the *good* way.

`file-backup` is a dead-simple backup container that creates timestamped tar archives from one or more paths. It does **not** try to outsmart you. No pruning logic. No backup rotation policy. No orchestration opinion. It just *makes the backup you told it to make*—every time, identically.

This makes it ideal for:
- Container volume backups
- Pre-upgrade snapshots
- CI artifact capture
- Bare-metal config capture
- Homelab sanity

If you want Borg, Restic, Syncthing, or ZFS send/receive—use those.  
If you want *one portable, predictable backup job in one container*—use this.

---

## How it Works (at a glance)

```
backup.sh   → create timestamped archive from paths (relative, not absolute)
restore.sh  → restore the newest matching archive (or a supplied one)
entrypoint.sh → coordinates cron or one-shot backup workflows
```

Everything is POSIX `sh`, Alpine-compatible, and inspectable. No Python, no Go binary, no sidecar services, no daemon.

---

## Runtime Usage, Env Variables, and Examples

See the Docker Hub page (this is where the usage docs live):

→ https://hub.docker.com/r/peetvandesande/file-backup

This keeps the GitHub README focused on design and contribution rather than deployment examples.

---

## Tag & Version Strategy

| Branch | Image Tag(s) | Notes |
|--------|-------------|-------|
| `main` | `latest`, `<version>`, `<version>-alpine`, `<sha>` | Always stable |
| `dev`  | `dev`, `dev-alpine`, `dev-<sha>` | Safe for testing / staging |
| feature branches | `<branch>`, `<branch>-alpine`, `<branch>-<sha>` | Useful in real org workflows |

You always know **exactly** what image you’re running.  
Yes, this is intentional.

---

## Local Development

Clone and build:

```bash
git clone https://github.com/peetvandesande/file-backup.git
cd file-backup
make print       # show tags and detected metadata
make build       # local build
make push        # push via buildx multiarch (if configured)
```

Run test backup locally:

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

### Documentation

- **Nextcloud Backup & Restore** → [`docs/nextcloud-backup-restore.md`](docs/nextcloud-backup-restore.md)

---

## Philosophy

> **Predictability > Cleverness**

- Backups should be reproducible and explainable.
- Restores should not require detective work.
- Complexity belongs in retention/replication layers, not the backup job itself.

You can chain this container with:
- `rclone` → push backups to S3/Wasabi/B2
- `restic` → dedupe + encryption + retention
- `syncthing` → multi-node sync
- `ssh` → ship artifacts off-host

But this container itself stays **small, legible, and uninteresting**.  
(That’s a compliment.)

---

## License

**GPL-3.0**

See `LICENSE` in this repository.

---

## Maintainer

**Peet van de Sande**  
https://github.com/peetvandesande

Feel free to open PRs, file issues, or treat this like infrastructure legos.
