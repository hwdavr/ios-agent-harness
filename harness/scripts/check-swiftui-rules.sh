#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${IOS_HARNESS_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
if [[ ! -d "$PROJECT_ROOT/NotesTakingAppiOS" && -d "$PROJECT_ROOT/../NotesTakingAppiOS" ]]; then
    PROJECT_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"
fi

checker_arguments=()
if [[ "${1:-}" == "--all" ]]; then
    checker_arguments+=(--all)
    shift
fi
SOURCE_ROOT="${1:-$PROJECT_ROOT/NotesTakingAppiOS}"
REGISTRY="${DOCUMENTED_DYNAMIC_ACCESSIBILITY_IDS_REGISTRY:-$PROJECT_ROOT/harness/rules-matrix/documented-dynamic-accessibility-identifiers.json}"

if [[ "${checker_arguments[*]:-}" == "--all" ]]; then
    exec "$PROJECT_ROOT/harness/scripts/run-ast-checker.sh" swiftui \
        --project-root "$PROJECT_ROOT" \
        --source-root "$SOURCE_ROOT" \
        --registry "$REGISTRY" \
        --all
fi

exec "$PROJECT_ROOT/harness/scripts/run-ast-checker.sh" swiftui \
    --project-root "$PROJECT_ROOT" \
    --source-root "$SOURCE_ROOT" \
    --registry "$REGISTRY"
