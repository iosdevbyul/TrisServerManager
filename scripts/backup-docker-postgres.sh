#!/bin/bash
set -euo pipefail
# Non-destructive single-database backup from a PostgreSQL 16 Docker container.
if [[ $# != 4 ]]; then echo "Usage: $0 CONTAINER DATABASE ROLE OUTPUT_DIRECTORY" >&2; exit 2; fi
container="$1"; database="$2"; role="$3"; output="$4"
[[ "$container" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]] || exit 2
command -v docker >/dev/null || exit 1
[[ "$(docker inspect -f '{{.State.Running}}' "$container")" == true ]] || { echo "Container not running" >&2; exit 1; }
image="$(docker inspect -f '{{.Config.Image}}' "$container")"
[[ "$image" == postgres:16* || "$image" == */postgres:16* ]] || { echo "Expected PostgreSQL 16 image" >&2; exit 1; }
[[ ! -L "$output" ]] || { echo "Output directory must not be a symlink" >&2; exit 1; }
mkdir -p "$output"
chmod 700 "$output"
umask 077
archive="$output/$container-$(date -u +%Y%m%dT%H%M%SZ).dump"
[[ ! -e "$archive" ]] || exit 1
tmp="$(mktemp "$output/.pgbackup.XXXXXXXX")"
trap 'rm -f "$tmp"' EXIT
# Uses container-local authentication; secrets must not be passed in argv.
docker exec -i "$container" pg_dump -U "$role" -d "$database" -Fc --no-owner --no-acl > "$tmp"
[[ -s "$tmp" ]] || { echo "Empty dump" >&2; exit 1; }
mv "$tmp" "$archive"
trap - EXIT
shasum -a 256 "$archive" > "$archive.sha256"
echo "Backup stored at: $archive"
echo "This dump only covers one database; global roles and other databases are excluded."
