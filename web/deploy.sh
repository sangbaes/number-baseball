#!/usr/bin/env bash
# Copy the game's web source into the sinbiroum-web hosting repo,
# then run `firebase deploy --only hosting:sinbiroum-v1` from there.
#
# Usage:
#   ./web/deploy.sh           # copy only (dry run for deploy)
#   ./web/deploy.sh --deploy  # copy and deploy
#
# Layout assumption:
#   number-baseball/  (this repo)  →  src files at web/src/
#   sinbiroum-web/    (sibling)    →  target at public/baseball/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
HOSTING_REPO="$(cd "$SCRIPT_DIR/../.." && pwd)/sinbiroum-web"
TARGET_DIR="$HOSTING_REPO/public/baseball"

if [[ ! -d "$HOSTING_REPO" ]]; then
    echo "❌ hosting repo not found at: $HOSTING_REPO"
    exit 1
fi

if [[ ! -d "$SRC_DIR" ]]; then
    echo "❌ source dir not found at: $SRC_DIR"
    exit 1
fi

echo "📦 syncing $SRC_DIR → $TARGET_DIR"
mkdir -p "$TARGET_DIR"
# --delete prunes files that no longer exist in src.
rsync -av --delete \
    --exclude=".DS_Store" \
    "$SRC_DIR/" "$TARGET_DIR/"

echo "✅ copy complete."

if [[ "${1:-}" == "--deploy" ]]; then
    echo "🚀 deploying hosting:sinbiroum-v1"
    cd "$HOSTING_REPO"
    firebase deploy --only hosting:sinbiroum-v1
else
    echo "ℹ️  pass --deploy to publish: $0 --deploy"
fi
