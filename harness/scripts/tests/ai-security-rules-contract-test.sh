#!/usr/bin/env bash
# Contract tests for the AI security source evaluator (iOS).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKER="$SCRIPT_DIR/../check-ai-security-rules.sh"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ai-security-rules.XXXXXX")"

cleanup() {
  rm -rf "$FIXTURE_ROOT"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[ -x "$CHECKER" ] || fail "missing executable checker: $CHECKER"

# --- Safe fixture: everything correctly configured ---
mkdir -p "$FIXTURE_ROOT/NotesTakingAppiOS/Data/Mermaid" \
  "$FIXTURE_ROOT/NotesTakingAppiOS/Resources/Mermaid" \
  "$FIXTURE_ROOT/build/reports/ai-security"

cat > "$FIXTURE_ROOT/NotesTakingAppiOS/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>NSAppTransportSecurity</key><dict>
<key>NSAllowsArbitraryLoads</key><false/>
</dict></dict></plist>
EOF
cat > "$FIXTURE_ROOT/NotesTakingAppiOS/Data/Mermaid/SafeRenderer.swift" <<'EOF'
import WebKit
class SafeRenderer {
    func configure() {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.loadHTMLString(html, baseURL: nil)
    }
}
EOF
cat > "$FIXTURE_ROOT/NotesTakingAppiOS/Resources/Mermaid/index.html" <<'EOF'
mermaid.initialize({ securityLevel: 'strict' })
EOF

safe_report="$FIXTURE_ROOT/build/reports/ai-security/safe.md"
bash "$CHECKER" --root "$FIXTURE_ROOT" --format markdown --output "$safe_report" \
  || fail "safe fixture should pass"
[ -s "$safe_report" ] || fail "safe fixture did not produce a report"

# --- Unsafe fixture: all violations present ---
cat > "$FIXTURE_ROOT/NotesTakingAppiOS/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>NSAppTransportSecurity</key><dict>
<key>NSAllowsArbitraryLoads</key>
<true />
</dict></dict></plist>
EOF
cat > "$FIXTURE_ROOT/NotesTakingAppiOS/Data/Mermaid/UnsafeRenderer.swift" <<'EOF'
import WebKit
class UnsafeRenderer {
    private let fixtureSecret = "PRIVATE_FIXTURE_NOTE"

    func render(output: String) {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.allowFileAccessFromFileURLs = true
        webView.evaluateJavaScript("render(\(prompt))")
        container.innerHTML = output
        Logger.app.info("\(prompt)")
    }
}
EOF
cat > "$FIXTURE_ROOT/NotesTakingAppiOS/Resources/Mermaid/index.html" <<'EOF'
mermaid.initialize({ securityLevel: 'loose' })
EOF

unsafe_report="$FIXTURE_ROOT/build/reports/ai-security/unsafe.json"
if bash "$CHECKER" --root "$FIXTURE_ROOT" --format json --output "$unsafe_report"; then
  fail "unsafe fixture should fail"
fi

[ -s "$unsafe_report" ] || fail "unsafe fixture did not produce a JSON report"
grep -Fq 'AISEC-CLEARTEXT' "$unsafe_report" || fail "cleartext finding missing"
grep -Fq 'AISEC-WEBVIEW-JAVASCRIPT' "$unsafe_report" || fail "JavaScript finding missing"
grep -Fq 'AISEC-WEBVIEW-FILE-ACCESS' "$unsafe_report" || fail "file-access finding missing"
grep -Fq 'AISEC-MERMAID-SECURITY-LEVEL' "$unsafe_report" || fail "Mermaid finding missing"
grep -Fq 'AISEC-AI-INPUT-LOGGING' "$unsafe_report" || fail "prompt logging finding missing"
grep -Fq 'AISEC-OUTPUT-HTML-SINK' "$unsafe_report" || fail "output sink finding missing"
grep -Fq 'AISEC-WEBVIEW-EVAL-UNTRUSTED' "$unsafe_report" || fail "evaluateJavaScript untrusted finding missing"
if grep -Fq 'PRIVATE_FIXTURE_NOTE' "$unsafe_report"; then
  fail "security report leaked fixture content"
fi

echo "PASS: AI security rule contract tests"
