#!/usr/bin/env bash
# =============================================================================
# check-swiftui-rules.sh
#
# Checks SwiftUI source files for violations of swiftui-rules.md.
#
# Usage: ./harness/scripts/check-swiftui-rules.sh [--all]
# Exit: 0 (no violations), 1 (violations found)
# =============================================================================

set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCE_ROOT="$PROJECT_ROOT/NotesTakingAppiOS"

SCAN_ALL=false
[[ "${1:-}" == "--all" ]] && SCAN_ALL=true

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

_search() { rg --color never -n "$1" "${2:-$SOURCE_ROOT}" 2>/dev/null || true; }

_run_check() {
    local rule="$1" pattern="$2" dir="${3:-}"
    echo -e "  ${CYAN}Rule: $rule${RESET}"
    local results
    if [[ -n "$dir" && -d "$SOURCE_ROOT/$dir" ]]; then
        results=$(_search "$pattern" "$SOURCE_ROOT/$dir")
    else
        results=$(_search "$pattern")
    fi
    if [[ -z "$results" ]]; then
        echo -e "    ${GREEN}✓ No violations${RESET}"
    else
        while IFS= read -r line; do
            [[ -n "$line" ]] && echo -e "    ${RED}$line${RESET}" && ((TOTAL_VIOLATIONS++))
        done <<< "$results"
    fi
}

echo -e "\n${BOLD}=== SwiftUI Rules Checker ===${RESET}"
echo -e "  Files: ${#swift_files[@]}\n"

# 1. Hardcoded colors — Color(hex:), Color(red:, Color.white, .red etc.
_run_check "Hardcoded Color literal" \
    'Color\(hex:\s*\"0x[0-9A-Fa-f]|Color\(red:|\.red\)|Color\.red|\.blue\)|Color\.blue|\.green\)|Color\.green'

# 2. Missing accessibilityIdentifier on interactive elements
no_id_files=()
for f in "${swift_files[@]}"; do
    [[ "$f" == "$SOURCE_ROOT/Views/"* ]] || continue
    if rg -q '\b(Button|TextField|Toggle|Picker|Stepper|Slider|SecureField|TextEditor|List)\b' "$f" 2>/dev/null; then
        if ! rg -q 'accessibilityIdentifier' "$f" 2>/dev/null; then
            no_id_files+=("$f")
        fi
    fi
done
echo -e "  ${CYAN}Rule: Interactive elements missing accessibilityIdentifier${RESET}"
if [[ ${#no_id_files[@]} -eq 0 ]]; then
    echo -e "    ${GREEN}✓ No violations${RESET}"
else
    for f in "${no_id_files[@]}"; do
        echo -e "    ${RED}${f#$PROJECT_ROOT/}${RESET}"
        ((TOTAL_VIOLATIONS++))
    done
fi

# 3. Harcoded strings in Views (Text with string literal that isn't a localization key)
_run_check "Hardcoded string in Text()" 'Text\("[A-Z][a-z]' "Views"

# 4. ViewModel calls on the same line as a stateless content declaration.
# A bare @ViewBuilder is a normal SwiftUI composition tool and is not itself
# evidence that a content view owns business state.
_run_check "Content View calling ViewModel directly" \
    'struct[[:space:]]+[A-Za-z0-9_]*Content[^:]*:[[:space:]]*View.*viewModel\.' "Views"

# 5. VStack with ForEach for large lists (should be List/LazyVStack)
_run_check "VStack with ForEach (use List or LazyVStack)" \
    'VStack\s*\{[^}]*ForEach'

echo ""
if [[ $TOTAL_VIOLATIONS -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}✓ All SwiftUI rules passed${RESET}\n"
    exit 0
else
    echo -e "${RED}${BOLD}✗ $TOTAL_VIOLATIONS violation(s) found${RESET}\n"
    exit 1
fi
