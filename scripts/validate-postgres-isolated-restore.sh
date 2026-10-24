#!/bin/bash
# Validate a PostgreSQL custom-format backup by restoring into a disposable DB.
# Never drops, truncates, or changes existing databases.
set -euo pipefail
usage() { echo "Usage: $0 --archive FILE --host 127.0.0.1 --port PORT --user ROLE --database NEW_DISPOSABLE_NAME" >&2; }
archive="" ; host="" ; port="" ; role="" ; database=""
while (($#)); do
 case "$1" in
 --archive) archive="${2:?}"; shift 2;;
 --host) host="${2:?}"; shift 2;;
 --port) port="${2:?}"; shift 2;;
 --user) role="${2:?}"; shift 2;;
 --database) database="${2:?}"; shift 2;;
 *) usage; exit 2;;
 esac
done
[[ -f "$archive" && -f "$archive.sha256" && "$host" == 127.0.0.1 && "$port" =~ ^[0-9]+$ && "$database" =~ ^tris_restore_[a-zA-Z0-9_]+$ && "$role" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || { usage; exit 2; }
[[ "$port" != 5433 && "$port" != 5434 ]] || { echo "Refusing known production-development ports 5433 and 5434" >&2; exit 2; }
command -v brew >/dev/null || exit 1
prefix="$(brew --prefix postgresql@16)"
for bin in pg_restore createdb psql; do [[ -x "$prefix/bin/$bin" ]] || { echo "Missing $bin" >&2; exit 1; }; done
bash "$(dirname "$0")/verify-postgres-backup.sh" "$archive"
# Fail closed if any database with the chosen name already exists.
exists="$(PGCONNECT_TIMEOUT=5 "$prefix/bin/psql" -X -A -t -v ON_ERROR_STOP=1 -h "$host" -p "$port" -U "$role" -d postgres -v dbname="$database" -c "SELECT 1 FROM pg_database WHERE datname = :'dbname'")"
[[ -z "$exists" ]] || { echo "Database name already exists; nothing changed" >&2; exit 1; }
echo "About to create and restore a new test database: $database on $host:$port"
echo "This script will NOT delete the restored database; inspect it and remove it manually later."
"$prefix/bin/createdb" -h "$host" -p "$port" -U "$role" "$database"
echo "Disposable database created."
"$prefix/bin/pg_restore" --exit-on-error --no-owner --no-acl -h "$host" -p "$port" -U "$role" -d "$database" "$archive"
echo "Restore completed. Review schema, row counts, roles, extensions, and application API queries before cutover."
