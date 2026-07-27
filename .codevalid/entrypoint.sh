#!/usr/bin/env bash
set -euo pipefail
if [[ -n "${WAIT_FOR_TCP:-}" ]]; then
  host="${WAIT_FOR_TCP%%:*}"
  port="${WAIT_FOR_TCP##*:}"
  echo "Waiting for $host:$port"
  for i in $(seq 1 60); do
    if nc -z "$host" "$port" 2>/dev/null; then break; fi
    sleep 1
  done
fi
exec "$@"
