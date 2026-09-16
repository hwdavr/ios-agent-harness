#!/usr/bin/env bash
# Configure the concrete booted simulator used for visual evidence.
# The visual-target manifest is the source of truth for appearance, device, and
# locale so mockup generation and runtime capture cannot silently drift apart.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${HARNESS_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

usage() {
  echo "Usage: bash harness/scripts/prepare-visual-runtime.sh --target <visual-target.json> [--device <udid>] [--device-name <name>] [--appearance <light|dark>] [--locale <BCP-47>]" >&2
  exit 2
}

TARGET_PATH=""
APPEARANCE_OVERRIDE=""
DEVICE_ID=""
DEVICE_NAME_OVERRIDE=""
LOCALE_OVERRIDE=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target|--visual-target)
      [ "$#" -ge 2 ] || usage
      TARGET_PATH="$2"
      shift 2
      ;;
    --appearance)
      [ "$#" -ge 2 ] || usage
      APPEARANCE_OVERRIDE="$2"
      shift 2
      ;;
    --device)
      [ "$#" -ge 2 ] || usage
      DEVICE_ID="$2"
      shift 2
      ;;
    --device-name)
      [ "$#" -ge 2 ] || usage
      DEVICE_NAME_OVERRIDE="$2"
      shift 2
      ;;
    --locale)
      [ "$#" -ge 2 ] || usage
      LOCALE_OVERRIDE="$2"
      shift 2
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo "FAIL: unknown option '$1'" >&2
      usage
      ;;
  esac
done

[ -n "$TARGET_PATH" ] || {
  echo "FAIL: --target is required; runtime setup must read the canonical visual target manifest" >&2
  exit 2
}

