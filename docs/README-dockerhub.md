# 🗂️ file-backup
[![Docker Pulls](https://img.shields.io/docker/pulls/peetvandesande/file-backup.svg)](https://hub.docker.com/r/peetvandesande/file-backup)
[![Image Size](https://img.shields.io/docker/image-size/peetvandesande/file-backup/alpine)](https://hub.docker.com/r/peetvandesande/file-backup)
[![License](https://img.shields.io/badge/license-GPL--3.0-blue)](LICENSE)

Minimal, reliable backup container that creates timestamped tar archives of one or more paths.  
No rotation policy, no backup server, no surprises — just **create backups** and **restore them**.

---

## 🚀 Quick Usage

### One-off backup
```bash
docker run --rm \
  -v /var/backups:/backups \
  -v /var/www:/data:ro \
  -e BACKUP_NAME_PREFIX=web-data \
  -e BACKUP_PATHS="/data" \
  -e RUN_ONCE=1 \
  peetvandesande/file-backup:alpine
```

### Scheduled backups (cron included)
```bash
docker run -d --name file-backup \
  -v /var/backups:/backups \
  -v /var/www:/data:ro \
  -e BACKUP_NAME_PREFIX=web-data \
  -e BACKUP_PATHS="/data" \
  peetvandesande/file-backup:alpine
```

To run a backup before cron starts:
```bash
-e RUN_BACKUP_ON_START=1
```

---

## 🧰 Restore

### Restore the latest matching backup:
```bash
docker run --rm \
  -v /var/backups:/backups \
  -v /var/www:/restore \
  -e BACKUP_NAME_PREFIX=web-data \
  peetvandesande/file-backup:alpine restore /restore
```

### Restore a specific archive:
```bash
docker run --rm \
  -v /var/backups:/backups \
  -v /var/www:/restore \
  peetvandesande/file-backup:alpine restore /backups/web-data-20250101.tar.gz /restore
```

---

## ⚙️ Environment Variables

| Variable | Default | Description |
|---------|---------|-------------|
| `BACKUP_NAME_PREFIX` | **required** | Prefix for archive names |
| `BACKUP_PATHS` | **required** | Space-separated list of paths to archive |
| `BACKUPS_DIR` | `/backups` | Output directory |
| `COMPRESS` | `gz` | `gz`, `bz2`, `zst`, or `none` |
| `COMPRESS_LEVEL` | *(auto)* | Compression level |
| `VERIFY_SHA256` | `1` | Write `.sha256` checksum |
| `PRESERVE_TIMES` | `1` | Keep mtimes (`1`) or normalize (`0`) |
| `CHOWN_UID` + `CHOWN_GID` | *(unset)* | Apply ownership to created archives if set |
| `CHMOD_MODE` | *(unset)* | Apply chmod if set |
| `RUN_ONCE` | `0` | Run a single backup and exit |
| `RUN_BACKUP_ON_START` | `0` | Run backup at container startup |

---

## 📦 Output Example
```
/backups/
├── web-data-20251106.tar.gz
└── web-data-20251106.tar.gz.sha256
```

---

## 🗎 Documentation
Full restore workflow (e.g., Nextcloud):
→ https://github.com/peetvandesande/file-backup/tree/main/docs

---

## 🏷️ Tags
| Tag | Base | Description |
|-----|------|-------------|
| `alpine` (default) | alpine:3 | Small + cron + backup/restore scripts |

---

Maintained by **Peet van de Sande**
