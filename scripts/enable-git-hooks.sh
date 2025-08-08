#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="$ROOT_DIR/.githooks"

if [ ! -d "$HOOKS_DIR" ]; then
  echo "❌ .githooks directory not found"
  exit 1
fi

git config core.hooksPath .githooks
chmod +x "$HOOKS_DIR"/* || true
echo "✅ Git hooks enabled (core.hooksPath=.githooks)"

