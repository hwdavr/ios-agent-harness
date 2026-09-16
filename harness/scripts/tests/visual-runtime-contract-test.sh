#!/usr/bin/env bash
# Contract tests for the visual-runtime simulator appearance and locale preflight.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
HELPER="$REPO_ROOT/harness/scripts/prepare-visual-runtime.sh"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/visual-runtime-contract.XXXXXX")"
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

fail_test() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_failure() {
  local expected="$1"
  shift
  local output
  if output=$("$@" 2>&1); then
    echo "$output" >&2
    fail_test "command unexpectedly succeeded: $*"
  fi
  printf '%s\n' "$output" | grep -Fq -- "$expected" || {
    echo "$output" >&2
    fail_test "output did not contain '$expected': $*"
  }
}

mkdir -p "$FIXTURE_ROOT/bin"
cat > "$FIXTURE_ROOT/bin/xcrun" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -ge 4 ] && [ "$1" = "simctl" ] && [ "$2" = "list" ] && [ "$3" = "devices" ] && [ "$4" = "--json" ]; then
  printf '%s\n' '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-0":[{"name":"iPhone 16","udid":"11111111-1111-1111-1111-111111111111","state":"Booted","isAvailable":true}]}}'
  exit 0
fi
if [ "$#" -eq 5 ] && [ "$1" = "simctl" ] && [ "$2" = "ui" ] && [ "$3" = "11111111-1111-1111-1111-111111111111" ] && [ "$4" = "appearance" ]; then
  printf '%s\n' "$*" >> "${VISUAL_RUNTIME_CALL_LOG:?}"
  exit 0
fi
if [ "$#" -eq 9 ] && [ "$1" = "simctl" ] && [ "$2" = "spawn" ] && [ "$3" = "11111111-1111-1111-1111-111111111111" ] && [ "$4" = "defaults" ] && [ "$5" = "write" ] && [ "$6" = "NSGlobalDomain" ]; then
  printf '%s\n' "$*" >> "${VISUAL_RUNTIME_CALL_LOG:?}"
  exit 0
fi
echo "unexpected xcrun invocation: $*" >&2
exit 1
EOF
chmod +x "$FIXTURE_ROOT/bin/xcrun"

export VISUAL_RUNTIME_CALL_LOG="$FIXTURE_ROOT/calls.log"
printf '%s\n' \
  '{' \
  '  "version": 1,' \
  '  "target_id": "runtime-test",' \
  '  "appearance": "light",' \
  '  "device": "iPhone 16",' \
  '  "logical_size_pt": { "width": 393, "height": 852 },' \
  '  "locale": "en-US",' \
  '  "states": { "runtime-state": {} }' \
  '}' > "$FIXTURE_ROOT/visual-target.json"
PATH="$FIXTURE_ROOT/bin:$PATH" bash "$HELPER" --target "$FIXTURE_ROOT/visual-target.json"
PATH="$FIXTURE_ROOT/bin:$PATH" bash "$HELPER" --target "$FIXTURE_ROOT/visual-target.json" --device 11111111-1111-1111-1111-111111111111
grep -Fq "simctl ui 11111111-1111-1111-1111-111111111111 appearance light" "$VISUAL_RUNTIME_CALL_LOG" \
  || fail_test "the helper did not configure the requested light appearance"
grep -Fq "simctl spawn 11111111-1111-1111-1111-111111111111 defaults write NSGlobalDomain AppleLanguages -array en-US" "$VISUAL_RUNTIME_CALL_LOG" \
  || fail_test "the helper did not configure the requested simulator language"
grep -Fq "simctl spawn 11111111-1111-1111-1111-111111111111 defaults write NSGlobalDomain AppleLocale -string en-US" "$VISUAL_RUNTIME_CALL_LOG" \
  || fail_test "the helper did not configure the requested simulator locale"

printf '%s\n' \
  '{' \
  '  "version": 1,' \
  '  "target_id": "runtime-test-invalid-locale",' \
  '  "appearance": "light",' \
  '  "device": "iPhone 16",' \
  '  "logical_size_pt": { "width": 393, "height": 852 },' \
  '  "locale": "en",' \
  '  "states": { "runtime-state": {} }' \
  '}' > "$FIXTURE_ROOT/invalid-locale-target.json"
expect_failure "visual target locale must be a concrete BCP-47" env PATH="$FIXTURE_ROOT/bin:$PATH" bash "$HELPER" --target "$FIXTURE_ROOT/invalid-locale-target.json"

printf '%s\n' \
  '{' \
  '  "version": 1,' \
  '  "target_id": "runtime-test-wrong-device",' \
  '  "appearance": "light",' \
  '  "device": "iPhone 17",' \
  '  "logical_size_pt": { "width": 393, "height": 852 },' \
  '  "locale": "en-US",' \
  '  "states": { "runtime-state": {} }' \
  '}' > "$FIXTURE_ROOT/wrong-device-target.json"
expect_failure "but visual target requires 'iPhone 17'" env PATH="$FIXTURE_ROOT/bin:$PATH" bash "$HELPER" --target "$FIXTURE_ROOT/wrong-device-target.json" --device 11111111-1111-1111-1111-111111111111

cat > "$FIXTURE_ROOT/bin/xcrun" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -ge 4 ] && [ "$1" = "simctl" ] && [ "$2" = "list" ] && [ "$3" = "devices" ] && [ "$4" = "--json" ]; then
  printf '%s\n' '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-0":[{"name":"iPhone 16","udid":"11111111-1111-1111-1111-111111111111","state":"Shutdown","isAvailable":true}]}}'
  exit 0
fi
exit 1
EOF
chmod +x "$FIXTURE_ROOT/bin/xcrun"
expect_failure "no booted simulator named 'iPhone 16' from visual target" env PATH="$FIXTURE_ROOT/bin:$PATH" bash "$HELPER" --target "$FIXTURE_ROOT/visual-target.json"

echo "PASS: visual runtime preflight configures the shared target on the requested booted simulator and rejects invalid locale, device, and availability cases."
