#!/usr/bin/env bash
# =============================================================================
# check-localization-rules.sh
#
# Checks Swift source files for hardcoded user-visible strings.
#
# Usage: ./harness/scripts/check-localization-rules.sh [--all]
# Exit: 0 (no violations), 1 (violations found)
# =============================================================================

set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCE_ROOT="$PROJECT_ROOT/NotesTakingAppiOS"

# Only check View files (strings in ViewModel are not user-visible)
SCAN_ALL=false
[[ "${1:-}" == "--all" ]] && SCAN_ALL=true

view_files=()
while IFS= read -r f; do view_files+=("$f"); done < <(find "$SOURCE_ROOT" -name "*.swift" -type f | grep -iE 'View|Screen|Content|Component')

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
TOTAL_VIOLATIONS=0

echo -e "\n${BOLD}=== Localization Rules Checker ===${RESET}"
echo -e "  View files: ${#view_files[@]}\n"

echo -e "  ${CYAN}Rule: Hardcoded English strings in SwiftUI Views${RESET}"
echo -e "  ${CYAN}(String literals in Text(), Label(), Button(), TextField() etc.)${RESET}"

for f in "${view_files[@]}"; do
    # Find string literals that look like user-visible text (start with capital letter or common words)
    # Exclude single characters, empty strings, and system SF Symbol names
    violations=$(rg -n --color never 'Text\("[A-Z][a-z]|Label\(".*[A-Z][a-z]|Button\("[A-Z][a-z]|TextField\("[A-Z][a-z]|\.navigationTitle\("[A-Z][a-z]' "$f" 2>/dev/null || true)
    # Also check for .sheet/.alert with hardcoded strings
    violations2=$(rg -n --color never '"(Save|Cancel|Delete|Edit|Done|OK|Close|Next|Back|Search|Add|Create|Update|Confirm|Submit|Retry|Settings|Home|Profile|Logout|Sign|Login|Register|Help|About|Share|Copy|Paste|Cut|Undo|Redo|Select|Clear|Filter|Sort|Refresh|Loading|Error|Success|Warning|Info|Yes|No|Remove|Upload|Download|Open|Preview|Print|Export|Import|Move|Rename|Duplicate|Archive|Restore|Unlock|Lock|Start|Stop|Pause|Resume|Play|Forward|Rewind|Skip|Like|Dislike|Favorite|Bookmark|Subscribe|Follow|Unfollow|Rate|Review|Comment|Reply|Forwarded|Send)"' "$f" 2>/dev/null || true)
    
    all_v="$violations"$'\n'"$violations2"
    if [[ -n "$(echo "$all_v" | head -c 5)" ]]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && echo -e "    ${RED}${f#$PROJECT_ROOT/}:${line}${RESET}" && ((TOTAL_VIOLATIONS++))
        done < <(echo "$all_v" | grep -v '^\s*$' | sort -u)
    fi
done

if [[ $TOTAL_VIOLATIONS -eq 0 ]]; then
    echo -e "    ${GREEN}✓ No violations${RESET}"
fi

echo ""
if [[ $TOTAL_VIOLATIONS -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}✓ All localization rules passed${RESET}\n"
    exit 0
else
    echo -e "${RED}${BOLD}✗ $TOTAL_VIOLATIONS violation(s) found${RESET}\n"
    exit 1
fi