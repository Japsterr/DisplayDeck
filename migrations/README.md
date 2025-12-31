# Database migrations

This repo uses versioned SQL files in `migrations/` for schema changes on existing databases.

Fresh installs:
- `schema.sql` is executed automatically by the Postgres container *only on first initialization* of the Postgres volume.

Existing installs:
- Use the optional `db-migrate` compose service to apply all `.sql` files in `migrations/` (in filename sort order).

## Run migrations (Docker)

Production compose:

```bash
docker compose --env-file .env -f docker-compose.prod.yml --profile migrate up --abort-on-container-exit db-migrate
```

Local dev compose:

```bash
docker compose --profile migrate up --abort-on-container-exit db-migrate
```

Notes:
- The runner creates a `schema_migrations` table (if missing) and records applied filenames.
- If a migration is already recorded, it is skipped.
- Migrations in this repo are generally written to be idempotent (`IF NOT EXISTS` / guarded `ALTER`s), but the runner still records them for clarity.
