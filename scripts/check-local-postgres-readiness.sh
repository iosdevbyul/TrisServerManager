#!/bin/bash
# Read-only, cluster-scoped readiness inspection before Docker-free cutover.
set -euo pipefail
usage() {
  echo "Usage: $0 --data-dir EXISTING_CLUSTER_DIR --port PORT" >&2
}
directory="" ; port=""
while (($#)); do
  case "$1" in
    --data-dir) [[ $# -ge 2 ]] || { usage; exit 2; }; directory="$2"; shift 2 ;;
    --port) [[ $# -ge 2 ]] || { usage; exit 2; }; port="$2"; shift 2 ;;
    *) usage; exit 2 ;;
  esac
done
[[ -n "$directory" && -d "$directory" && -f "$directory/PG_VERSION" ]] || {
  echo "An existing initialized PostgreSQL data directory is required." >&2; exit 2;
}
[[ "$port" =~ ^[1-9][0-9]*$ ]] && ((port <= 65535)) || { usage; exit 2; }
[[ "$(cat "$directory/PG_VERSION")" == 16 ]] || {
  echo "Expected PostgreSQL 16 cluster; refusing to inspect with a different major version." >&2; exit 2;
}
command -v brew >/dev/null || { echo "Homebrew CLI unavailable." >&2; exit 1; }
prefix="$(brew --prefix postgresql@16)"
pgctl="$prefix/bin/pg_ctl"
pgready="$prefix/bin/pg_isready"
[[ -x "$pgctl" && -x "$pgready" ]] || { echo "PostgreSQL 16 tools missing." >&2; exit 1; }
printf 'Cluster: %s\nExpected port: %s\n' "$directory" "$port"
if "$pgctl" -D "$directory" status; then
  echo "Cluster process: running"
else
  echo "Cluster process: not running or status unavailable"
  echo "Do not switch application connection settings yet."
  exit 1
fi
# pg_isready is a reachability probe only, not proof of cluster identity.
if "$pgready" -h 127.0.0.1 -p "$port"; then
  echo "TCP endpoint: accepting connections"
else
  echo "TCP endpoint: unavailable"
  exit 1
fi
echo "CAUTION: This does not verify that the TCP listener belongs to the chosen cluster."
echo "Before migration, independently verify cluster identity, roles, schema, rows, and application API health."
echo "No containers, database data, or processes were changed."
