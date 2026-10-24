#!/bin/bash
set -euo pipefail
[[ $# == 1 && -f "$1" && -f "$1.sha256" ]] || { echo "Usage: $0 BACKUP.dump" >&2; exit 2; }
archive="$1"
dir="$(cd "$(dirname "$archive")" && pwd -P)"
name="$(basename "$archive")"
(cd "$dir" && shasum -a 256 -c "$name.sha256")
if command -v brew >/dev/null && prefix="$(brew --prefix postgresql@16 2>/dev/null)" && [[ -x "$prefix/bin/pg_restore" ]]; then
  "$prefix/bin/pg_restore" --list "$archive" >/dev/null
elif command -v pg_restore >/dev/null; then
  pg_restore --list "$archive" >/dev/null
else
  echo "pg_restore missing; cannot validate archive" >&2; exit 1
fi
echo "Archive checksum and table of contents verified. A full isolated restore remains necessary."
