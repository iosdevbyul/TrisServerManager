#!/bin/bash
# Read-only prerequisite and conflict inspection for a Docker-to-Homebrew PostgreSQL 16 migration.
# Does not install packages, create clusters, dump data, print credentials, or stop services.
set -u

say() { printf '\n== %s ==\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }
print_port() {
  local port="$1"
  printf 'Port %s: ' "$port"
  if have lsof; then
    local listeners
    listeners="$(lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null || true)"
    if [ -n "$listeners" ]; then
      printf 'IN USE (PID(s): %s)\n' "$(printf '%s' "$listeners" | tr '\n' ' ')"
    else
      printf 'no TCP listener detected\n'
    fi
  else
    printf 'not checked (lsof missing)\n'
  fi
}

say 'System'
uname -sm
say 'Homebrew'
if have brew; then
  brew --prefix
  if brew list --versions postgresql@16 2>/dev/null; then
    printf 'postgresql@16 installed\n'
  else
    printf 'postgresql@16 is not installed; install manually after reviewing backups\n'
  fi
  prefix="$(brew --prefix postgresql@16 2>/dev/null || true)"
  if [ -n "$prefix" ] && [ -x "$prefix/bin/pg_ctl" ]; then
    "$prefix/bin/pg_ctl" --version
  fi
else
  printf 'Homebrew is not installed or unavailable in PATH\n'
fi

say 'Known PostgreSQL ports'
print_port 5432
print_port 5433
print_port 5434

say 'Docker containers (read-only)'
if have docker && docker info >/dev/null 2>&1; then
  docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}' || true
  printf '\nDocker volumes are intentionally NOT modified or removed.\n'
else
  printf 'Docker engine unavailable; existing database data has not been inspected.\n'
fi

say 'Next steps'
printf '%s\n' \
  '1. Confirm which Compose projects and PostgreSQL roles/databases own your data.' \
  '2. Take verified backups before initializing or restoring any native clusters.' \
  '3. Use isolated, separate PostgreSQL 16 data directories.' \
  '4. Restore into a temporary cluster and validate before changing API DATABASE_URL.' \
  '5. Keep Docker containers and volumes for rollback until explicitly approved.'
