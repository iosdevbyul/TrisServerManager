#!/bin/bash
# Explicit opt-in creation of an isolated PostgreSQL 16 data cluster.
# Does not start the cluster, manage brew services, migrate data, or touch Docker.
set -euo pipefail

usage() {
  echo "Usage: $0 --data-dir ABSOLUTE_PATH --port 5433|5434 --create"
  echo "Requires Homebrew postgresql@16. Only creates a NEW, nonexistent directory."
}

data_dir="" ; port="" ; create=false
while (($#)); do
  case "$1" in
    --data-dir) [[ $# -ge 2 ]] || { usage; exit 2; }; data_dir="$2"; shift 2 ;;
    --port) [[ $# -ge 2 ]] || { usage; exit 2; }; port="$2"; shift 2 ;;
    --create) create=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done

[[ "$create" == true ]] || { echo "Refusing: --create must be explicitly provided." >&2; exit 2; }
[[ "$data_dir" = /* && "$data_dir" != "/" && "$data_dir" != *"/../"* && "$data_dir" != *"/./"* ]] || {
  echo "Require a safe absolute data directory path." >&2; exit 2;
}
[[ "$port" =~ ^[0-9]+$ ]] && ((10#$port >= 1 && 10#$port <= 65535)) || {
  echo "Port must be an integer from 1 to 65535." >&2; exit 2;
}
[[ ! -e "$data_dir" && ! -L "$data_dir" ]] || {
  echo "Refusing: data directory already exists: $data_dir" >&2; exit 2;
}
command -v brew >/dev/null || { echo "Homebrew missing. Install it separately." >&2; exit 1; }
prefix="$(brew --prefix postgresql@16)"
initdb="$prefix/bin/initdb"
[[ -x "$initdb" ]] || { echo "PostgreSQL 16 initdb missing." >&2; exit 1; }
if command -v lsof >/dev/null && lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null | grep -q .; then
  echo "Port $port is currently occupied. Stop or choose another port first." >&2; exit 1;
fi
mkdir -p "$(dirname "$data_dir")"
# initdb securely prompts for a password; it is not passed through CLI or stored here.
"$initdb" -D "$data_dir" -A scram-sha-256 -W
echo "Created isolated PostgreSQL 16 cluster at $data_dir"
echo "Keep the password entered at the initdb prompt in your preferred password manager."
echo "No service was started and no existing database was changed."
