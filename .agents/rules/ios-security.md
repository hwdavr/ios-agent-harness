# iOS Security Code Rules

## Purpose and Scope

These rules define the mandatory security baseline for iOS code that crosses a
trust boundary. Apply them whenever a change handles authentication or session
data, local sensitive data (Keychain, UserDefaults, CoreData, SwiftData), URL schemes
or Universal Links, files, App Groups or IPC, networking/TLS/App Transport Security,
`WKWebView`, third-party packages or SDKs, AI/model input or output, rendering, or
release/build security settings.

This is a conditional cross-cutting rule that forms the tenth row (`SEC`) in the
ten-rule Rule Applicability matrix. When a change touches one of the boundaries
above, record `SEC: Required` and the relevant evidence in the plan/review. When
none apply, record `SEC: Not applicable — no iOS security boundary is changed`.

## Trust-Boundary Invariants

### 1. Treat external input as hostile

- Treat user text, backend responses, model output, custom URL schemes, Universal
  Links, pasteboard data, navigation route arguments, file metadata, and external file
  or remote URLs as untrusted.
- Validate type, size, encoding, scheme, host, MIME type, and allowed values before
  use. Prefer bounded fields and explicit allow-lists over best-effort filtering.
- Reject malformed, blank, oversized, unknown, or ambiguous values and use a
  deterministic safe fallback. Do not turn validation failures into privileged
  navigation or data access.

### 2. Protect secrets and private content

- Never hardcode API keys, credentials, access/refresh/ID tokens, or signing
  material in source code. Keep environment-specific values in `.xcconfig` and
  `Info.plist` / `BuildConfig` without committing secrets.
- Never log, send to analytics, include in error messages, or expose in UI
  diagnostics: credentials, tokens, full note content, prompts, model output, PII,
  or sensitive identifiers. Redact before telemetry or crash reporting (`os.Logger`,
  `os_log`, `print`, `NSLog`).
- Store tokens and highly sensitive local data in the Keychain with appropriate
  accessibility attributes (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`); clear
  in-memory and persisted session state on logout. Review App Switcher previews,
  notifications, clipboard, and sharing extensions for accidental disclosure.

### 3. Enforce network and transport security

- Production traffic must use HTTPS and satisfy App Transport Security (ATS).
  Never set `NSAllowsArbitraryLoads = true` or use blanket ATS bypasses in `Info.plist`.
- Any development or domain-specific exception must be narrowly scoped, documented,
  approved, and excluded from release configuration. Never trust invalid TLS
  certificates or disable certificate validation in production.
- A UI-test-only cleartext endpoint is permitted only when the launch is explicitly
  gated by `-UITesting`, the URL is allow-listed to `127.0.0.1` or `[::1]` with a
  valid port, and invalid or missing configuration fails closed to an unreachable
  loopback endpoint. It must never fall back to the live production API.
- Validate and map remote payloads before domain/UI use; do not let transport
  success imply authorization.

### 4. Keep WKWebView and rendered content least-privileged

- Avoid `WKWebView` unless required. For untrusted or inline content, keep
  `allowsContentJavaScript = false` unless a documented product requirement proves it
  necessary and the web view is sandboxed with a non-persistent website data store.
- Never set `allowFileAccessFromFileURLs = true` or `allowUniversalAccessFromFileURLs = true`.
- Implement `WKNavigationDelegate`'s `decidePolicyFor navigationAction:` to restrict
  navigation to declared, safe bundle resources or schemes; reject arbitrary external
  navigation.
- Do not pass untrusted model or user content directly to `evaluateJavaScript` or HTML
  sinks such as `innerHTML`.
- Mermaid or other diagram renderers must use strict security mode (`securityLevel: 'strict'`)
  and sanitize or bound source text before rendering. Never use a loose security mode.

### 5. Minimize iOS IPC, URL Scheme, and Extension exposure

- Custom URL schemes and Universal Links require strict parameter validation and
  must not invoke privileged actions without active user confirmation or session
  re-authentication.
- Validate incoming values before accessing data or entering privileged flows.
- Scope App Groups, Keychain access groups, and shared containers to the minimum
  required entitlement.

### 6. Constrain AI/model boundaries

- Bound every prompt field and clearly delimit untrusted user, note, backend, or
  file content before it reaches a model. Do not include secrets or unnecessary
  private content.
- Treat model responses as untrusted data. Accept only an exact, typed, allow-listed
  result; reject prose, markup, unknown values, blank values, and oversized output.
  Use a deterministic fallback and isolate requests so one request cannot influence
  another.
- Do not add an external model/service, upload private content, or expose model
  prompts without an explicit product and security review.

### 7. Harden release configuration and dependencies

- Release builds must not contain staging endpoints, debug inspector overlays, test
  hooks, or verbose sensitive logging.
- Audit third-party Swift packages, SDK collection, permissions, and transitive
  dependencies before adoption. Disable unnecessary tracking or telemetry.

## Required Evidence and Enforcement

For a change marked `SEC: Required`:

1. Explain the affected trust boundary and the validation, least-privilege, and
   failure behavior in the implementation/review evidence.
2. Add unit/integration tests for validation, redaction, secure fallback, malformed
   URL/file/backend input, or authentication failures as applicable.
3. Add a real UI or runtime boundary test for platform behavior such as `WKWebView`,
   custom URL handling, Keychain access, or permission/security state.
4. Run the canonical source gate from the project root:

   ```bash
   bash harness/scripts/check-full-source-rules.sh
   ```

   The bundle invokes `check-ai-security-rules.sh` and its negative-case contract
   test. The evaluator mechanically rejects ATS cleartext, unsafe `WKWebView` or
   Mermaid settings, AI-input logging, and direct untrusted HTML sinks; it does not
   replace human review of storage, IPC, permissions, or release settings.
5. Also run `swiftlint`, build validation, and applicable contract/gate checks.
   Do not suppress a finding, add a broad exclusion, or disable rules to make a
   security check pass. Fix the root cause or document an explicitly approved
   false positive.

## Out of Scope

Backend-only controls (e.g. CSP headers, HSTS, server-side rate limiting), formal
compliance certification, and penetration testing require their own owners and review.
They do not waive these client-side rules.
