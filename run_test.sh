#!/usr/bin/env bash
set -euo pipefail

echo "🔧 pre-commit: cleaning previous env..."
pre-commit clean

echo "🧪 Validating .pre-commit-config.yaml..."
pre-commit validate-config

echo "📦 Installing hooks..."
pre-commit install --install-hooks

echo "🏃 Running hooks on all files..."
# --show-diff-on-failure: muestra difs que causan fallo
# --color always: colores en CI
pre-commit run --all-files --show-diff-on-failure --color always

echo "✅ All pre-commit hooks passed."

