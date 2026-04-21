# Melodize — Three-Pass Recovery Plan

> Authoritative, in-repo copy of the recovery roadmap. Mirrors `/home/catgirl/.claude/plans/hazy-napping-walrus.md`. Any session opening this repo should read this file first.

## Context

The project accumulated drift while a smaller model was driving. Docs diverged from code, some features landed undocumented, some TODOs were quietly completed, some code went dead, and chunks of the Material 3 Expressive design attempt landed half-baked. The user's explicit plan is a three-pass recovery.

**User priorities (in order):**
1. **Pass 1** — Docs + dead-code cleanup. *(completed 2026-04-21)*
2. **Pass 2** — Bug fixes + design fixes for items already shipped but implemented poorly.
3. **Pass 3** — Material 3 Expressive upgrade, driven by `Material 3 Expressive Roadmap.html` at repo root.

**User dislikes (do NOT put on roadmap):**
- Star / favourite songs feature.
- CarPlay / Android Auto.

**User permissions:**
- Structural / architectural rewrites are OK when something is implemented poorly, provided (a) existing features keep working and (b) the reasoning is explained to the user before the rewrite lands.

**Recommendations direction (important):**
- User wants recommendations to show **NEW and relevant** music they don't already have — NOT library-similar songs.
- `SubsonicClient.getSimilarSongs` (Navidrome/Last.fm similar) is therefore the *wrong* source; keep it unwired. Deezer stays primary; quality improvements in Pass 2.

---

## Pass 1 — Docs + dead-code cleanup ✅

Done on 2026-04-21. Summary:

- **Docs rewritten:** `README.md` Features + Roadmap, `memory/project_overview.md`, this file created.
- **Dead code removed:**
  - `AppDatabase.saveQueue` / `getSavedQueue` + `QueueEntries` table (zero call sites). Queue persistence is a future feature; re-add the table with a real migration when it lands.
  - `AppDatabase.getPendingDownloads` (zero call sites). `upsertDownload` / `updateDownloadStatus` / `deleteDownload` kept — useful for Pass 2 download reliability work.
  - `SubsonicClient.getStarredSongs` / `starSong` / `unstarSong` (user has ruled out the feature).
- **Drift schema:** v3 → v4 via `DROP TABLE IF EXISTS queue_entries` in migration. `build_runner` re-ran to regenerate `database.g.dart`.
- **Verified NOT dead:** `lib/features/player/widgets/floating_mini_player.dart` — reachable via `mini_player.dart:6,28` when `preferences.floatingNavBar` is on. Kept.

---

## Pass 2 — Bug + design fixes (next session)

Each sub-item lists current state, what's wrong, and target behavior. Suggested order by priority. Architectural rewrites permitted per user policy.

### 2a. Recommendations quality

Current state: `lib/core/providers.dart` (`recommendationsProvider`), `lib/core/api/deezer_client.dart` (`getRecommendations`).

Problems:
- Seeds are random 5–10 from last 30 history entries. No artist-diversity enforcement on the seed set.
- Seed fetches are sequential, one HTTP round-trip per seed. Slow.
- `DeezerClient.search` picks `tracks.first` — fails on common names (wrong artist → wrong radio).
- Library cross-check is exact-title equality — misses remixes, covers, `(Remastered)` etc.
- Silent empty on any failure — UI can't distinguish "nothing found" from "network error" from "no history yet".

Target (Deezer stays primary, **do not** wire `getSimilarSongs`):
- Parallel seed fetches via `Future.wait`.
- Pick Deezer artist by best fuzzy match on artist name across the first N search hits.
- Enforce artist diversity: max 2 tracks per artist in the final list.
- Grow candidate pool (40+) → shuffle → take 20.
- Surface failure reasons in the UI (not just an empty section).
- Improve library cross-check: strip `(Remastered)`, `feat. X`, parenthetical suffixes before comparison.
- Re-check cache policy — `autoDispose` may be causing churn on navigation.

### 2b. Connection-error specificity on Home

Current: single chip "Server unreachable — pull to retry" for every failure mode. User specifically complained.

Target: differentiate at the `SubsonicClient` level and surface distinct chips:

