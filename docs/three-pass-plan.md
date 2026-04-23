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

## Pass 2 — Bug + design fixes (in progress)

Pass 2 is split into seven standalone sub-plans under [`docs/pass-2/`](pass-2/). Each file is self-contained: context, problem, proposal, open questions, files, verification. A fresh session can resume any sub-item by reading just that file.

| # | Topic | File | Status |
|---|-------|------|--------|
| 2a | Recommendations quality rewrite | [pass-2/2a-recommendations.md](pass-2/2a-recommendations.md) | in progress — awaiting user decisions |
| 2b | Connection-error specificity on Home | [pass-2/2b-connection-errors.md](pass-2/2b-connection-errors.md) | pending |
| 2c | Download reliability + notifications | [pass-2/2c-download-reliability.md](pass-2/2c-download-reliability.md) | pending |
| 2d | `companionAvailableProvider` staleness | [pass-2/2d-companion-freshness.md](pass-2/2d-companion-freshness.md) | pending |
| 2e | Auto-download `'all'` idempotency | [pass-2/2e-auto-download-idempotency.md](pass-2/2e-auto-download-idempotency.md) | pending |
| 2f | Mini-player + dock design fixes | [pass-2/2f-miniplayer-dock.md](pass-2/2f-miniplayer-dock.md) | shape/radius pass shipped in v1.8.4 — tiles + app bars still pending |
| 2g | Menu + visual-glitch triage | [pass-2/2g-menu-triage.md](pass-2/2g-menu-triage.md) | pending (needs screenshots) |

Current execution order (picked by user to benchmark Opus 4.7 on a meaty item first): **2a now**, remaining order TBD after.

### Features shipped outside the pass-2 plan (v1.8.5, 2026-04-22)
- **Downloaded songs overhaul** — live search (title/artist/album/genre/format), lossless/lossy filter, sort by name/artist/album/recently added (asc/desc); empty and no-results states.
- **Settings sub-pages** — Library server, Deezer, and Companion settings each moved to their own `_SettingsPageScaffold` sub-screen instead of being inline in the main settings scroll.

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
