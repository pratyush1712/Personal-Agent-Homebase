#!/usr/bin/env bash
# =============================================================================
# Render an Oh-My-OpenAgent config for local or remote LiteLLM routing.
#
# This script never reads .env files. Pass values as flags or make variables.
# =============================================================================

set -euo pipefail

usage() {
    cat <<'USAGE'
Usage:
  scripts/render-openagent-config.sh --mode local
  scripts/render-openagent-config.sh --mode remote --domain example.com
  scripts/render-openagent-config.sh --base-url https://litellm.example.com/v1 --output .generated/openagent.remote.jsonc

Options:
  --mode local|remote       Select a default base URL. Defaults to local.
  --base-url URL            Explicit LiteLLM OpenAI-compatible base URL.
  --domain DOMAIN           Domain used for remote mode. Defaults to pratyushsudhakar.com.
  --key KEY                 LiteLLM key to embed. Defaults to the placeholder sk-litellm-master.
  --source PATH             Source JSONC file. Defaults to oh-my-openagent.jsonc.
  --output PATH             Output file. Defaults to .generated/oh-my-openagent.<mode>.jsonc.
  -h, --help                Show this help.
USAGE
}

mode="local"
domain="pratyushsudhakar.com"
base_url=""
key="sk-litellm-master"
source_path="oh-my-openagent.jsonc"
output_path=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --mode)
            mode="${2:?--mode requires local or remote}"
            shift 2
            ;;
        --base-url)
            base_url="${2:?--base-url requires a URL}"
            shift 2
            ;;
        --domain)
            domain="${2:?--domain requires a domain}"
            shift 2
            ;;
        --key)
            key="${2:?--key requires a LiteLLM key}"
            shift 2
            ;;
        --source)
            source_path="${2:?--source requires a path}"
            shift 2
            ;;
        --output)
            output_path="${2:?--output requires a path}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

case "$mode" in
    local)
        default_base_url="http://localhost:4000/v1"
        ;;
    remote)
        default_base_url="https://litellm.${domain}/v1"
        ;;
    *)
        echo "--mode must be local or remote" >&2
        exit 2
        ;;
esac

if [ -z "$base_url" ]; then
    base_url="$default_base_url"
fi

if [ -z "$output_path" ]; then
    output_path=".generated/oh-my-openagent.${mode}.jsonc"
fi

python3 - "$source_path" "$output_path" "$base_url" "$key" <<'PY'
from pathlib import Path
import sys

source_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
base_url = sys.argv[3].rstrip("/")
key = sys.argv[4]

if not source_path.exists():
    raise SystemExit(f"Source config not found: {source_path}")

if not base_url.startswith(("http://", "https://")):
    raise SystemExit("--base-url must start with http:// or https://")

if "||" in base_url:
    raise SystemExit("--base-url must not include Oh-My-OpenAgent model separators")

source = source_path.read_text(encoding="utf-8")
rendered = source.replace("http://localhost:4000/v1", base_url)
rendered = rendered.replace("sk-litellm-master", key)

output_path.parent.mkdir(parents=True, exist_ok=True)
output_path.write_text(rendered, encoding="utf-8")
print(f"Rendered {output_path} with base URL {base_url}")
PY
