#!/usr/bin/env bash
# =============================================================================
# check-navigation-rules.sh
#
# Checks Swift source files for violations of navigation-rules.md constraints.
#
# Usage:
#   ./harness/scripts/check-navigation-rules.sh
#   NAVIGATION_SOURCE_ROOT=/path/to/fixture \
#     ./harness/scripts/check-navigation-rules.sh
#
# Exit: 0 (no violations), 1 (violations found)
# =============================================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
if [[ ! -d "$PROJECT_ROOT/NotesTakingAppiOS" && -d "$PROJECT_ROOT/../NotesTakingAppiOS" ]]; then
    PROJECT_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"
fi
SOURCE_ROOT="${NAVIGATION_SOURCE_ROOT:-$PROJECT_ROOT/NotesTakingAppiOS}"
MAIN_VIEW="$SOURCE_ROOT/Views/Main/MainTabView.swift"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

TOTAL_VIOLATIONS=0
route_files=()

display_path() {
    local file="$1"
    case "$file" in
        "$PROJECT_ROOT"/*) echo "${file#$PROJECT_ROOT/}" ;;
        *) echo "$file" ;;
    esac
}

report_violation() {
    local location="$1"
    local message="$2"
    echo -e "    ${RED}${location}: ${message}${RESET}"
    TOTAL_VIOLATIONS=$((TOTAL_VIOLATIONS + 1))
}

search() {
    rg --color never --with-filename -n "$1" "$2" 2>/dev/null || true
}

collect_route_files() {
    [[ -d "$SOURCE_ROOT" ]] || return 0
    while IFS= read -r file; do
        [[ -n "$file" ]] && route_files+=("$file")
    done < <(find "$SOURCE_ROOT" -type f -name '*.swift' \( -iname '*Navigation*.swift' -o -iname '*Route*.swift' \) -print)
}

route_type_is_hashable() {
    local type="$1"
    type="${type//[[:space:]]/}"
    type="${type#@}"

    case "$type" in
        String|Int|Int8|Int16|Int32|Int64|UInt|UInt8|UInt16|UInt32|UInt64|Double|Float|Bool|UUID|Date|URL)
            return 0
            ;;
    esac

    if [[ -d "$SOURCE_ROOT" ]] && rg -q \
        "(enum|struct|class)[[:space:]]+$type([[:space:]:{]|$).*Hashable" \
        "$SOURCE_ROOT" --glob '*.swift' 2>/dev/null; then
        return 0
    fi

    return 1
}

function_contains_pattern() {
    local file="$1"
    local function_name="$2"
    local pattern="$3"

    awk -v function_name="$function_name" -v pattern="$pattern" '
        BEGIN { inside = 0; depth = 0; found = 0 }
        {
            if (!inside && $0 ~ "func[[:space:]]+" function_name "[[:space:]]*\\(") {
                inside = 1
            }

            if (inside) {
                if ($0 ~ pattern) {
                    found = 1
                }

                line = $0
                opening = gsub(/\{/, "", line)
                closing = gsub(/\}/, "", line)
                depth += opening - closing

                if (depth <= 0 && opening > 0) {
                    if (found) {
                        exit 0
                    }
                    inside = 0
                    depth = 0
                }
            }
        }
        END {
            if (found) {
                exit 0
            }
            exit 1
        }
    ' "$file"
}

navigation_has_default_value() {
    local file
    while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        if rg -q 'navigationDestination[[:space:]]*\([[:space:]]*for:' "$file" 2>/dev/null \
            && rg -q 'defaultValue' "$file" 2>/dev/null; then
            return 0
        fi
    done < <(find "$SOURCE_ROOT" -type f -name '*.swift' -print)
    return 1
}

check_main_navigation_container() {
    echo -e "  ${CYAN}Rule: root typed navigation container${RESET}"

    if [[ ! -f "$MAIN_VIEW" ]]; then
        report_violation "$(display_path "$MAIN_VIEW")" \
            "MainTabView.swift is required for the root navigation contract"
        return
    fi

    if ! rg -q 'NavigationStack|NavigationSplitView' "$MAIN_VIEW" 2>/dev/null; then
        local line
        line=$(rg -n 'struct[[:space:]]+MainTabView' "$MAIN_VIEW" 2>/dev/null | head -n 1)
        [[ -n "$line" ]] || line="1"
        report_violation "$(display_path "$MAIN_VIEW"):${line%%:*}" \
            "root screen must define NavigationStack or NavigationSplitView"
    fi

    if ! rg -q 'navigationDestination[[:space:]]*\([[:space:]]*for:' "$MAIN_VIEW" 2>/dev/null; then
        local line
        line=$(rg -n 'struct[[:space:]]+MainTabView' "$MAIN_VIEW" 2>/dev/null | head -n 1)
        [[ -n "$line" ]] || line="1"
        report_violation "$(display_path "$MAIN_VIEW"):${line%%:*}" \
            "root navigation must handle typed routes with navigationDestination(for:)"
    fi
}

check_conditional_destination_swaps() {
    echo -e "  ${CYAN}Rule: destination pushes use the back stack${RESET}"
    [[ -f "$MAIN_VIEW" ]] || return

    local results
    results=$(search \
        'if[[:space:]]+let[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*(viewModel\.)?(activeDestination|navigationDestination)' \
        "$MAIN_VIEW")

    if [[ -z "$results" ]]; then
        echo -e "    ${GREEN}✓ No conditional destination root swaps${RESET}"
        return
    fi

    while IFS= read -r record; do
        [[ -n "$record" ]] || continue
        local file="${record%%:*}"
        local rest="${record#*:}"
        local line="${rest%%:*}"
        report_violation "$(display_path "$file"):$line" \
            "do not conditionally replace the root with a destination; push a typed route onto the navigation stack"
    done <<< "$results"
}

check_legacy_navigation_links() {
    echo -e "  ${CYAN}Rule: typed navigation links${RESET}"
    [[ -d "$SOURCE_ROOT/Views" ]] || return

    local results
    results=$(search 'NavigationLink[[:space:]]*\([[:space:]]*destination[[:space:]]*:' "$SOURCE_ROOT/Views")
    if [[ -z "$results" ]]; then
        echo -e "    ${GREEN}✓ No untyped NavigationLink(destination:) calls${RESET}"
        return
    fi

    while IFS= read -r record; do
        [[ -n "$record" ]] || continue
        local file="${record%%:*}"
        local rest="${record#*:}"
        local line="${rest%%:*}"
        report_violation "$(display_path "$file"):$line" \
            "use NavigationLink(value:) with a Hashable route instead of NavigationLink(destination:)"
    done <<< "$results"
}

check_route_declarations() {
    echo -e "  ${CYAN}Rule: Hashable route definitions${RESET}"
    [[ ${#route_files[@]} -gt 0 ]] || return

    local file
    for file in "${route_files[@]}"; do
        local results
        results=$(search 'enum[[:space:]]+[A-Za-z_][A-Za-z0-9_]*(Route|Destination)([[:space:]:{]|$)' "$file")
        [[ -n "$results" ]] || continue

        while IFS= read -r record; do
            [[ -n "$record" ]] || continue
            local file_part="${record%%:*}"
            local rest="${record#*:}"
            local line="${rest%%:*}"
            local declaration="${rest#*:}"
            if ! printf '%s\n' "$declaration" | rg -q 'Hashable'; then
                report_violation "$(display_path "$file_part"):$line" \
                    "route/destination enums must conform to Hashable"
            fi
        done <<< "$results"
    done
}

check_route_arguments() {
    echo -e "  ${CYAN}Rule: minimal Hashable route arguments${RESET}"
    [[ ${#route_files[@]} -gt 0 ]] || return

    local file
    for file in "${route_files[@]}"; do
        local results
        results=$(search '^[[:space:]]*case[[:space:]]+[A-Za-z_][A-Za-z0-9_]*\([^)]*\)' "$file")
        [[ -n "$results" ]] || continue

        while IFS= read -r record; do
            [[ -n "$record" ]] || continue
            local file_part="${record%%:*}"
            local rest="${record#*:}"
            local line="${rest%%:*}"
            local source="${rest#*:}"
            local arguments="${source#*\(}"
            arguments="${arguments%\)}"

            local optional
            optional=$(printf '%s\n' "$arguments" | rg -o '[A-Za-z_][A-Za-z0-9_]*[[:space:]]*:[^,)]*\?' 2>/dev/null || true)
            if [[ -n "$optional" ]] && ! navigation_has_default_value; then
                report_violation "$(display_path "$file_part"):$line" \
                    "optional route arguments require an explicit defaultValue in the destination"
            fi

            local components
            IFS=',' read -ra components <<< "$arguments"
            local component
            for component in "${components[@]}"; do
                [[ "$component" == *:* ]] || continue
                local label="${component%%:*}"
                local type="${component#*:}"
                type="${type//[[:space:]]/}"
                type="${type//\?/}"
                type="${type//=/}"
                [[ -n "$type" ]] || continue

                if [[ "$type" =~ (Model|DTO|Entity)$ ]] || ! route_type_is_hashable "$type"; then
                    report_violation "$(display_path "$file_part"):$line" \
                        "route argument '$label' uses non-Hashable or complex type '$type'; pass an ID or scalar value"
                fi
            done
        done <<< "$results"
    done
}

check_view_model_navigation_state() {
    echo -e "  ${CYAN}Rule: ViewModel navigation state${RESET}"
    [[ -d "$SOURCE_ROOT/ViewModels" ]] || return

    local file
    while IFS= read -r file; do
        [[ -n "$file" ]] || continue

        local boolean_results
        boolean_results=$(search \
            'var[[:space:]]+(isShowing|showing|show)(Editor|Detail|Screen|Destination|View)\b' \
            "$file")
        while IFS= read -r record; do
            [[ -n "$record" ]] || continue
            local rest="${record#*:}"
            local line="${rest%%:*}"
            report_violation "$(display_path "$file"):$line" \
                "do not encode a navigation destination as a boolean ViewModel flag"
        done <<< "$boolean_results"

        local route_results
        route_results=$(search \
            'var[[:space:]]+(activeDestination|navigationPath|navigationRoute|currentRoute)\b' \
            "$file")
        while IFS= read -r record; do
            [[ -n "$record" ]] || continue
            local rest="${record#*:}"
            local line="${rest%%:*}"
            report_violation "$(display_path "$file"):$line" \
                "navigation destinations belong to the View stack/path, not persistent ViewModel route state"
        done <<< "$route_results"

        if [[ -n "$route_results" ]]; then
            local auth_function
            for auth_function in signOut handleSessionExpired; do
                local auth_line
                auth_line=$(rg -n "func[[:space:]]+$auth_function[[:space:]]*\\(" "$file" 2>/dev/null | head -n 1)
                [[ -n "$auth_line" ]] || continue
                local clear_pattern='activeDestination[[:space:]]*=[[:space:]]*nil|navigationPath[[:space:]]*=[[:space:]]*\[\]|navigationPath[[:space:]]*\.(removeLast|removeAll)'
                if ! function_contains_pattern "$file" "$auth_function" "$clear_pattern"; then
                    local auth_number="${auth_line%%:*}"
                    report_violation "$(display_path "$file"):$auth_number" \
                        "$auth_function auth exit path must clear the navigation route/path"
                fi
            done
        fi
    done < <(find "$SOURCE_ROOT/ViewModels" -type f -name '*.swift' -print)
}

echo -e "\n${BOLD}=== iOS Navigation Rules Checker ===${RESET}"
echo -e "  Source: $SOURCE_ROOT\n"

if [[ ! -d "$SOURCE_ROOT" ]]; then
    report_violation "$SOURCE_ROOT" "navigation source root does not exist"
else
    collect_route_files
    check_main_navigation_container
    check_conditional_destination_swaps
    check_legacy_navigation_links
    check_route_declarations
    check_route_arguments
    check_view_model_navigation_state
fi

echo ""
if [[ $TOTAL_VIOLATIONS -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}✓ All navigation rules passed${RESET}\n"
    exit 0
fi

echo -e "${RED}${BOLD}✗ $TOTAL_VIOLATIONS navigation violation(s) found${RESET}\n"
exit 1
