#!/usr/bin/env bash
set -euo pipefail

# Convenience forwarder to build_dmg.sh
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$ROOT_DIR/script/build_dmg.sh" "$@"
