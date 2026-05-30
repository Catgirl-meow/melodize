# Melodize — Three-Pass Plan

## Overview

1. **Pass 1** — Docs + dead-code cleanup ✅
2. **Pass 2** — Bug fixes + design fixes for shipped-but-rough features
3. **Pass 3** — Material 3 Expressive upgrade, driven by `Material 3 Expressive Roadmap.html`

**Out of scope:** Star/favourite songs, CarPlay/Android Auto.

**Recommendations direction:** Show *new* music the user doesn't already have via Deezer. `SubsonicClient.getSimilarSongs` stays unwired.

---

## Pass 1 — Docs + dead-code cleanup ✅

- Rewrote `README.md` Features + Roadmap
- Removed dead code: `AppDatabase.saveQueue`/`getSavedQueue` + `QueueEntries` table, `AppDatabase.getPendingDownloads`, `SubsonicClient.getStarredSongs`/`starSong`/`unstarSong`
- Drift schema v3 → v4, regenerated `database.g.dart`
- Kept `floating_mini_player.dart` — reachable via `mini_player.dart` when `preferences.floatingNavBar` is on

---

## Pass 2 — Bug + design fixes

Each sub-plan is self-contained under [`docs/pass-2/`](pass-2/).

| # | Topic | File | Status |
|---|-------|------|--------|
| 2a | Recommendations quality rewrite | — | ✅ shipped |
| 2b | Connection-error specificity on Home | — | ✅ shipped v1.9.6 |
| 2c | Download reliability + notifications | — | ✅ shipped v1.9.9 |
| 2d | `companionAvailableProvider` staleness | — | ✅ shipped v1.9.6 |
| 2e | Auto-download `'all'` idempotency | — | ✅ shipped v1.9.6 |
| 2f | Mini-player + dock design fixes | [pass-2/2f-miniplayer-dock.md](pass-2/2f-miniplayer-dock.md) | shape/radius shipped v1.8.4 — tiles + app bars pending |
| 2g | Menu + visual-glitch triage | — | ✅ shipped v1.9.9 |
| 2h | Smart shuffle + playback architecture rework | [pass-2/2h-playback-architecture.md](pass-2/2h-playback-architecture.md) | ✅ implemented May 2026 |
| 2i | Queue screen reorder FPS + stability | — | ✅ shipped v1.10.x |
| 2j | Companion cache guard + deterministic shuffle seed | — | ✅ shipped v1.10.3 |

**Visual-polish backlog:** [design-consistency.md](design-consistency.md)

### Notable out-of-plan shipments

- **v1.8.5** — Downloaded songs overhaul (search, filter, sort); Settings sub-pages
- **v1.8.6–1.8.9** — Artist detail screen; Deezer two-pass artist search; More Like This fixes
- **v1.9.0–v1.9.5** — SliverAppBar.medium, CarouselView, M3E entrance animations, `DynamicSchemeVariant.expressive`, section header tracking
- **v1.10.x–v1.11.0** — Queue screen rewrite (`SliverReorderableList` + scoped rebuilds, reorder crash fix, paused equalizer, transition pills, correct shuffle ordering in queue view); companion cache guard + deterministic shuffle seed; comprehensive smart shuffle test suite

---

## Pass 3 — Material 3 Expressive upgrade

Driven by `Material 3 Expressive Roadmap.html`.

| # | Item | Priority | Status |
|---|------|----------|--------|
| 01 | Shape-morphing mini player | P0 | shipped — rework in Pass 2f |
| 02 | Large / medium `SliverAppBar` | P0 | reverted on Home v1.9.9; Library + Settings pending |
| 03 | Grouped settings tiles | P0 | shipped — visual pass in Pass 2f |
| 04 | Wavy progress + FAB shape morph | P1 | pending |
| 05 | `DynamicSchemeVariant.expressive` | P1 | ✅ v1.9.0 |
| 06 | Motion tokens | P1 | partial — Home stagger v1.9.5 |
| 07 | `displayLargeEmphasized` typography | P2 | partial — Home headers v1.9.5 |
| 08 | Haptics (opt-out pref) | P2 | pending |

Pass 3 starts after Pass 2 stabilizes.
