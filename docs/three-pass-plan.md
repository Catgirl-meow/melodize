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
| 2a | Recommendations quality rewrite | [pass-2/2a-recommendations.md](pass-2/2a-recommendations.md) | ✅ shipped (multi-session) |
| 2b | Connection-error specificity on Home | [pass-2/2b-connection-errors.md](pass-2/2b-connection-errors.md) | ✅ shipped v1.9.6 |
| 2c | Download reliability + notifications | [pass-2/2c-download-reliability.md](pass-2/2c-download-reliability.md) | ✅ shipped v1.9.9 (timeout + connection-loss + re-failure snacks; OS-level notifications still future) |
| 2d | `companionAvailableProvider` staleness | [pass-2/2d-companion-freshness.md](pass-2/2d-companion-freshness.md) | ✅ shipped v1.9.6 |
| 2e | Auto-download `'all'` idempotency | [pass-2/2e-auto-download-idempotency.md](pass-2/2e-auto-download-idempotency.md) | ✅ shipped v1.9.6 |
| 2f | Mini-player + dock design fixes | [pass-2/2f-miniplayer-dock.md](pass-2/2f-miniplayer-dock.md) | shape/radius pass shipped in v1.8.4 — tiles + app bars still pending |
| 2g | Menu + visual-glitch triage | [pass-2/2g-menu-triage.md](pass-2/2g-menu-triage.md) | ✅ shipped v1.9.9 (song tile + now-playing menus get header + drag handle; library sorts + sleep timer fixed) |

**Standing visual-polish backlog:** [design-consistency.md](design-consistency.md) — drift across screens (app bars, cover radii, header typography, deprecated APIs). Pick from there during polish passes.

Current execution order (picked by user to benchmark Opus 4.7 on a meaty item first): **2a now**, remaining order TBD after.

### Features shipped outside the pass-2 plan

**v1.8.5 (2026-04-22)**
- **Downloaded songs overhaul** — live search (title/artist/album/genre/format), lossless/lossy filter, sort by name/artist/album/recently added (asc/desc); empty and no-results states.
- **Settings sub-pages** — Library server, Deezer, and Companion settings each moved to their own `_SettingsPageScaffold` sub-screen instead of being inline in the main settings scroll.

**v1.8.6–1.8.9 (2026-04-23 to 2026-04-26)**
- Vim keybinds no longer fire in text fields (Flutter 3.27 `visitAncestorElements` fix).
- Full artist detail screen: top songs (Subsonic), Deezer discovery tracks, all albums grid, all songs list, download album one-tap.
- Deezer two-pass artist search — `/search/artist` first (name-relevance), fallback `/search` with strict match; no more pop-biased first-result. Fixes bad recommendations.
- More Like This error on pull-to-refresh fixed — `_refresh` now clears the seed override.
- More Like This now prepends override as seed[0] with 3 history backup seeds; radio pool raised 10→20 for large libraries.

**v1.9.5 (2026-04-27)**
- **SliverAppBar.medium restored** — collapsing greeting back on Home; expanded state uses `headlineMedium bold` via `FlexibleSpaceBar`, collapsed state uses `titleLarge bold`. Previous removal (v1.9.3/1.9.4) was a regression fix workaround.
- **Staggered section entrance** — sections cascade in with 60 ms gaps (Playlists → Recently Added → Discover → Recs → Recently Played) instead of all animating simultaneously.
- **400 ms entrance duration** — up from 350 ms to match M3E spec; `Interval` curve bakes delay into tween.
- **Carousel trailing affordance** — padding changed from symmetric 16 px to leading-only 16 px; trailing partial card now visible as scroll hint.
- **Section header tracking** — `letterSpacing` tightened from `-0.1` to `-0.2` matching `titleLargeEmphasized` spec.
- **Card/banner radii** — error container, empty hint, Deezer expired banner all bumped 14 → 16 px (M3E medium shape token).

**v1.9.2–v1.9.4 (2026-04-27)**
- Three successive attempts to fix portrait carousel covers introduced by v1.9.0's `CarouselView`.
- Root cause: `CarouselView(shrinkExtent: 40)` passes tight width to edge items but loose height — explicit `size: 130` only controlled height. Fix: `AspectRatio(1.0)` wrapping every cover image forces `height = width` unconditionally.

**v1.9.1 (2026-04-26)**
- Cover art 1:1 ratio fix — `SizedBox.square` wrapping all carousel images.
- Greeting gap reduced — `SliverAppBar.large` → `SliverAppBar.medium`.
- Carousel taps fixed — tap handling moved to `CarouselView.onTap`; inner InkWells were swallowing gestures.

**v1.9.0 (2026-04-26)**
- `SliverAppBar.medium` collapsing greeting on Home (Pass 3 item 02 — Home ✅).
- All Home horizontal rows → `CarouselView` (160 px cards, snap-to-card).
- Section headers `titleLarge w700` (Pass 3 item 07 — Home section headers ✅).
- Section entrance: fade + 16 px upward slide, M3E emphasized-decelerate curve (Pass 3 item 06 — partial ✅).
- `DynamicSchemeVariant.expressive` on fallback `ColorScheme.fromSeed` (Pass 3 item 05 ✅).
- Error states: recs error uses `errorContainer`; server-unreachable → `ActionChip` with retry.
- Recs refresh button → `IconButton.filledTonal`; PREVIEW badge → `inverseSurface` tokens.
- Bottom sheet context menu adds song title/artist header.

---

## Pass 3 — Material 3 Expressive upgrade (later)

Driven entirely by `Material 3 Expressive Roadmap.html` (8 items, ~20 h total).

| # | Item | Priority | Est. | Status |
|---|------|----------|------|--------|
| 01 | Shape-morphing mini player | P0 | ~4 h | shipped, rework in Pass 2f |
| 02 | Large / medium `SliverAppBar` | P0 | ~3 h | ✅ Home done v1.9.0 — Library + Settings pending |
| 03 | Grouped settings tiles | P0 | ~2 h | shipped, visual pass in Pass 2f |
| 04 | Wavy progress + FAB shape morph | P1 | ~3 h | pending — Flutter 3.27+ |
| 05 | `DynamicSchemeVariant.expressive` | P1 | ~1 h | ✅ done v1.9.0 |
| 06 | Motion tokens | P1 | ~4 h | partial — Home stagger + 400 ms v1.9.5; codebase-wide pending |
| 07 | `displayLargeEmphasized` typography | P2 | ~2 h | partial — Home section headers tracking -0.2 v1.9.5; Now Playing title pending |
| 08 | Haptics (with opt-out preference) | P2 | ~1 h | pending |

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
