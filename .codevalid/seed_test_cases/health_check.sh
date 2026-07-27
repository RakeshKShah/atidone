#!/usr/bin/env bash
set -euo pipefail
HEALTH_URL="${HEALTH_URL:-http://localhost:6713/api/health}"
echo "Checking health at $HEALTH_URL"
curl -fsS "$HEALTH_URL"
echo
