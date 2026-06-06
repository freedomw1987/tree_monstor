#!/usr/bin/env bash
# setup_gitignore.sh — Add dev-task-memory gitignore snippet to project's .gitignore.
#
# Usage:
#   bash setup_gitignore.sh <project_path>
#   bash setup_gitignore.sh ~/www/crm-system

set -e

PROJECT="${1:-$(pwd)}"
GITIGNORE="$PROJECT/.gitignore"

if [ ! -d "$PROJECT" ]; then
    echo "❌ Project directory not found: $PROJECT"
    exit 1
fi

SNIPPET="# dev-task-memory — runtime state, not source
docs/_meta/
dev-task-state.md"

if [ -f "$GITIGNORE" ]; then
    if grep -q "dev-task-memory" "$GITIGNORE"; then
        echo "✅ Already in .gitignore: $GITIGNORE"
    else
        echo "" >> "$GITIGNORE"
        echo "$SNIPPET" >> "$GITIGNORE"
        echo "✅ Added to $GITIGNORE"
    fi
else
    echo "$SNIPPET" > "$GITIGNORE"
    echo "✅ Created $GITIGNORE"
fi
