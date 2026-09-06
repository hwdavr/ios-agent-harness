#!/usr/bin/env bash
# Critical Journey Registry Checker
# Validates the journey registry, checks destination coverage,
# and executes registered journeys as a regression gate.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${HARNESS_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

REGISTRY_PATH=""
DESTINATIONS_FILE=""
MODE=""
TARGET_ID=""
DRY_RUN=0

usage() {
  cat << 'EOF' >&2
Usage: bash harness/scripts/check-journey-registry.sh [OPTIONS] <MODE>

Options:
  --registry <path>           Path to journey-registry.yaml (default: docs/product/journey-registry.yaml)
  --project-root <path>       Root directory of the project
  --destinations-file <path>  Path to file declaring app destinations/routes
  --dry-run                   Print execution command without running tests (for --run-all / --run-one)

Modes (must specify exactly one):
  --validate                  Validate registry schema, file paths, methods, and selectors
  --check-coverage            Report destination coverage against declared routes
  --run-all                   Run all registered journey tests via xcodebuild
  --run-one <journey-id>      Run a specific journey test by ID

Exit codes:
  0: All validations/checks/tests passed
  1: Test failure or regression
  2: Schema/validation error, missing file, or invalid arguments
EOF
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --registry)
      [ $# -ge 2 ] || usage
      REGISTRY_PATH="$2"
      shift 2
      ;;
    --project-root)
      [ $# -ge 2 ] || usage
      PROJECT_ROOT="$2"
      shift 2
      ;;
    --destinations-file)
      [ $# -ge 2 ] || usage
      DESTINATIONS_FILE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --validate)
      MODE="validate"
      shift
      ;;
    --check-coverage)
      MODE="check-coverage"
      shift
      ;;
    --run-all)
      MODE="run-all"
      shift
      ;;
    --run-one)
      [ $# -ge 2 ] || usage
      MODE="run-one"
      TARGET_ID="$2"
      shift 2
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo "Error: Unknown option '$1'" >&2
      usage
      ;;
  esac
done

[ -n "$MODE" ] || usage

if [ -z "$REGISTRY_PATH" ]; then
  REGISTRY_PATH="$PROJECT_ROOT/docs/product/journey-registry.yaml"
elif [[ "$REGISTRY_PATH" != /* ]]; then
  REGISTRY_PATH="$PROJECT_ROOT/$REGISTRY_PATH"
fi

if [ -z "$DESTINATIONS_FILE" ]; then
  DESTINATIONS_FILE=""
elif [[ "$DESTINATIONS_FILE" != /* ]]; then
  DESTINATIONS_FILE="$PROJECT_ROOT/$DESTINATIONS_FILE"
fi

export PROJECT_ROOT
export REGISTRY_PATH
export DESTINATIONS_FILE
export MODE
export TARGET_ID
export DRY_RUN

python3 - << 'PYTHON_SCRIPT'
import os
import re
import subprocess
import sys
from pathlib import Path

project_root = Path(os.environ["PROJECT_ROOT"]).resolve()
registry_path = Path(os.environ["REGISTRY_PATH"]).resolve()
destinations_file_str = os.environ.get("DESTINATIONS_FILE", "")
destinations_file = Path(destinations_file_str).resolve() if destinations_file_str else None
mode = os.environ["MODE"]
target_id = os.environ.get("TARGET_ID", "")
dry_run = os.environ.get("DRY_RUN", "0") == "1"

def is_placeholder(val):
    if not val:
        return True
    s = str(val).strip()
    if s in {"", "N/A", "n/a", "null", "None"}:
        return True
    if s.startswith("{") and s.endswith("}"):
        try:
            import json
            json.loads(s)
            return False
        except Exception:
            return True
    if s.startswith("<") and s.endswith(">"):
        return True
    if "insert" in s.lower() and ("here" in s.lower() or "description" in s.lower()):
        return True
    return False

def parse_yaml_journeys(content):
    """Minimal YAML parser for journey-registry.yaml."""
    journeys = []
    current = None
    for line in content.splitlines():
        stripped = line.strip()
        if stripped.startswith("- id:"):
            if current is not None:
                journeys.append(current)
            current = {"id": stripped.split(":", 1)[1].strip()}
        elif current is not None and stripped.startswith("- ") and ":" not in stripped:
            last_key = list(current.keys())[-1]
            if isinstance(current[last_key], list):
                current[last_key].append(stripped[2:].strip())
        elif current is not None and ":" in stripped:
            key, _, val = stripped.partition(":")
            key = key.strip()
            val = val.strip().strip('"').strip("'")
            if key == "destinations":
                current[key] = []
            else:
                current[key] = val if val else None
    if current is not None:
        journeys.append(current)
    return journeys

def validate_registry():
    if not registry_path.is_file():
        print(f"FAIL: Journey registry file not found: {registry_path}", file=sys.stderr)
        return False, []

    content = registry_path.read_text(encoding="utf-8")
    if not content.strip():
        print(f"FAIL: Journey registry file is empty: {registry_path}", file=sys.stderr)
        return False, []

    journeys = parse_yaml_journeys(content)
    if not journeys:
        print(f"FAIL: No journeys found in registry: {registry_path}", file=sys.stderr)
        return False, []

    required_fields = [
        "id",
        "description",
        "introduced_by",
        "destinations",
        "test_file",
        "test_method",
        "xcode_selector",
        "boundary",
        "post_return_assertion",
    ]

    violations = []
    seen_ids = set()

    for idx, j in enumerate(journeys):
        entry_desc = f"entry #{idx+1} (id='{j.get('id', 'UNKNOWN')}')"
        for field in required_fields:
            val = j.get(field)
            if val is None:
                violations.append(f"{entry_desc}: missing required field '{field}'")
            elif isinstance(val, list):
                if len(val) == 0:
                    violations.append(f"{entry_desc}: field '{field}' must not be empty")
                else:
                    for item in val:
                        if is_placeholder(item):
                            violations.append(f"{entry_desc}: field '{field}' contains placeholder item '{item}'")
            elif is_placeholder(val):
                violations.append(f"{entry_desc}: field '{field}' has empty or placeholder value '{val}'")

        jid = j.get("id")
        if jid:
            if jid in seen_ids:
                violations.append(f"{entry_desc}: duplicate journey id '{jid}'")
            seen_ids.add(jid)

        test_file_str = j.get("test_file")
        if test_file_str and not is_placeholder(test_file_str):
            test_file_path = (project_root / test_file_str).resolve()
            if not test_file_path.is_file():
                violations.append(f"{entry_desc}: test_file does not exist: {test_file_str}")
            elif not test_file_str.endswith("Tests.swift"):
                violations.append(f"{entry_desc}: test_file must end with Tests.swift")
            else:
                test_content = test_file_path.read_text(encoding="utf-8")
                method = j.get("test_method")
                if method and not is_placeholder(method):
                    method_regex = re.compile(rf"func\s+{re.escape(method)}\s*\(")
                    if not method_regex.search(test_content):
                        violations.append(f"{entry_desc}: test_method '{method}' not found in {test_file_str}")

                selector = j.get("xcode_selector")
                if selector and not is_placeholder(selector):
                    if "/" not in selector:
                        violations.append(f"{entry_desc}: xcode_selector '{selector}' must be in format <Target>/<Class>/<method>")
                    else:
                        parts = selector.split("/")
                        if len(parts) >= 2:
                            meth_part = parts[-1]
                            cls_part = parts[-2]
                            if method and meth_part != method:
                                violations.append(f"{entry_desc}: xcode_selector method '{meth_part}' does not match test_method '{method}'")
                            if cls_part not in test_file_str:
                                violations.append(f"{entry_desc}: xcode_selector class '{cls_part}' does not match file name '{test_file_str}'")

    if violations:
        print("======================================================", file=sys.stderr)
        print("  Journey Registry Validation FAILED", file=sys.stderr)
        print("======================================================", file=sys.stderr)
        for v in violations:
            print(f"  FAIL: {v}", file=sys.stderr)
        return False, journeys

    print("======================================================")
    print("  Journey Registry Validation PASSED")
    print("======================================================")
    print(f"  Registry: {registry_path}")
    print(f"  Total valid journeys: {len(journeys)}")
    for j in journeys:
        print(f"    - [{j['id']}] {j['description']}")
        print(f"        Selector: {j['xcode_selector']}")
        print(f"        Boundary: {j['boundary']}")
    return True, journeys

def check_coverage(journeys):
    if destinations_file is None or not destinations_file.is_file():
        print(f"FAIL: Destinations file not found: {destinations_file}", file=sys.stderr)
        sys.exit(2)

    content = destinations_file.read_text(encoding="utf-8")
    # Match Swift enum cases or static properties declared as route destinations
    app_destinations = sorted(list(set(re.findall(r"case\s+([A-Za-z0-9_]+)", content))))

    dest_to_journeys = {}
    for d in app_destinations:
        dest_to_journeys[d] = []

    for j in journeys:
        for d in j.get("destinations", []):
            if d in dest_to_journeys:
                dest_to_journeys[d].append(j["id"])
            else:
                dest_to_journeys[d] = [j["id"]]

    covered = [d for d in app_destinations if dest_to_journeys.get(d)]
    uncovered = [d for d in app_destinations if not dest_to_journeys.get(d)]

    pct = (len(covered) / len(app_destinations) * 100.0) if app_destinations else 0.0

    print("======================================================")
    print("  Critical Journey Destination Coverage")
    print("======================================================")
    print(f"  Destinations source: {destinations_file}")
    print(f"  Coverage: {len(covered)} / {len(app_destinations)} ({pct:.1f}%)\n")

    print("  COVERED DESTINATIONS:")
    for d in covered:
        ids = ", ".join(dest_to_journeys[d])
        print(f"    [+] {d:<20} -> covered by {ids}")

    print("\n  UNCOVERED DESTINATIONS:")
    for d in uncovered:
        print(f"    [-] {d}")

    print("======================================================")

if mode == "validate":
    valid, _ = validate_registry()
    sys.exit(0 if valid else 2)

elif mode == "check-coverage":
    valid, journeys = validate_registry()
    if not valid:
        sys.exit(2)
    check_coverage(journeys)
    sys.exit(0)

elif mode == "run-one":
    valid, journeys = validate_registry()
    if not valid:
        sys.exit(2)

    entry = next((j for j in journeys if j.get("id") == target_id), None)
    if not entry:
        print(f"FAIL: Journey ID '{target_id}' not found in registry.", file=sys.stderr)
        sys.exit(2)

    selector = entry["xcode_selector"]
    cmd = [
        "xcodebuild", "test",
        "-project", "NotesTakingAppiOS.xcodeproj",
        "-scheme", "NotesTakingAppiOS",
        "-destination", "platform=iOS Simulator,name=iPhone 16",
        f"-only-testing:{selector}",
    ]

    print("======================================================")
    print(f"  Executing Critical Journey: {target_id}")
    print("======================================================")
    print(f"  Description: {entry.get('description')}")
    print(f"  Boundary:    {entry.get('boundary')}")
    print(f"  Selector:    {selector}")
    print(f"  Command:     {' '.join(cmd)}")
    print("======================================================")

    if dry_run:
        print("[DRY-RUN] Command would be executed successfully.")
        sys.exit(0)

    res = subprocess.run(cmd, cwd=project_root)
    sys.exit(0 if res.returncode == 0 else 1)

elif mode == "run-all":
    valid, journeys = validate_registry()
    if not valid:
        sys.exit(2)

    selectors = [j["xcode_selector"] for j in journeys]

    cmd = ["xcodebuild", "test",
           "-project", "NotesTakingAppiOS.xcodeproj",
           "-scheme", "NotesTakingAppiOS",
           "-destination", "platform=iOS Simulator,name=iPhone 16"]
    for sel in selectors:
        cmd.append(f"-only-testing:{sel}")

    print("======================================================")
    print(f"  Executing ALL Critical Journeys ({len(journeys)} registered)")
    print("======================================================")
    for j in journeys:
        print(f"    - {j['id']}: {j['xcode_selector']}")
    print(f"  Command: {' '.join(cmd)}")
    print("======================================================")

    if dry_run:
        print("[DRY-RUN] Command would be executed successfully.")
        sys.exit(0)

    res = subprocess.run(cmd, cwd=project_root)
    sys.exit(0 if res.returncode == 0 else 1)

else:
    print(f"FAIL: Unknown mode '{mode}'", file=sys.stderr)
    sys.exit(2)
PYTHON_SCRIPT
