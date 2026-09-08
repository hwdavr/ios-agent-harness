#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${IOS_HARNESS_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
if [[ ! -d "$PROJECT_ROOT/NotesTakingAppiOS" && -d "$PROJECT_ROOT/../NotesTakingAppiOS" ]]; then
    PROJECT_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project-root)
            PROJECT_ROOT="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

SOURCE_ROOT="${LOCALIZATION_SOURCE_ROOT:-$PROJECT_ROOT/NotesTakingAppiOS}"

exec "$PROJECT_ROOT/harness/scripts/run-ast-checker.sh" localization \
    --project-root "$PROJECT_ROOT" \
    --source-root "$SOURCE_ROOT" \
    --all
