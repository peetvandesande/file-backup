# 🗂️ file-backup
[![Docker Pulls](https://img.shields.io/docker/pulls/peetvandesande/file-backup.svg)](https://hub.docker.com/r/peetvandesande/file-backup)
[![Image Size](https://img.shields.io/docker/image-size/peetvandesande/file-backup/alpine)](https://hub.docker.com/r/peetvandesande/file-backup)
[![License](https://img.shields.io/badge/license-GPL--3.0-blue)](https://github.com/peetvandesande/file-backup/blob/main/LICENSE)

Lightweight backup container that creates timestamped tar archives.

No rotation, pruning, encryption, or cloud upload logic is included — **bring your own retention policy**.

---

## 🚀 Quick Usage

### One-off backup

```bash
docker run --rm \
  -v /var/backups:/backups \
  -v /var/www/html:/data:ro \
  -e BACKUP_NAME_PREFIX=web-data \
  -e BACKUP_PATHS="/data" \
  -e RUN_ONCE=1 \
  peetvandesande/file-backup:alpine
```

### Scheduled backup ( daily at 02:30 by default )

```bash
docker run -d --name web-backup \
  -v /var/backups:/backups \
  -v /var/www/html:/data:ro \
  -e BACKUP_NAME_PREFIX=web-data \
  -e BACKUP_PATHS="/data" \
  peetvandesande/file-backup:alpine
```

Override schedule:
```bash
-v ./crontab:/etc/crontabs/root:ro
```

To run a backup before cron starts:
```bash
-e RUN_BACKUP_ON_START=1
```

---

## 🧰 Restore

Restore the **latest matching** archive:

```bash
docker run --rm \
  -v /var/backups:/backups \
  -v /var/www/html:/restore \
  peetvandesande/file-backup:alpine restore /restore
```

Restore a **specific** archive:

```bash
docker run --rm \
  -v /var/backups:/backups \
  -v /var/www/html:/restore \
  peetvandesande/file-backup:alpine restore /backups/web-data-20251106.tar.gz /restore
```

If you want predictable chmod/chown after extraction, restore into a fresh directory and then adjust ownership afterwards.

---

## ⚙️ Environment Variables

| Variable | Default | Description |
|---------|---------|-------------|
| `BACKUP_NAME_PREFIX` | **required** | Prefix for archive filenames |
| `BACKUP_PATHS` | **required** | Space-separated list of paths to include |
| `BACKUPS_DIR` | `/backups` | Where archives are stored |
| `COMPRESS` | `gz` | `gz`, `bz2`, `zst`, or `none` |
| `COMPRESS_LEVEL` | *(auto)* | Optional compression level |
| `VERIFY_SHA256` | `1` | `1` = write `.sha256` file |
| `PRESERVE_TIMES` | `1` | `1` = keep mtimes, `0` = normalize |
| `CHOWN_UID` | *(unset)* | Apply user ownership (if set) |
| `CHOWN_GID` | *(unset)* | Apply group ownership (if set) |
| `CHMOD_MODE` | *(unset)* | Apply mode to archive/sha file e.g. `0640` |
| `EXCLUDE_PATTERNS` | *(unset)* | Space-separated patterns → `tar --exclude=` |
| `RUN_ONCE` | `0` | Run backup once and exit |
| `RUN_BACKUP_ON_START` | `0` | Run backup before cron starts |

### Ownership Logic Example

```bash
# Force UID=34, keep existing GID:
-e CHOWN_UID=34

# Force GID=34, keep existing UID:
-e CHOWN_GID=34

# Force both explicitly:
-e CHOWN_UID=34 -e CHOWN_GID=34
```

---

## 📦 Output Format

```
/backups/
├── web-data-20251106.tar.gz
└── web-data-20251106.tar.gz.sha256
```

---

## 🏷️ Tags

| Tag | Description |
|-----|-------------|
| `alpine` (default) | Smallest runtime image |
| `dev` | Work-in-progress branch images |
| `<version>` | Tagged stable releases |

---

## 🐳 Docker Compose Example

```yaml
services:
  web:
    image: "httpd"
    volumes:
      - www-data:/var/www

  web-backup:
    image: peetvandesande/file-backup
    environment:
      - BACKUP_NAME_PREFIX=web-data
      - BACKUP_PATHS="/var/www/html"
      - COMPRESS=bz2
      - CHOWN_UID=34
      - CHOWN_GID=34
      - CHMOD_MODE=0640
    volumes:
      - www-data:/var/www:ro
      - /var/backups:/backups

volumes:
  www-data: {}    
    
```

This setup runs a Apache HTTPD container and a backup container side by side,  
with backups stored under `./backups` on the host.


---

Full docs and Nextcloud guide available here:  
→ https://github.com/peetvandesande/file-backup/tree/main/docs/

