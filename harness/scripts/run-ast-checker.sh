#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${IOS_HARNESS_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
if [[ ! -d "$PROJECT_ROOT/NotesTakingAppiOS" && -d "$PROJECT_ROOT/../NotesTakingAppiOS" ]]; then
    PROJECT_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"
fi

PACKAGE_DIR="$PROJECT_ROOT/harness/ast-checker"
if [[ ! -f "$PACKAGE_DIR/Package.swift" ]]; then
    echo "FAIL: AST checker package is missing: $PACKAGE_DIR" >&2
    exit 1
fi

exec swift run --package-path "$PACKAGE_DIR" ast-rule-checker "$@"
