#!/usr/bin/env bash
# =============================================================================
# Load a Docker Compose-style env file without printing its contents, then exec.
# Usage:
#   scripts/with-env.sh .env.local command arg1 arg2
# =============================================================================

set -euo pipefail

if [ "$#" -lt 2 ]; then
    echo "Usage: scripts/with-env.sh <env-file> <command> [args...]" >&2
    exit 2
fi

env_file="$1"
shift

if [ ! -f "$env_file" ]; then
    echo "Environment file not found: $env_file" >&2
    exit 1
fi

eval "$(
    python3 - "$env_file" <<'PY'
from pathlib import Path
import re
import shlex
import sys

env_path = Path(sys.argv[1])
name_pattern = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")

for raw_line in env_path.read_text(encoding="utf-8").splitlines():
    stripped = raw_line.strip()
    if not stripped or stripped.startswith("#"):
        continue
    if stripped.startswith("export "):
        stripped = stripped[len("export "):].lstrip()
    if "=" not in stripped:
        raise SystemExit(f"Invalid env entry in {env_path}: {raw_line}")
    key, value = stripped.split("=", 1)
    key = key.strip()
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
        value = value[1:-1]
    if not name_pattern.match(key):
        raise SystemExit(f"Invalid env var name in {env_path}: {key}")
    print(f"export {key}={shlex.quote(value)}")
PY
)"

exec "$@"
