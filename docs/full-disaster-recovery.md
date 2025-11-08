# Full Disaster Recovery Guide

This guide provides a **complete restore workflow** for rebuilding a Nextcloud deployment using the backups created by `file-backup` and `pg-backup`.

This applies to:
- Host failure recovery
- Migration to a new machine
- Recreating volumes cleanly

---

## 1) Collect Required Files

| Item | Example |
|------|---------|
| Nextcloud data+config backup | `nextcloud-data-YYYYMMDD.tar.gz` |
| Database dump | `nextcloud-db-YYYYMMDD.sql` |
| Original compose file | `docker-compose.yml` (matching Nextcloud version recommended) |
| Environment file | `db.env` (with current POSTGRESS_PASSWORD) |

Place them together, e.g.:

```
/restore/
  docker-compose.yml
  nextcloud-data-20251106.tar.gz
  nextcloud-db-20251106.sql
  db.env
  
```

---

## 2) Recreate Volumes & Network (Do Not Start Services)

```bash
docker compose up --no-start
```

This:
- Creates named volumes
- Creates required networks
- Leaves containers **stopped** → correct state for restore

---

## 3) Restore Application Data

```bash
docker run --rm \
  -v $PWD:/backups \
  -v nextcloud-data:/var/www/html/data \
  -v nextcloud-config:/var/www/html/config \
  -e BACKUP_NAME_PREFIX=nextcloud-data \
  peetvandesande/file-backup:alpine restore
```

To restore a **specific** file instead of latest:

```bash
peetvandesande/file-backup:alpine restore /backups/nextcloud-data-20251106.tar.gz
```

---

## 4) Restore Database (pg-backup Example)

Start DB only:

```bash
docker compose up -d nextcloud-db
sleep 4
```

Restore:

```bash
docker run --rm \
  -v $PWD:/backups \
  -e BACKUP_NAME_PREFIX=nextcloud-db \
  --env-file db.env \
  --network nextcloud_default \
  peetvandesande/pg-backup:alpine restore /backups/nextcloud-db-20251106.sql
```

---

## 5) Start Nextcloud

```bash
docker compose up -d nextcloud
```

Wait 30 seconds, then open the web UI.

---

## 6) Verification Checklist

| Check | How |
|------|-----|
| Config restored | `config.php` has correct trusted domains | 
| Files restored | Files visible in UI |
| Shares intact | Shared folders reappear |
| No upgrade screen | App version matches backed-up version |

---

## 7) Optional: Safe Trial Restore (No Risk)

```bash
mkdir /tmp/test-restore
docker run --rm \
  -v $PWD:/backups \
  -v /tmp/test-restore:/restore \
  peetvandesande/file-backup:alpine restore /restore
```

Inspect before restoring volumes.

---

## Done ✅

You now have a **repeatable, auditable, zero-surprise Disaster Recovery workflow.**
