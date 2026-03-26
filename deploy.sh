#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "== [1/5] storage"
bash "$SCRIPT_DIR/storage/deploy.sh"

echo "== [2/5] bigquery"
bash "$SCRIPT_DIR/bigquery/deploy.sh"

echo "== [3/5] pubsub"
bash "$SCRIPT_DIR/pubsub/deploy.sh"

echo "== [4/5] workflows"
bash "$SCRIPT_DIR/workflows/deploy.sh"

echo "== [5/5] function"
(cd "$SCRIPT_DIR/function" && bash deploy.sh)

echo ""
echo "Done."
