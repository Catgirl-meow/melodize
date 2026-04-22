# 2e — Auto-download `'all'` idempotency

**Goal:** Stop the `ref.listen(allSongsProvider)` in `_StartupRouterState` from re-running a batch download on every emission.

## Current state

- `lib/main.dart` → `_StartupRouterState` listens on `allSongsProvider` (a `StreamProvider` that emits cache + fresh).
- Every emission → calls `_downloadAll` / `downloadBatch(songs)`.
- `downloadBatch` dedupes by song ID internally, so nothing breaks — but every emission still enumerates the full library list, compares, and no-ops. Wastes CPU, flashes UI.

## Problem

Audit observation (not a user report, but worth fixing). On boot:
- Emission 1: cached library (hit DB).
- Emission 2: fresh server response.
→ `_downloadAll` runs twice.

With "auto-download all" enabled, this happens on every app start for a library of N songs.

## Proposal

Compute a signature of the emitted song-ID set; store last signature in `_StartupRouterState`; skip `_downloadAll` if unchanged.

```dart
final sig = Object.hashAll(songs.map((s) => s.id));
if (sig == _lastAutoDlSig) return;
_lastAutoDlSig = sig;
_downloadAll(songs);
```

## Open questions
- None material.

## Files to touch
- `lib/main.dart` — `_StartupRouterState`.

## Verification
- Log `_downloadAll` entries before/after: should see 1 call per real library change, not 2+ per launch.

## Status
- 2026-04-21: pending.
