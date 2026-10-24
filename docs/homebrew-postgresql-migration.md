# Homebrew PostgreSQL foundation

This is the first, **non-migrating** step toward a Docker-free local development setup.
The added `HomebrewPostgres` helper is not wired into service registrations or the UI yet.

## Safety contract

- Keep current Docker Compose registrations and volumes intact.
- Do not invoke `docker compose down -v`, `docker volume rm`, `initdb`, or `pg_ctl` automatically during discovery.
- Require an explicit, already-initialized data directory with `PG_VERSION`.
- Invoke `pg_ctl` through `Process` with argument arrays; do not interpolate a user path into a shell command.
- Scope status/start/stop to the exact chosen data directory. Never stop another cluster based on a port match.
- PostgreSQL 16 is required for the existing PostgreSQL 16 Docker installations. Do not switch major versions during data migration.

## Before any cutover

1. Inventory each Compose project, credentials, roles, extensions, DB names, and current mounts.
2. Back up the WakTrainer and authentication databases and verify the backups can restore.
3. Install `postgresql@16` using Homebrew, without changing an existing running Docker database.
4. Initialize **separate** native clusters for services that need isolation, and use the intended 5433 and 5434 ports only after verifying they are free.
5. Restore into a temporary native cluster and compare schemas and representative data.
6. Update server connection configuration only after recovery checks pass.
7. Retain Docker containers and volumes until user-approved cutover and rollback validation.

## Next implementation

Add a dedicated `homebrewPostgres` service kind, an explicit cluster-directory and port editor, status/start/stop integration, and readiness checks. Keep manual install and migration as separate user-approved operations. Then test on the target Mac; macOS CI cannot verify local Homebrew installation or migrate real data.
