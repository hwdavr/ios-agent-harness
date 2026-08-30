#!/usr/bin/env bash
# =============================================================================
# check-localization-rules.sh
#
# Checks production Swift source and the Xcode String Catalog for localization
# rule violations.
#
# Usage:
#   ./harness/scripts/check-localization-rules.sh
#   LOCALIZATION_SOURCE_ROOT=/path/to/fixture \
#     ./harness/scripts/check-localization-rules.sh
# =============================================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCE_ROOT="${LOCALIZATION_SOURCE_ROOT:-$PROJECT_ROOT/NotesTakingAppiOS}"
CATALOG="$SOURCE_ROOT/Localizable.xcstrings"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

TOTAL_VIOLATIONS=0
CATALOG_VALID=false

report_violation() {
    local location="$1"
    local message="$2"
    echo -e "    ${RED}${location}: ${message}${RESET}"
    TOTAL_VIOLATIONS=$((TOTAL_VIOLATIONS + 1))
}

is_valid_key() {
    local key="$1"
    # Dynamic resources may have a format suffix after the stable key.
    key="${key%% *}"
    [[ "$key" =~ ^[a-z][a-z0-9]*(_[a-z0-9]+){2,}$ ]]
}

is_generated_catalog_key() {
    # Xcode can extract an empty key and printf-style format keys from source
    # expressions. They are catalog entries, not user-authored resource names.
    [[ -z "$1" || "$1" == %* ]]
}

catalog_has_key() {
    local key="$1"
    local key_base="${key%% *}"
    [ "$CATALOG_VALID" = true ] || return 0
    jq -e --arg key "$key_base" \
        '[.strings | keys[] | select(. == $key or startswith($key + " "))] | length > 0' \
        "$CATALOG" >/dev/null 2>&1
}

record_resource_reference() {
    local record="$1"
    local line_data="${record#*:}"
    local file="${record%%:*}"
    local line="${line_data%%:*}"
    local source="${line_data#*:}"
    local literal=""

    literal=$(printf '%s\n' "$source" | sed -nE \
        -e 's/.*String\(localized:[[:space:]]*"([^"]*)".*/\1/p' \
        -e 's/.*LocalizedStringKey\([[:space:]]*"([^"]*)".*/\1/p' | head -n 1)
    [ -n "$literal" ] || return 0

    if ! is_valid_key "$literal"; then
        report_violation "$file:$line" "localization resource must use a prefixed key: \"$literal\""
    elif ! catalog_has_key "$literal"; then
        report_violation "$file:$line" "localization key is missing from Localizable.xcstrings: \"${literal%% *}\""
    fi
}

record_ui_literal() {
    local record="$1"
    local line_data="${record#*:}"
    local file="${record%%:*}"
    local line="${line_data%%:*}"
    local source="${line_data#*:}"
    local literal=""

    literal=$(printf '%s\n' "$source" | sed -nE \
        -e 's/.*(Text|Label|Button|TextField|ProgressView)\("([^"]*)".*/\2/p' \
        -e 's/.*\.(navigationTitle|alert|confirmationDialog|accessibilityLabel|accessibilityHint|accessibilityValue)\("([^"]*)".*/\2/p' | head -n 1)
    [ -n "$literal" ] || return 0

    # Empty Text and dynamic user/content values are not resource declarations.
    [ -n "$literal" ] || return 0
    local literal_prefix="${literal:0:2}"
    if [ "$literal_prefix" = '\(' ]; then
        case "$literal" in
            *%*) ;;
            *) return 0 ;;
        esac
    fi

    if ! is_valid_key "$literal"; then
        report_violation "$file:$line" "SwiftUI user-visible literal must use a prefixed localization key: \"$literal\""
    elif ! catalog_has_key "$literal"; then
        report_violation "$file:$line" "SwiftUI localization key is missing from Localizable.xcstrings: \"${literal%% *}\""
    fi
}