if [[ "$TARGET_PATH" != /* ]] && [ ! -f "$TARGET_PATH" ] && [ -f "$PROJECT_ROOT/$TARGET_PATH" ]; then
  TARGET_PATH="$PROJECT_ROOT/$TARGET_PATH"
fi
[ -f "$TARGET_PATH" ] || {
  echo "FAIL: visual target manifest not found: $TARGET_PATH" >&2
  exit 2
}

TARGET_PATH="$TARGET_PATH" APPEARANCE_OVERRIDE="$APPEARANCE_OVERRIDE" \
DEVICE_NAME_OVERRIDE="$DEVICE_NAME_OVERRIDE" LOCALE_OVERRIDE="$LOCALE_OVERRIDE" \
python3 - <<'PYTHON_SCRIPT'
import json
import os
import re
import sys
from pathlib import Path

path = Path(os.environ["TARGET_PATH"]).resolve()
try:
    manifest = json.loads(path.read_text(encoding="utf-8"))
except Exception as error:
    print(f"FAIL: could not parse visual target manifest {path}: {error}", file=sys.stderr)
    sys.exit(2)

if not isinstance(manifest, dict) or manifest.get("version") != 1:
    print("FAIL: visual target manifest must use version 1", file=sys.stderr)
    sys.exit(2)

required = ("target_id", "appearance", "device", "logical_size_pt", "locale", "states")
missing = [key for key in required if key not in manifest]
if missing:
    print(f"FAIL: visual target manifest is missing {', '.join(missing)}", file=sys.stderr)
    sys.exit(2)

appearance = manifest["appearance"]
device = manifest["device"]
locale = manifest["locale"]
logical_size = manifest["logical_size_pt"]
states = manifest["states"]
if appearance not in {"light", "dark"}:
    print("FAIL: visual target appearance must be light or dark", file=sys.stderr)
    sys.exit(2)
if not isinstance(device, str) or not device.strip():
    print("FAIL: visual target device must be a non-empty string", file=sys.stderr)
    sys.exit(2)
if not isinstance(locale, str) or not re.fullmatch(r"[A-Za-z]{2,3}-[A-Za-z]{2}", locale):
    print("FAIL: visual target locale must be a concrete BCP-47 language-region value such as en-US", file=sys.stderr)
    sys.exit(2)
if not isinstance(logical_size, dict) or not all(isinstance(logical_size.get(key), (int, float)) and logical_size[key] > 0 for key in ("width", "height")):
    print("FAIL: visual target logical_size_pt must contain positive width and height", file=sys.stderr)
    sys.exit(2)
if not isinstance(states, dict) or not states:
    print("FAIL: visual target states must be a non-empty object", file=sys.stderr)
    sys.exit(2)

appearance_override = os.environ.get("APPEARANCE_OVERRIDE", "")
if appearance_override and appearance_override != appearance:
    print(f"FAIL: --appearance {appearance_override} conflicts with visual target appearance {appearance}", file=sys.stderr)
    sys.exit(2)
device_override = os.environ.get("DEVICE_NAME_OVERRIDE", "")
if device_override and device_override != device:
    print(f"FAIL: --device-name '{device_override}' conflicts with visual target device '{device}'", file=sys.stderr)
    sys.exit(2)
locale_override = os.environ.get("LOCALE_OVERRIDE", "")
if locale_override and locale_override != locale:
    print(f"FAIL: --locale {locale_override} conflicts with visual target locale {locale}", file=sys.stderr)
    sys.exit(2)

print(f"target_id={manifest['target_id']}")
print(f"appearance={appearance}")
print(f"device={device}")
print(f"locale={locale}")
PYTHON_SCRIPT

APPEARANCE=$(TARGET_PATH="$TARGET_PATH" python3 -c 'import json, os; print(json.load(open(os.environ["TARGET_PATH"], encoding="utf-8"))["appearance"])')
DEVICE_NAME=$(TARGET_PATH="$TARGET_PATH" python3 -c 'import json, os; print(json.load(open(os.environ["TARGET_PATH"], encoding="utf-8"))["device"])')
LOCALE=$(TARGET_PATH="$TARGET_PATH" python3 -c 'import json, os; print(json.load(open(os.environ["TARGET_PATH"], encoding="utf-8"))["locale"])')

if [ -n "$DEVICE_ID" ] && [ -n "$DEVICE_NAME_OVERRIDE" ]; then
  echo "FAIL: provide --device or --device-name, not both" >&2
  exit 2
fi

SIMCTL_JSON=$(xcrun simctl list devices --json)

if [ -n "$DEVICE_ID" ]; then
  DEVICE_STATE=$(printf '%s' "$SIMCTL_JSON" | jq -r --arg udid "$DEVICE_ID" '
    [.devices[][] | select(.udid == $udid) | .state][0] // empty
  ')
  [ "$DEVICE_STATE" = "Booted" ] || {
    echo "FAIL: simulator $DEVICE_ID is not booted (state: ${DEVICE_STATE:-missing})" >&2
    exit 1
  }
  DEVICE_MODEL=$(printf '%s' "$SIMCTL_JSON" | jq -r --arg udid "$DEVICE_ID" '
    [.devices[][] | select(.udid == $udid) | .name][0] // empty
  ')
  [ "$DEVICE_MODEL" = "$DEVICE_NAME" ] || {
    echo "FAIL: simulator $DEVICE_ID is '$DEVICE_MODEL', but visual target requires '$DEVICE_NAME'" >&2
    exit 1
  }
else
  DEVICE_ID=$(printf '%s' "$SIMCTL_JSON" | jq -r --arg name "$DEVICE_NAME" '
    [.devices[][] | select(.name == $name and .state == "Booted") | .udid][0] // empty
  ')
  [ -n "$DEVICE_ID" ] || {
    echo "FAIL: no booted simulator named '$DEVICE_NAME' from visual target" >&2
    exit 1
  }
fi

xcrun simctl ui "$DEVICE_ID" appearance "$APPEARANCE"
xcrun simctl spawn "$DEVICE_ID" defaults write NSGlobalDomain AppleLanguages -array "$LOCALE"
xcrun simctl spawn "$DEVICE_ID" defaults write NSGlobalDomain AppleLocale -string "$LOCALE"
echo "PASS: configured simulator $DEVICE_ID from visual target $TARGET_PATH (appearance=$APPEARANCE locale=$LOCALE device=$DEVICE_NAME)"
