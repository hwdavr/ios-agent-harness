# Runtime Observability Rules

## Log Format

All log calls must use `os.Logger` with a consistent subsystem:

```swift
import os

extension Logger {
    static let app = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.example.app", category: "App")
    static let network = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.example.app", category: "Network")
    static let database = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.example.app", category: "Database")
}

// Usage
Logger.app.info("HomeScreen appeared")
Logger.network.error("Request failed: \(error.localizedDescription)")
```

- Use `Bundle.main.bundleIdentifier` for the subsystem — this is mandatory for Console.app filtering.
- Never log PII (email, user ID, user-generated sensitive content) at any level.

---

## Log Levels

| Level | When to use | Example |
|-------|-------------|---------|
| `debug` | Development-time detail — stripped in release | Parsed response body, ViewModel state snapshot |
| `info` | Significant lifecycle events | Screen opened, user action confirmed |
| `notice` / `warning` | Recoverable anomaly — worth investigating | Cache miss, retry attempt, empty API response |
| `error` | Non-recoverable failure — always investigate | Exception caught, API 5xx, DB write failed |
| `fault` | System-level unrecoverable error | Data corruption, forced termination |

---

## What to Check When Debugging

**API / Network**
- Subsystem: `Network`
- Look for: HTTP status code, request URL, response body (truncated), retry count
- Common signals: `401` → token expired · `404` → wrong endpoint · timeout → connectivity

**SwiftData / Database**
- Enable Core Data / SwiftData debug logging via `-com.apple.CoreData.SQLDebug 1` launch argument
- Look for: SQL statement executed, row count returned, transaction open/close
- Common signals: `0 rows` → query mismatch · constraint violation → unique/FK violation

**ViewModel / State**
- Subsystem: `App`
- Look for: UI state transitions, async task lifecycle
- Common signals: state stuck in `loading` → upstream task never completes · `error` state → check cause message

**Navigation**
- Subsystem: `App`
- Look for: route values, navigation path depth
- Common signals: blank screen → missing `navigationDestination` · crash → wrong route type

**Repository / Cache**
- Subsystem: `App`
- Look for: cache hit/miss, data-source selected (local vs remote), sync trigger
- Common signals: stale data → cache not invalidated · repeated network calls → no cache write

---

## Filtering in Console.app

- Open Console.app → filter by `subsystem:` with your bundle identifier
- Use `category:` to filter to specific subsystems (Network, Database, App)
- Enable debug logging per-category to see detailed output during development