scan_catalog() {
    if [ ! -f "$CATALOG" ]; then
        report_violation "$CATALOG" "required String Catalog is missing"
        return
    fi

    # String Catalog files use JSON syntax. `plutil -lint` rejects valid
    # catalogs on some macOS versions because it treats the .xcstrings
    # extension as an unsupported property-list type, so jq is the portable
    # syntax check here.
    if ! jq -e . "$CATALOG" >/dev/null 2>&1; then
        report_violation "$CATALOG" "String Catalog is not valid JSON"
        return
    fi

    if ! jq -e '.sourceLanguage and (.strings | type == "object") and .version' "$CATALOG" >/dev/null 2>&1; then
        report_violation "$CATALOG" "String Catalog must contain sourceLanguage, strings, and version"
        return
    fi

    CATALOG_VALID=true
    while IFS= read -r key; do
        if is_generated_catalog_key "$key"; then
            continue
        fi
        if ! is_valid_key "$key"; then
            report_violation "$CATALOG" "catalog key must follow <screen>_<component>_<type>: \"$key\""
        fi
    done < <(jq -r '.strings | keys[]' "$CATALOG" 2>/dev/null || true)
}

scan_resource_references() {
    while IFS= read -r record; do
        record_resource_reference "$record"
    done < <(
        rg -n --color never --glob '*.swift' \
            'String\(localized:[[:space:]]*"|LocalizedStringKey\([[:space:]]*"' \
            "$SOURCE_ROOT" 2>/dev/null || true
    )
}

scan_ui_literals() {
    while IFS= read -r record; do
        record_ui_literal "$record"
    done < <(
        rg -n --color never --glob '*.swift' \
            '(Text|Label|Button|TextField|ProgressView)\("[^"\n]*"|\.(navigationTitle|alert|confirmationDialog|accessibilityLabel|accessibilityHint|accessibilityValue)\("[^"\n]*"' \
            "$SOURCE_ROOT/Views" 2>/dev/null || true
    )
}

scan_forbidden_localization_apis() {
    while IFS= read -r record; do
        local file="${record%%:*}"
        local line_data="${record#*:}"
        local line="${line_data%%:*}"
        report_violation "$file:$line" "NSLocalizedString is not allowed; use a catalog key with String(localized:)"
    done < <(
        rg -n --color never --glob '*.swift' 'NSLocalizedString\(' "$SOURCE_ROOT" 2>/dev/null || true
    )
}

scan_app_owned_bypasses() {
    local search_roots=(
        "$SOURCE_ROOT/Domain"
        "$SOURCE_ROOT/ViewModels"
        "$SOURCE_ROOT/Views"
        "$SOURCE_ROOT/Data"
    )

    while IFS= read -r record; do
        local file="${record%%:*}"
        local line_data="${record#*:}"
        local line="${line_data%%:*}"
        report_violation "$file:$line" "app-owned error message must come from a localization resource"
    done < <(
        rg -n --color never --glob '*.swift' \
            '\.(invalid|error)\(message:[[:space:]]*"|message[[:space:]]*\?\?[[:space:]]*"[A-Z]|(invalidCallback|tokenExchangeFailed|loginFailed|shareFailed)\("[A-Z]|network\(underlying:[[:space:]]*"[A-Z]|static let [A-Za-z0-9]*(Title|Label|Message|Placeholder|Description|Error)[[:space:]]*=[[:space:]]*"[A-Z]|return[[:space:]]*"[A-Z][^"]*[.!?]' \
            "${search_roots[@]}" 2>/dev/null || true
    )

    while IFS= read -r record; do
        local file="${record%%:*}"
        local line_data="${record#*:}"
        local line="${line_data%%:*}"
        report_violation "$file:$line" "raw code-language label must use a localization resource"
    done < <(
        rg -n --color never --glob '*.swift' '"Plain Text"' \
            "$SOURCE_ROOT/Views" "$SOURCE_ROOT/ViewModels" 2>/dev/null || true
    )

    while IFS= read -r record; do
        local file="${record%%:*}"
        local line_data="${record#*:}"
        local line="${line_data%%:*}"
        report_violation "$file:$line" "accessibility category labels must use localized copy, not rawValue"
    done < <(
        rg -n --color never --glob '*.swift' 'accessibilityLabel\([^)]*\.rawValue' \
            "$SOURCE_ROOT/Views" 2>/dev/null || true
    )
}

echo -e "\n${BOLD}=== Localization Rules Checker ===${RESET}"
echo "  Source root: $SOURCE_ROOT"

if ! command -v jq >/dev/null 2>&1; then
    report_violation "environment" "jq is required to validate the String Catalog"
else
    scan_catalog
    scan_resource_references
fi

scan_ui_literals
scan_forbidden_localization_apis
scan_app_owned_bypasses

echo ""
if [ "$TOTAL_VIOLATIONS" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✓ All localization rules passed${RESET}\n"
    exit 0
fi

echo -e "${RED}${BOLD}✗ $TOTAL_VIOLATIONS localization violation(s) found${RESET}\n"
exit 1
