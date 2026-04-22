# 2b — Connection-error specificity on Home

**Goal:** Replace the generic "Server unreachable — pull to retry" chip with one of several specific messages so the user knows what's actually wrong.

## Current state

- `lib/core/providers.dart` — `serverReachableProvider` (boolean, true/false).
- `lib/features/home/home_screen.dart:76–96` — renders one single chip when `isOnline && !serverReachable`.
- `SubsonicClient.ping()` returns `Future<bool>` — all error modes collapse to `false`.

## Problems

User: "Connection errors in home literally give 0 information on what exactly is wrong, it's just always offline."

Can't distinguish: no internet, DNS failure, connection refused, TLS failure, wrong password, HTTP 5xx, timeout. Each has a different remediation (settings vs network vs server vs retry).

## Proposal

Typed error enum wrapping the ping result:

```dart
enum ServerReachability {
  ok,
  noInternet,         // connectivity_plus says no network
  dnsFailure,         // DNS didn't resolve
  connectionRefused,  // socket refused
  tlsFailure,         // TLS handshake failed (bad cert, wrong protocol)
  authRejected,       // HTTP 401 / Subsonic auth error
  forbidden,          // HTTP 403
  serverError,        // HTTP 5xx
  timeout,            // request exceeded timeout
  unknown,            // anything else
}
```

`SubsonicClient.ping()` → `Future<ServerReachability>`. Dio `DioExceptionType` + exception-message inspection to classify.

`serverReachableProvider` → emits `ServerReachability`. Home chip switches on value with appropriate icon + text + CTA (e.g. "Update password in Settings" for `authRejected`).

## Open questions
- CTA for `authRejected` — deep-link into the setup screen, or just text?
- For `noInternet`, should the chip hide the whole Home content or just show at top?

## Files to touch
- `lib/core/api/subsonic_client.dart` — change `ping()` signature, classification logic.
- `lib/core/providers.dart` — adjust `serverReachableProvider`.
- `lib/features/home/home_screen.dart` — render per-state chip.
- `lib/shared/widgets/offline_banner.dart` — may benefit from the same enum.

## Verification
- Airplane mode → "No internet connection".
- Wrong URL → "Server not reachable (check URL)".
- Wrong password → "Login rejected — update in Settings".
- Server shut down → "Server not reachable" (connection refused, same bucket).

## Status
- 2026-04-21: pending (Pass 2 queue).
