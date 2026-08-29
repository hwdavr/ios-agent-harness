#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CHECKER="$PROJECT_ROOT/harness/scripts/check-localization-rules.sh"
REGRESSION="$PROJECT_ROOT/docs/current/reproduction/localization-rules-regression-test.sh"

if ! bash "$REGRESSION"; then
    echo "RED: localization regression fixture did not report its intentional violations."
    exit 1
fi

if ! bash "$CHECKER" >/dev/null; then
    echo "RED: production localization catalog or source failed the localization contract."
    exit 1
fi

echo "GREEN: localization checker contract passed for invalid and production fixtures."
