#!/usr/bin/env python3
"""Dependency-free source policy evaluator for AI and WebView boundaries (iOS)."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


HIGH = "high"
IGNORE_PARTS = {".build", "build", "Build", "DerivedData", "deriveddata", ".git", "Pods", "node_modules"}
SUPPRESS_COMMENT = re.compile(r"(//|#)\s*aisec:ignore", re.IGNORECASE)


def finding(rule_id: str, path: Path, line: int, message: str) -> dict[str, object]:
    return {
        "id": rule_id,
        "severity": HIGH,
        "path": path.as_posix(),
        "line": line,
        "message": message,
    }


def should_skip(path: Path) -> bool:
    return any(part in IGNORE_PARTS for part in path.parts)


def scan_file(path: Path, patterns: list[tuple[str, str, str]]) -> list[dict[str, object]]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeDecodeError):
        return []

    findings: list[dict[str, object]] = []
    for rule_id, regex, message in patterns:
        compiled = re.compile(regex, re.IGNORECASE)
        for line_number, line in enumerate(lines, start=1):
            if SUPPRESS_COMMENT.search(line):
                continue
            if compiled.search(line):
                findings.append(finding(rule_id, path, line_number, message))
    return findings


def scan_file_multiline(path: Path, patterns: list[tuple[str, str, str]]) -> list[dict[str, object]]:
    """Scan full file content with DOTALL so patterns can span multiple lines."""
    try:
        content = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return []

    findings: list[dict[str, object]] = []
    for rule_id, regex, message in patterns:
        compiled = re.compile(regex, re.IGNORECASE | re.DOTALL)
        for match in compiled.finditer(content):
            line_number = content[:match.start()].count("\n") + 1
            findings.append(finding(rule_id, path, line_number, message))
    return findings


def collect_findings(root: Path) -> list[dict[str, object]]:
    findings: list[dict[str, object]] = []

    # 1. Cleartext traffic checks (Info.plist — NSAppTransportSecurity)
    #    Uses multiline scan because <key> and <true/> may be on separate lines.
    for plist in sorted(root.rglob("*.plist")):
        if should_skip(plist):
            continue
        findings.extend(
            scan_file_multiline(
                plist,
                [
                    (
                        "AISEC-CLEARTEXT",
                        r"<key>NSAllowsArbitraryLoads</key>\s*\n?\s*<true\s*/>",
                        "App Transport Security must not allow arbitrary loads (cleartext traffic).",
                    )
                ],
            )
        )

    # 2. Source code patterns (Swift — WKWebView security boundaries)
    source_patterns = [
        (
            "AISEC-WEBVIEW-JAVASCRIPT",
            r"allowsContentJavaScript\s*=\s*true",
            "The inline renderer must not enable JavaScript unless required and sandboxed.",
        ),
        (
            "AISEC-WEBVIEW-FILE-ACCESS",
            r"allowFileAccessFromFileURLs\s*=\s*true",
            "WKWebView must not allow file access from file URLs.",
        ),
        (
            "AISEC-WEBVIEW-UNIVERSAL-ACCESS",
            r"allowUniversalAccessFromFileURLs\s*=\s*true",
            "WKWebView must not allow universal access from file URLs.",
        ),
        (
            "AISEC-WEBVIEW-EVAL-UNTRUSTED",
            r"evaluateJavaScript\([^)]*\b(prompt|modelResult|output|summary|noteText|content|userInput)\b",
            "Untrusted content must not be passed to evaluateJavaScript.",
        ),
        (
            "AISEC-WEBVIEW-FILE-BASE-URL",
            r"loadHTMLString\([^)]*baseURL:\s*URL\(string:\s*\"file:",
            "Inline HTML must not use a file: base URL; use nil or about:blank.",
        ),
        (
            "AISEC-WEBVIEW-BROAD-FILE-ACCESS",
            r"loadFileURL\([^)]*allowingReadAccessTo:\s*URL\(string:\s*\"file:///\"\)",
            "loadFileURL must not grant read access to the filesystem root.",
        ),
        (
            "AISEC-AI-INPUT-LOGGING",
            r"(Logger(\.[a-zA-Z_]+)+|os_log|print|NSLog)\([^\n]*(prompt|noteText|accessToken|refreshToken|idToken)\b",
            "AI inputs and credentials must not be written to logs.",
        ),
        (
            "AISEC-OUTPUT-HTML-SINK",
            r"(innerHTML\s*=\s*[^;]*|loadHTMLString\([^)]*|evaluateJavaScript\([^)]*)(prompt|modelResult|output|summary|noteText|content)\b",
            "Untrusted model output must not flow directly into an HTML sink.",
        ),
    ]

    for path in sorted(root.rglob("*.swift")):
        if should_skip(path):
            continue
        findings.extend(scan_file(path, source_patterns))

    # 3. Asset and diagram security level patterns
    asset_patterns = [
        (
            "AISEC-MERMAID-SECURITY-LEVEL",
            r"securityLevel\s*:\s*['\"]loose['\"]",
            "Mermaid must use strict security mode for untrusted diagram text.",
        )
    ]

    for path in sorted(root.rglob("*")):
        if not path.is_file() or should_skip(path):
            continue
        if path.suffix in (".html", ".htm", ".js", ".mjs") or "Assets" in path.parts or "Resources" in path.parts:
            findings.extend(scan_file(path, asset_patterns))

    return sorted(findings, key=lambda item: (str(item["path"]), int(item["line"]), str(item["id"])))


def render_markdown(root: Path, findings: list[dict[str, object]]) -> str:
    status = "FAIL" if findings else "PASS"
    lines = [
        "# AI Security Rules Report",
        "",
        f"- Status: **{status}**",
        f"- Root: `{root}`",
        f"- High-severity findings: **{len(findings)}**",
        "",
        "The report intentionally contains only rule IDs, paths, line numbers, and redacted remediation text.",
        "",
    ]
    if not findings:
        lines.append("No high-severity AI/WebView boundary findings detected.")
        return "\n".join(lines) + "\n"
    lines.extend(["| ID | Severity | Location | Remediation |", "|---|---|---|---|"])
    for item in findings:
        location = f"`{item['path']}:{item['line']}`"
        lines.append(f"| `{item['id']}` | {item['severity']} | {location} | {item['message']} |")
    return "\n".join(lines) + "\n"


def render_json(root: Path, findings: list[dict[str, object]]) -> str:
    payload = {
        "schema_version": 1,
        "status": "FAIL" if findings else "PASS",
        "root": root.as_posix(),
        "finding_count": len(findings),
        "findings": findings,
    }
    return json.dumps(payload, indent=2) + "\n"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=None, help="Repository root to scan")
    parser.add_argument("--format", choices=("markdown", "json"), default="markdown")
    parser.add_argument("--output", type=Path, default=None, help="Existing-parent report path")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = (args.root or Path(__file__).resolve().parents[2]).resolve()
    if not root.is_dir():
        print(f"FAIL: repository root does not exist: {root}", file=sys.stderr)
        return 2
    if args.output is not None and not args.output.parent.is_dir():
        print(f"FAIL: report parent directory does not exist: {args.output.parent}", file=sys.stderr)
        return 2

    findings = collect_findings(root)
    report = render_markdown(root, findings) if args.format == "markdown" else render_json(root, findings)
    if args.output is None:
        print(report, end="")
    else:
        try:
            args.output.write_text(report, encoding="utf-8")
        except OSError as error:
            print(f"FAIL: could not write report: {error}", file=sys.stderr)
            return 2
        print(f"AI security report written to {args.output}")
    if findings:
        for item in findings:
            print(
                f"FAIL {item['id']} {item['path']}:{item['line']} — {item['message']}",
                file=sys.stderr,
            )
        return 1
    print("PASS: AI security rules")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
