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
HARNESS_LOCATION="$(cd "$SCRIPT_DIR/../.." && pwd)"
if [[ -d "$HARNESS_LOCATION/.harness" && -d "$HARNESS_LOCATION/NotesTakingAppiOS" ]]; then
    PROJECT_ROOT="${IOS_HARNESS_PROJECT_ROOT:-$HARNESS_LOCATION}"
    HARNESS_ROOT="$HARNESS_LOCATION/.harness"
else
    HARNESS_ROOT="$HARNESS_LOCATION"
    PROJECT_ROOT="${IOS_HARNESS_PROJECT_ROOT:-$(cd "$HARNESS_ROOT/.." && pwd)}"
fi

SCAN_ALL=false
if [[ "${1:-}" == "--all" ]]; then
    SCAN_ALL=true
    shift
fi
SOURCE_ROOT="${1:-$PROJECT_ROOT/NotesTakingAppiOS}"
REGISTRY="${DOCUMENTED_DYNAMIC_ACCESSIBILITY_IDS_REGISTRY:-$PROJECT_ROOT/harness/rules-matrix/documented-dynamic-accessibility-identifiers.json}"

[[ -d "$SOURCE_ROOT" ]] || {
    echo "FAIL: SwiftUI source root does not exist: $SOURCE_ROOT" >&2
    exit 1
}

swift_files=()
if [[ "$SCAN_ALL" == "true" ]] || ! git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree &>/dev/null; then
    while IFS= read -r f; do swift_files+=("$f"); done < <(find "$SOURCE_ROOT" -name "*.swift" -type f)
else
    while IFS= read -r f; do swift_files+=("$f"); done < <(
        { git -C "$PROJECT_ROOT" diff --name-only --diff-filter=d HEAD; git -C "$PROJECT_ROOT" diff --name-only --cached --diff-filter=d; git -C "$PROJECT_ROOT" ls-files --others --exclude-standard; } 2>/dev/null \
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

validate_identifier_registry() {
    [[ -f "$REGISTRY" ]] || {
        echo -e "    ${RED}Missing documented dynamic accessibility-identifier registry: $REGISTRY${RESET}"
        return 1
    }
    command -v jq >/dev/null 2>&1 || {
        echo -e "    ${RED}jq is required to validate the dynamic accessibility-identifier registry${RESET}"
        return 1
    }
    if ! jq -e '
        type == "object" and
        (.entries | type == "array" and length > 0) and
        all(
            .entries[];
            (.id | type == "string" and length > 0) and
            (.file | type == "string" and length > 0) and
            (.documentation | type == "string" and length > 0) and
            (.template | type == "string" and length > 0) and
            (.source_type | IN("immutable-domain-id", "fixed-catalog-key", "immutable-screen-prefix")) and
            (.line_pattern | type == "string" and length > 0)
        )
    ' "$REGISTRY" >/dev/null 2>&1; then
        echo -e "    ${RED}Invalid dynamic accessibility-identifier registry: $REGISTRY${RESET}"
        return 1
    fi

    local entry_id entry_file documentation template
    while IFS=$'\t' read -r entry_id entry_file documentation template; do
        [[ -n "$entry_id" ]] || continue
        [[ -f "$PROJECT_ROOT/$entry_file" ]] || {
            echo -e "    ${RED}Registry entry $entry_id references missing source file: $entry_file${RESET}"
            return 1
        }
        [[ "$documentation" != /* && "$documentation" != *..* ]] || {
            echo -e "    ${RED}Registry entry $entry_id has an unsafe documentation path: $documentation${RESET}"
            return 1
        }
        [[ -f "$PROJECT_ROOT/$documentation" ]] || {
            echo -e "    ${RED}Registry entry $entry_id references missing documentation: $documentation${RESET}"
            return 1
        }
        grep -Fq "$template" "$PROJECT_ROOT/$documentation" || {
            echo -e "    ${RED}Registry entry $entry_id is not documented by template '$template' in $documentation${RESET}"
            return 1
        }
    done < <(jq -r '.entries[] | [.id, .file, .documentation, .template] | @tsv' "$REGISTRY")
}

is_documented_dynamic_identifier() {
    local relative_file="$1"
    local source_line="$2"
    jq -e --arg file "$relative_file" --arg line "$source_line" '
        .entries[]
        | select(.file == $file)
        | select(.line_pattern as $pattern | $line | test($pattern))
    ' "$REGISTRY" >/dev/null 2>&1
}

_rule_header() {
    echo -e "  ${CYAN}Rule: $1${RESET}"
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

_rule_header "Dynamic accessibilityIdentifier expressions must be registry-backed and documented"
if ! validate_identifier_registry; then
    ((TOTAL_VIOLATIONS++))
else
    dynamic_identifier_violations=0
    for f in "${swift_files[@]}"; do
        relative_file="${f#$PROJECT_ROOT/}"
        dynamic_lines=$(awk '
            function reset() { in_call = 0; start = 0 }
            !in_call && $0 ~ /accessibilityIdentifier[[:space:]]*\(/ { in_call = 1; start = NR }
            in_call {
                if ($0 ~ /\\\(/) {
                    print start ":" $0
                    reset()
                    next
                }
                if ($0 ~ /\)[[:space:]]*$/) reset()
            }
        ' "$f")
        while IFS= read -r dynamic_line; do
            [[ -n "$dynamic_line" ]] || continue
            line_number="${dynamic_line%%:*}"
            source_line="${dynamic_line#*:}"
            if ! is_documented_dynamic_identifier "$relative_file" "$source_line"; then
                echo -e "    ${RED}${relative_file}:${line_number}: dynamic accessibilityIdentifier is not an approved documented immutable identifier: ${source_line}${RESET}"
                ((TOTAL_VIOLATIONS++))
                ((dynamic_identifier_violations++))
            fi
        done <<< "$dynamic_lines"
    done
    if [[ "$dynamic_identifier_violations" -eq 0 ]]; then
        echo -e "    ${GREEN}✓ All dynamic accessibilityIdentifiers are documented immutable identifiers${RESET}"
    fi
fi

echo ""
if [[ $TOTAL_VIOLATIONS -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}✓ All SwiftUI rules passed${RESET}\n"
    exit 0
else
    echo -e "${RED}${BOLD}✗ $TOTAL_VIOLATIONS violation(s) found${RESET}\n"
    exit 1
fi
