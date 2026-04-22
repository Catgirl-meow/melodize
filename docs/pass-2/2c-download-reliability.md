# 2c — Download reliability + notifications

**Goal:** Server-side (companion) download flow stops being "glitchy"; every completion/failure surfaces a snackbar with actionable info; library refresh after a new song arrives isn't janky.

## Current state

User report (verbatim): *"Download on server is glitchy and notifications for is it working or not are sometimes not appearing and they don't give much info and library updates and janky."*

**Files:**
- `lib/shared/utils/download_polling_mixin.dart` — client-side polling loop.
- `lib/core/api/companion_client.dart` (grep/confirm exact path) — `startDownload` + `getDownloadStatus`.
- `lib/features/home/home_screen.dart:_RecommendationCardState._addToLibrary` — one call site.
- Similar call sites in search screen / now-playing (audit needed).
- `allSongsProvider` (`lib/core/providers.dart`) — emits on server refresh; Library list rebuilds wholesale → jank.

## Problems (hypothesized, verify during execution)

1. Polling loop may not survive widget disposal (navigate away while downloading → progress lost).
2. Errors from companion may be swallowed silently.
3. Companion job lifecycle unclear — no timeout, no resume after companion restart.
4. Library list rebuild on `allSongsProvider` emit: whole list re-lays-out rather than diffing changed items.

## Proposal (draft — confirm during execution)

- Audit `DownloadPollingMixin`: confirm it unsubscribes cleanly; move polling to a top-level `StateNotifier` so widgets just observe, not own.
- Ensure every terminal state (success, 4xx, 5xx, timeout) triggers `showStyledSnack` with the track title + concrete reason.
- Companion timeout: if status hasn't changed in N minutes, mark failed with "server didn't finish — check companion logs".
- Library diff-in-place: use `ListView.builder` with stable keys or Riverpod `select` to limit rebuilds.

## Open questions (for when 2c starts)
- Should downloads continue in the background if the user closes the app?
- Do we want an in-app "Downloads" view with active progress (already exists — verify quality)?
- Should we show a persistent notification for active server-side downloads (Android)?

## Files to touch
- `lib/shared/utils/download_polling_mixin.dart` → likely refactor or replace.
- Companion client wrapper.
- Screens that initiate downloads (home, search).
- Library list (`lib/features/library/...`).

## Verification
- Kick off 3 simultaneous downloads, navigate around app → all 3 complete with snackbars.
- Kill companion mid-download → client reports specific error within N seconds.
- New song arrives during browsing → item inserts without the whole list flashing.

## Status
- 2026-04-21: pending.
