# Backup and restore

Back up Postgres, Mongo, Qdrant snapshots, and the release environment. Store
archives encrypted outside the deployment host. Never commit `env.production`
or include it in an unencrypted support bundle.

## Backup

Run these from the deployment directory. Replace `BACKUP_DIR` with a protected
absolute directory on a mounted backup disk.

```bash
export BACKUP_DIR=/mnt/univai-backups/$(date -u +%Y-%m-%dT%H%M%SZ)
install -d -m 0700 "$BACKUP_DIR"
docker compose --env-file env.production -f infra/deploy/docker-compose.prod.yml exec -T postgres \
  pg_dump -U univai -d univai -Fc > "$BACKUP_DIR/postgres.dump"
docker compose --env-file env.production -f infra/deploy/docker-compose.prod.yml exec -T mongo \
  mongodump --archive > "$BACKUP_DIR/mongo.archive"
curl --fail -X POST http://127.0.0.1:6333/collections/COURSE_COLLECTION/snapshots
cp -p env.production "$BACKUP_DIR/env.production"
sha256sum "$BACKUP_DIR"/* > "$BACKUP_DIR/SHA256SUMS"
```

Qdrant is private in production. Run its snapshot request from an authenticated
administrative shell on the backend network and copy the returned snapshot out
of the volume. Record the exact collection name and Qdrant version with it.

## Restore drill

Stop application writers, verify checksums, and restore into empty volumes using
the same database versions. Keep Caddy stopped until validation completes.

```bash
sha256sum -c "$BACKUP_DIR/SHA256SUMS"
docker compose --env-file env.production -f infra/deploy/docker-compose.prod.yml stop app agent live exam
docker compose --env-file env.production -f infra/deploy/docker-compose.prod.yml exec -T postgres \
  pg_restore -U univai -d univai --clean --if-exists < "$BACKUP_DIR/postgres.dump"
docker compose --env-file env.production -f infra/deploy/docker-compose.prod.yml exec -T mongo \
  mongorestore --drop --archive < "$BACKUP_DIR/mongo.archive"
```

Restore the Qdrant snapshot through its snapshot recovery API, start the four
application services, then verify `/health/ready`, row/document counts, one cited
answer, and one exam lookup. Perform this drill before calling a backup usable.
