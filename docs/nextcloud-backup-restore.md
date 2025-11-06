# Nextcloud Backup & Restore Guide (with file-backup)

This guide covers how to **backup and restore Nextcloud** using the `file-backup` container.

It assumes:
- Your Nextcloud is running via Docker Compose
- You are storing data in named volumes
- You want **deterministic, inspectable backups** without database magic or hidden actions

---

## 🎯 What We Backup

Nextcloud has three critical components:

| Component | What it is | How we back it up |
|----------|------------|------------------|
| **Application config** | `config.php`, trusted domains, app configuration | Back up `/var/www/html/config` |
| **User data** | Files uploaded by users | Back up `/var/www/html/data` |
| **Database** | Metadata, user records, sharing links | Use `pg_dump` / `mysqldump` or a DB-specific backup container |

This container **does not** dump the database.  
You must pair it with your DB backup of choice.

---

## 🧱 Example docker-compose.yml (Nextcloud)

```yaml
services:
  nextcloud:
    image: nextcloud:31
    volumes:
      - nextcloud-html:/var/www/html
      - nextcloud-data:/var/www/html/data
      - nextcloud-config:/var/www/html/config

  nextcloud-db:
    image: postgres:17
    volumes:
      - nextcloud-db:/var/lib/postgresql/data

volumes:
  nextcloud-html:
  nextcloud-data:
  nextcloud-config:
  nextcloud-db:
```

---

## 📦 Backup Nextcloud Data

```bash
docker run --rm \
  -v /var/backups/sylvie:/backups \
  -v nextcloud-data:/var/www/html/data:ro \
  -v nextcloud-config:/var/www/html/config:ro \
  -e BACKUP_NAME_PREFIX=nextcloud-data \
  -e BACKUP_PATHS="/var/www/html/data /var/www/html/config" \
  -e RUN_ONCE=1 \
  peetvandesande/file-backup:alpine
```

This creates files like:

```
/var/backups/sylvie/
├── nextcloud-data-20251106.tar.gz
└── nextcloud-data-20251106.tar.gz.sha256
```

For the **database**, use your existing DB dump strategy (example for PostgreSQL):

```bash
pg_dump -U nextcloud -h nextcloud-db nextcloud > /var/backups/sylvie/nextcloud-db-20251106.sql
```

---

## 🧰 Restore Procedure

Restoring Nextcloud correctly **requires that volumes exist before restore.**  
Do **not** recreate the app first.

### 1. Recreate volumes **without starting containers**

```bash
docker compose up --no-start
```

This ensures:
- Volumes are created
- Networks are created
- The application is still **stopped** (correct state for restore)

### 2. Restore nextcloud-data + config

```bash
docker run --rm \
  -v /var/backups/sylvie:/backups \
  -v nextcloud-data:/var/www/html/data \
  -v nextcloud-config:/var/www/html/config \
  -e BACKUP_NAME_PREFIX=nextcloud-data \
  peetvandesande/file-backup:alpine restore /
```

If you want to restore a **specific file** instead of latest:

```bash
peetvandesande/file-backup:alpine restore /backups/nextcloud-data-20251106.tar.gz /
```

### 3. Restore the database

Example:

```bash
psql -U nextcloud -h nextcloud-db < /var/backups/sylvie/nextcloud-db-20251106.sql
```

### 4. Start Nextcloud normally

```bash
docker compose up -d
```

---

## ✅ Verification Checklist (after restore)

| Check | How |
|-------|-----|
| Config is restored | Open `config.php`, verify domain + DB settings |
| User files present | Web UI → Files |
| Shares intact | Users can see previously shared folders |
| Apps available | Settings → Apps |

---

## 🧊 Notes

- `PRESERVE_TIMES=0` can reduce tar restore warnings
- To test a restore **safely**, restore into a temporary directory instead of the live volume
- If using external storage apps, confirm mount points in config.php

---

## 🛠 Troubleshooting

| Problem | Fix |
|--------|------|
| Nextcloud upgrade screen appears | You restored data from a newer version than the app. Use matching image versions. |
| Users see “files not found” | Data directory path in config.php mismatches deployment |
| Restore produced warnings about timestamps | Use `-e PRESERVE_TIMES=0` on restore |

---

## Done ✅

You now have a **repeatable, auditable, zero-surprise Nextcloud backup + restore workflow.**
