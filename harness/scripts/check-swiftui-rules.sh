#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${IOS_HARNESS_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
if [[ ! -d "$PROJECT_ROOT/NotesTakingAppiOS" && -d "$PROJECT_ROOT/../NotesTakingAppiOS" ]]; then
    PROJECT_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"
fi

checker_arguments=()
explicit_source_root=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --project-root)
            PROJECT_ROOT="$2"
            shift 2
            ;;
        --all)
            checker_arguments+=(--all)
            shift
            ;;
        -*)
            shift
            ;;
        *)
            explicit_source_root="$1"
            shift
            ;;
    esac
done

SOURCE_ROOT="${explicit_source_root:-${SWIFTUI_SOURCE_ROOT:-$PROJECT_ROOT/NotesTakingAppiOS}}"
REGISTRY="${DOCUMENTED_DYNAMIC_ACCESSIBILITY_IDS_REGISTRY:-$PROJECT_ROOT/docs/harness/documented-dynamic-accessibility-identifiers.json}"

exec "$PROJECT_ROOT/harness/scripts/run-ast-checker.sh" swiftui \
    --project-root "$PROJECT_ROOT" \
    --source-root "$SOURCE_ROOT" \
    --registry "$REGISTRY" \
    "${checker_arguments[@]}"
