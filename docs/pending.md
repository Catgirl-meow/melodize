# Pending Work

Consolidated from `docs/three-pass-plan.md` and `docs/design-consistency.md` (both deleted — superseded by this file).

Status: ❌ open · 🟡 partial · ✅ shipped

---

## App bars — M3E item 02 (P0)

| ID | Surface | Current | Target | Status |
|----|---------|---------|--------|--------|
| P1 | `lib/features/library/library_screen.dart:116` | plain `AppBar` + `TabBar` | `SliverAppBar.medium` w/ TabBar as `bottom` in `CustomScrollView` per tab | ❌ |
| P2 | `lib/features/settings/settings_screen.dart` (`_SettingsPageScaffold`) | plain `AppBar` | `SliverAppBar.medium` for sub-pages | ❌ |
| P3 | `lib/features/downloads/downloads_screen.dart:36` | plain `SliverAppBar` (no variant) | `SliverAppBar.medium` | ❌ |
| P4 | `lib/features/settings/downloaded_songs_screen.dart:245` | plain `AppBar` | `SliverAppBar.medium` (already has scroll) | ❌ |
| P5 | `lib/features/home/home_screen.dart` | inline `SliverToBoxAdapter` + `SafeArea(top:true)` greeting | revisit M3E medium/large variant | 🟡 reverted v1.9.9 |

**Lesson from Home (v1.9.9):** M3 medium/large `SliverAppBar` puts title *bottom-aligned* inside expanded slot. Default expanded height 112 px + Android status bar ~32 px = ~144 px tall bar with title at bottom → ~100 px gap above greeting. `expandedHeight: 88` halves it. Future re-attempt must either (a) override title vertical alignment in flexible space, or (b) accept gap as M3E spec.

---

## Pass 2f — Mini-player + dock design fixes

Remaining after v1.8.4 shape/radius pass:
- Tile polish (app bars pending — see P1–P5 above)
- Remaining app bar + tile visual alignment

---

## Cover art & radii

| ID | File | Issue | Status |
|----|------|-------|--------|
| P6 | `lib/shared/widgets/song_tile.dart:84` (`_QualityBadge`) | `ClipRRect` radius **4** — different shape token than everything else | ❌ |

---

## Typography — detail headers (P1)

| ID | File | Issue | Status |
|----|------|-------|--------|
| P7 | `lib/features/library/album_detail_screen.dart:54` | Title hardcoded `fontSize: 20, FontWeight.bold` — should use `theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)` | ❌ |
| P8 | `lib/features/library/playlist_detail_screen.dart:54` | Same | ❌ |
| P9 | `lib/features/library/artist_detail_screen.dart` (header) | Same pattern, verify | ❌ |

### M3E item 07 — displayLargeEmphasized typography (P2)

| ID | Detail | Status |
|----|--------|--------|
| P10 | Home section headers tracking -0.2 shipped v1.9.5 | ✅ done |
| P11 | Now Playing screen title styling | 🟡 partial |

---

## Motion / animation — M3E item 06 (P1)

| ID | Detail | Status |
|----|--------|--------|
| P12 | Home stagger + 400 ms entrance (shipped v1.9.5) | ✅ done |
| P13 | Codebase-wide motion token adoption | ❌ pending |

---

## M3E remaining items

| # | Item | Priority | Detail | Status |
|---|------|----------|--------|--------|
| 02 | Large/medium `SliverAppBar` | P0 | See P1–P5 above | 🟡 partial |
| 04 | Wavy progress + FAB shape morph | P1 | Flutter 3.27+ pending | ❌ |
| 06 | Motion tokens codebase-wide | P1 | See P12–P13 | 🟡 partial |
| 07 | `displayLargeEmphasized` typography | P2 | See P10–P11 | 🟡 partial |
| 08 | Haptics (opt-out pref) | P2 | Not started | ❌ |

---

## Paddings & rhythm (P2)

| ID | Issue | Status |
|----|-------|--------|
| P14 | Sort sheet header padding: `fromLTRB(16, 16, 16, 8)` in library vs `fromLTRB(16, 10, 8, 4)` in top row — pick one | ❌ |
| P15 | Section-header → content gap: Home 12 px, Library tabs 4 px. M3E spec 16 px | ❌ |
| P16 | Sleep timer sheet: manual `Material(borderRadius: 28)` instead of default sheet theme | ❌ |

---

## P3 — low priority

| ID | Issue | Status |
|----|-------|--------|
| P17 | Setup screen radii (14 / 20 in places) — onboarding only, low visibility | ❌ optional |

---

## Conventions (lock in to prevent drift)

- Cover thumbs: always `CoverArtImage` (default radius 8). Use `externalUrl:` for non-Subsonic.
- Detail header title: `theme.textTheme.titleLarge` + `fontWeight: bold`. No raw `fontSize:`.
- Card / banner radii: 16 (M3E medium shape). Already in `cardTheme`.
- Bottom sheets: rely on default sheet theme (28 dp top corners). No manual `Material(borderRadius:)`.
- Top-of-screen app bar: `SliverAppBar.medium` for tab roots; full-bleed `SliverAppBar` w/ `flexibleSpace` only for cover-art detail screens.
- Color overlays: `.withValues(alpha:)`, never `.withOpacity()`.
