#!/usr/bin/env bash
# =============================================================================
# check-architecture-rules.sh
#
# Checks Swift source files for violations of ios-architecture.md constraints.
#
# Usage: ./harness/scripts/check-architecture-rules.sh [--all]
# Exit: 0 (no violations), 1 (violations found)
# =============================================================================

set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCE_ROOT="$PROJECT_ROOT/NotesTakingAppiOS"

SCAN_ALL=false
[[ "${1:-}" == "--all" ]] && SCAN_ALL=true

# Collect Swift files
swift_files=()
if [[ "$SCAN_ALL" == "true" ]] || ! git rev-parse --is-inside-work-tree &>/dev/null; then
    while IFS= read -r f; do swift_files+=("$f"); done < <(find "$SOURCE_ROOT" -name "*.swift" -type f)
else
    while IFS= read -r f; do swift_files+=("$f"); done < <(
        { git diff --name-only --diff-filter=d HEAD; git diff --name-only --cached --diff-filter=d; git ls-files --others --exclude-standard; } 2>/dev/null \
        | grep '\.swift$' | sort -u | sed "s|^|$PROJECT_ROOT/|" | grep "^$SOURCE_ROOT/"
    )
    [[ ${#swift_files[@]} -eq 0 ]] && while IFS= read -r f; do swift_files+=("$f"); done < <(find "$SOURCE_ROOT" -name "*.swift" -type f)
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
TOTAL_VIOLATIONS=0

_search() { rg --color never -n "$1" "$2" 2>/dev/null || true; }

_run_check() {
    local rule="$1" pattern="$2" dir="$3"
    echo -e "  ${CYAN}Rule: $rule${RESET}"
    local results
    if [[ -n "$dir" && -d "$SOURCE_ROOT/$dir" ]]; then
        results=$(_search "$pattern" "$SOURCE_ROOT/$dir")
    else
        results=$(_search "$pattern" "$SOURCE_ROOT")
    fi
    if [[ -z "$results" ]]; then
        echo -e "    ${GREEN}✓ No violations${RESET}"
    else
        while IFS= read -r line; do
            [[ -n "$line" ]] && echo -e "    ${RED}$line${RESET}" && ((TOTAL_VIOLATIONS++))
        done <<< "$results"
    fi
}

echo -e "\n${BOLD}=== iOS Architecture Rules Checker ===${RESET}"
echo -e "  Files: ${#swift_files[@]}\n"

# 1. Views importing data layer
_run_check "SwiftUI View importing Data layer types" 'import.*Data|URLSession' "Views"

# 2. ViewModels importing URLSession directly
for f in "${swift_files[@]}"; do
    if echo "$f" | grep -qi 'ViewModel' && rg -q 'URLSession' "$f" 2>/dev/null; then
        echo -e "    ${RED}${f#$PROJECT_ROOT/}: ViewModel imports URLSession directly${RESET}"
        ((TOTAL_VIOLATIONS++))
    fi
done

# 3. Domain layer importing SwiftUI/UIKit
_run_check "Domain file importing SwiftUI" 'import SwiftUI|import UIKit' "Domain"

# 4. Data layer exposing DTOs (structs with Codable) outside data layer
_run_check "DTO (Codable) used in ViewModel layer" 'import.*Data.*\n.*Codable' ""

# 5. Business logic in Views (fatalError, switch on domain types)
_run_check "Business logic in View body" '@ViewBuilder.*func body.*switch.*status|func body.*\.isEnabled' "Views"

# 6. Check for DTOs referenced from ViewModel files
for f in "${swift_files[@]}"; do
    if echo "$f" | grep -qi 'ViewModel\.swift$' && rg -q 'Codable' "$f" 2>/dev/null; then
        echo -e "    ${RED}${f#$PROJECT_ROOT/}: ViewModel likely references DTO (Codable)${RESET}"
        ((TOTAL_VIOLATIONS++))
    fi
done

echo ""
if [[ $TOTAL_VIOLATIONS -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}✓ All architecture rules passed${RESET}\n"
    exit 0
else
    echo -e "${RED}${BOLD}✗ $TOTAL_VIOLATIONS violation(s) found${RESET}\n"
    exit 1
fi