# 2d — `companionAvailableProvider` staleness

**Goal:** If companion service drops after first successful check, UI stops claiming it's online.

## Current state

- `lib/core/providers.dart` — `companionAvailableProvider` is a `FutureProvider<bool>`. Resolves once, caches forever.
- Any UI that watches it (download buttons, settings chip, etc.) never re-checks.

## Problem

User notices stale "companion available" status when it actually went down.

## Proposal

Replace with one of:
- **(a) `StreamProvider`** that emits every 30 s when any watcher is subscribed.
- **(b) Keep `FutureProvider`** but invalidate on any companion-bound request failure, and add a periodic ping via a simple `Timer` owned by a `KeepAliveLink` holder.

Lean toward (a) — simpler, and Riverpod auto-disposes when no watchers.

## Open questions
- 30 s too aggressive? 60 s?
- Exponential backoff when it's down (don't hammer every 30 s if it's been down for an hour)?

## Files to touch
- `lib/core/providers.dart` — swap provider type.
- Any widget watching `companionAvailableProvider` (should just work — same boolean).

## Verification
- Start with companion up → toggle shows available.
- Stop companion → within ~30 s UI updates to unavailable.
- Restart companion → within ~30 s UI recovers.

## Status
- 2026-04-21: pending.
