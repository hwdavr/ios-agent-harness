---
name: security-and-hardening
description: Harden iOS security and privacy boundaries for untrusted input, Keychain, ATS, WKWebView, and SDKs.
---

# Security and Hardening

Authoritative project code constraints are defined in `.agents/rules/ios-security.md`. Use this skill for threat modeling, architectural checklists, and hardening guidance; do not contradict the code rule.

## Overview

Security-first development practices for iOS applications. Treat every external input as untrusted, every token as sensitive, every entry surface as a security boundary, and every persisted secret as a liability. Security is not a later review step. It constrains storage, networking, Info.plist design, SDK integrations, and UI behavior from the start.

## Governing Rule

Before applying this skill, load `.agents/rules/ios-security.md` whenever the
change touches one of its iOS trust boundaries. That rule is the authoritative
baseline and evidence contract; this skill provides the operational guidance and
must not weaken, suppress, or replace it.

## When to Use

- Handling auth tokens, refresh tokens, credentials, or user sessions
- Storing sensitive data locally (Keychain vs SwiftData/UserDefaults)
- Adding Universal Links, custom URL schemes, or App Clip entry points
- Handling incoming URL requests (`onOpenURL`, `scene(_:openURLContexts:)`) from outside the process
- Opening files, attachments, camera/photo picker, or security-scoped URLs
- Adding or modifying `WKWebView`
- Integrating third-party SDKs, analytics, crash reporters, or external APIs
- Handling PII, financial data, or regulated data
- Making build, `.xcconfig`, entitlements, or `Info.plist` (ATS, permission usage descriptions) changes

## iOS Security Boundaries

### Always Do

- Validate all external input from Universal Links, custom URL schemes, backend payloads, and file metadata
- Store tokens, credentials, and sensitive local secrets in Keychain Services with appropriate accessibility attributes
- Use HTTPS for production traffic and enforce App Transport Security (ATS) by default
- Apply least privilege for `Info.plist` privacy usage descriptions (`NSCameraUsageDescription`, etc.)
- Redact tokens, secrets, credentials, and sensitive identifiers from `os.Logger`
- Review `Info.plist`, `.xcconfig`, and entitlements changes for security impact
- Keep dependencies and Swift packages updated and review known vulnerabilities before release

### Ask First

- Adding a new custom URL scheme or Universal Link domain
- Adding or changing authentication/session flows
- Storing new categories of sensitive local data
- Adding `WKWebView`, JavaScript message handlers, or arbitrary URL loading
- Relaxing ATS validation, adding exception domains, or allowing arbitrary loads
- Adding certificate pinning
- Introducing new third-party SDKs that collect user/device data
- Requesting new system permissions or Background Modes

### Never Do

- Never hardcode API keys, client secrets, tokens, or credentials in source code
- Never log passwords, access tokens, refresh tokens, session secrets, or full PII via `os.Logger` or `print()`
- Never trust client checks as sole authorization
- Never store auth tokens or private user credentials in `UserDefaults` or plaintext files
- Never enable `NSAllowsArbitraryLoads = true` for convenience
- Never use unrestricted `WKWebView` settings against untrusted content
- Never assume file extensions or MIME declarations are trustworthy without validation

---

## Core Threat Areas

### 1. Input Validation at iOS Boundaries

- Validate IDs, enum values, route params, and user-entered fields before use
- Validate all incoming URL query items and path components before navigation or data fetch
- Treat backend responses as untrusted until parsed and mapped
- Constrain URL schemes, hosts, MIME types, and file sizes

### 2. Local Data Protection

- Use Keychain Services (`Security.framework`) for tokens and credentials
- Avoid plaintext storage in `UserDefaults`, SwiftData, or unencrypted local files for sensitive credentials
- Set appropriate accessibility levels (e.g. `kSecAttrAccessibleAfterFirstUnlock`)
- Clear sensitive state on logout
- Exclude sensitive caches from iCloud backup via `.isExcludedFromBackup`
- Avoid placing secrets in pasteboard, notifications, widgets, or screen captures

### 3. Auth and Session Handling

- Keep tokens out of logs, exceptions, analytics, and navigation paths
- Clear both in-memory and Keychain auth state on logout
- Treat refresh-token rotation as sensitive infrastructure
- Fail closed when auth state is missing, malformed, or expired

### 4. App Extensions and IPC Boundaries

- Validate data crossing App Group shared containers
- Use Keychain access groups intentionally with minimal sharing
- Validate all incoming URLs from `onOpenURL` before taking action

### 5. Universal Links and Navigation

- Treat every incoming URL parameter as untrusted
- Validate destination eligibility before entering privileged flows
- Do not navigate directly into sensitive screens without auth and state checks
- Ensure malformed or unexpected URLs fail safely without crash or unauthorized navigation

### 6. Network Hardening

- Use HTTPS only for production endpoints
- Enforce App Transport Security (ATS) in `Info.plist` without broad exceptions
- Validate backend payloads before domain/UI mapping
- Be explicit about retry and fallback behavior on auth and transport failures

### 7. WKWebView Safety

- Avoid `WKWebView` unless it is genuinely needed
- Keep JavaScript execution isolated; never register JavaScript message handlers that execute untrusted native actions
- Restrict file access from file URLs (`allowFileAccessFromFileURLs = false`)
- Do not load arbitrary user-provided URLs without strict allowlisting

### 8. File and Sandbox Handling

- Operate within the app's sandboxed directories (`Documents`, `Caches`, `Application Support`)
- Use security-scoped bookmarks when accessing user-selected external documents
- Validate file sizes and paths before processing attachments
- Sanitize paths against directory traversal (`../`)

### 9. Third-Party SDK Data Minimization

- Review what data the SDK collects, stores, and transmits
- Disable unnecessary telemetry, advertising identifiers, or auto-logging
- Do not send auth tokens or sensitive note content to SDKs without explicit approval

---

## iOS Release Hardening

### Configuration and Entitlements

- Keep sensitive build configuration in `.xcconfig` files excluded from version control or properly secured
- Use Release build configurations with optimization enabled (`-O`)
- Review app entitlements to ensure only required capabilities are enabled
- Verify code signing certificates and provisioning profiles match release targets

### TLS and Certificate Pinning

Use selectively for high-sensitivity traffic or environments with explicit MITM-resistance requirements.

- Enforce HTTPS for production traffic
- Add certificate pinning only with an agreed certificate rotation plan
- Prefer designs that support backup pins and controlled migration
- Document the expected failure behavior before shipping pinning
- Do not add pinning casually; broken pinning creates production outages