| Condition | Message |
|-----------|---------|
| No network at all | No internet connection |
| DNS / connection refused | Server not reachable (check URL) |
| TLS handshake failure | Server TLS error |
| HTTP 401 | Login rejected — update password in Settings |
| HTTP 403 | Access forbidden |
| HTTP 5xx | Server error — try again |
| Timeout | Server slow or unreachable |

Likely implementation: wrap ping result in a typed error enum, plumb through `serverReachableProvider`, render with matching icon + CTA.

### 2c. Download reliability + notifications

User: "Download on server is glitchy and notifications … sometimes not appearing and they don't give much info and library updates and janky."

Target:
- Audit `DownloadPollingMixin` — confirm the polling loop survives widget disposal and communicates progress.
- Every completion / failure path surfaces a snackbar with actionable info (track title, error reason).
- Companion-side: double-check job lifecycle (`startDownload` → `getDownloadStatus`); add resumption / timeout handling.
- Library refresh jank: `allSongsProvider` emits twice (cache + fresh) causing list reconciliation work. Diff in place vs replace wholesale.

### 2d. `companionAvailableProvider` staleness

`FutureProvider` resolves once then stays. If companion drops, UI keeps showing it online. Fix: `StreamProvider` with periodic re-check when companion-dependent UI is mounted, or invalidate on any companion error.

### 2e. Auto-download `'all'` idempotency

`ref.listen(allSongsProvider)` in `_StartupRouterState` fires on every emission. `downloadBatch` dedupes so no harm, but wastes CPU on cache/fresh cycles. Guard with a signature check (hash of song-ID list).

### 2f. Mini-player + dock design fixes

User: "Horrible design in some places like mini player, menus and some other stuff … new dock which is partly horrible. The old dock can be btw enabled in settings."

Investigate:
- `FloatingMiniPlayer` vs `_ClassicMiniPlayer` (in `mini_player.dart`). Reconcile shape-morph treatment so both variants feel coherent.
- Shape-morph item 01 from M3 Expressive roadmap landed with radius 28 ↔ 10 on play/pause and a thumbnail morph. User says "partly horrible". Review radius choice, curve, and how it meshes with the floating dock geometry.
- Item 02 app-bar (`SliverAppBar.large/medium`) — review Home / Library / Settings. Recent commits removed a SliverAppBar gap but the architecture may still be wrong.
- Item 03 grouped settings tiles (v1.7.36) — needs a visual pass.

### 2g. Menu + visual-glitch triage

Broad "menus look bad / visual glitches". In Pass 2 session, ask the user for specific screens or screenshots, then iterate per-screen.

### Verification (Pass 2)
- Each sub-item gets its own acceptance criteria when executed.
- Device install + manual QA on each touched surface.

---

## Pass 3 — Material 3 Expressive upgrade (later)

Driven entirely by `Material 3 Expressive Roadmap.html` (8 items, ~20 h total).

| # | Item | Priority | Est. | Status |
|---|------|----------|------|--------|
| 01 | Shape-morphing mini player | P0 | ~4 h | shipped, rework in Pass 2f |
| 02 | Large / medium `SliverAppBar` | P0 | ~3 h | shipped, rework in Pass 2f |
| 03 | Grouped settings tiles | P0 | ~2 h | shipped, visual pass in Pass 2f |
| 04 | Wavy progress + FAB shape morph | P1 | ~3 h | new — Flutter 3.27+ |
| 05 | `DynamicSchemeVariant.expressive` | P1 | ~1 h | new |
| 06 | Motion tokens | P1 | ~4 h | new — codebase-wide refactor |
| 07 | `displayLargeEmphasized` typography | P2 | ~2 h | new |
| 08 | Haptics (with opt-out preference) | P2 | ~1 h | new |

Pass 3 starts after Pass 2 stabilizes. The HTML roadmap has per-item Claude Code prompts ready to paste.

---

## Out of scope (deferred indefinitely per user)
- Star / favourite songs.
- CarPlay / Android Auto.

---

## Persistence strategy

So this plan survives session restarts:
- **This file** in the repo at `docs/three-pass-plan.md` (single source of truth).
- Mirror at `/home/catgirl/.claude/plans/hazy-napping-walrus.md` (updated after each pass).
- `memory/project_overview.md` in auto-memory points here.
- `MEMORY.md` index has a line pointing to `project_overview.md`.

Fresh sessions: read this file + `memory/project_overview.md` before proposing changes.
