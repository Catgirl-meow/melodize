# Design Consistency Backlog

Audited 2026-04-27. Things that drift from M3E spec or from each other across screens. Pick from this list when doing visual-polish passes — none are blocking bugs.

Status legend: ❌ open · 🟡 partial · ✅ shipped

---

## P0 — visible gaps vs M3E roadmap item 02 (large/medium app bars)

| ID | Surface | Current | Target | Status |
|----|---------|---------|--------|--------|
| C1 | `lib/features/library/library_screen.dart:116` | plain `AppBar` + `TabBar` | `SliverAppBar.medium` w/ TabBar as `bottom`, in a `CustomScrollView` per tab | ❌ |
| C2 | `lib/features/settings/settings_screen.dart:817` (`_SettingsPageScaffold`) | plain `AppBar` | `SliverAppBar.medium` for sub-pages | ❌ |
| C3 | `lib/features/downloads/downloads_screen.dart:36` | plain `SliverAppBar` (no variant) | `SliverAppBar.medium` | ❌ |
| C4 | `lib/features/settings/downloaded_songs_screen.dart:245` | plain `AppBar` | `SliverAppBar.medium` (this screen has its own scroll already) | ❌ |
| — | `lib/features/home/home_screen.dart:118` | `SliverAppBar.medium` | — | ✅ v1.9.5 |

Album / Artist / Playlist detail screens use a deliberate full-bleed cover-art `SliverAppBar` with `flexibleSpace`. Keep as-is (intentional pattern).

## P1 — cover art radius drift

`CoverArtImage` default `borderRadius: 8`. Other places re-implement clipping with different radii, so 48-px thumbs look different per screen.

| ID | File | Issue |
|----|------|-------|
| C5 | `lib/shared/widgets/deezer_track_tile.dart:67,114` | Reimplements `ClipRRect` + `CachedNetworkImage` with radius **6** instead of using `CoverArtImage(externalUrl:)` (radius 8). Used in search results + artist page. ❌ |
| C6 | `lib/shared/widgets/song_tile.dart:84` (`_QualityBadge`) | Radius **4** — different shape token vs everything else around it. Could use 6 or theme's small shape. ❌ |

Fix C5 by routing the tile through `CoverArtImage` (it already supports `externalUrl`). Removes duplicate cache/placeholder logic too.

## P1 — typography inconsistency on detail headers

| ID | File | Issue |
|----|------|-------|
| C7 | `lib/features/library/album_detail_screen.dart:54` | Title hardcoded `fontSize: 20, FontWeight.bold` — should be `theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)`. ❌ |
| C8 | `lib/features/library/playlist_detail_screen.dart:54` | Same. ❌ |
| C9 | `lib/features/library/artist_detail_screen.dart` (header) | Same pattern, verify before fix. ❌ |

## P2 — deprecated API on detail gradient overlays

`.withOpacity(0.9)` deprecated in newer Flutter. Replace w/ `.withValues(alpha: 0.9)`.

| ID | File:line |
|----|-----------|
| C10 | `lib/features/library/album_detail_screen.dart:41` |
| C11 | `lib/features/library/playlist_detail_screen.dart:40` |
| C12 | `lib/features/library/artist_detail_screen.dart` (gradient stack) |

Part of broader analyzer cleanup (~35 minor warnings repo-wide).

## P2 — paddings + section rhythm

| ID | Where | Notes |
|----|-------|-------|
| C13 | Sort sheet header padding | `fromLTRB(16, 16, 16, 8)` in library vs `fromLTRB(16, 10, 8, 4)` in library top row. Pick one rhythm. ❌ |
| C14 | Section-header → content gap | Home 12 px, Library tabs 4 px. M3E spec 16 px. ❌ |
| C15 | Sleep timer sheet | Manual `Material(borderRadius: 28)` instead of using sheet theme default — works but two paths to same shape. Could collapse to default + theme override. ❌ |

## P3 — setup screen radii

`lib/features/setup/setup_screen.dart` uses radius 14 / 20 in places. Onboarding only, low visibility. ❌ optional.

---

## Conventions to lock in (so future diffs don't re-introduce drift)

- **Cover thumbs**: always go through `CoverArtImage`. Default radius 8. Pass `externalUrl:` for non-Subsonic art.
- **Detail header title**: `theme.textTheme.titleLarge` + `fontWeight: bold`. No raw `fontSize:`.
- **Card / banner radii**: 16 (M3E medium shape). Already in theme `cardTheme`.
- **Bottom sheets**: rely on default sheet theme (28 dp top corners). Don't wrap in manual `Material(borderRadius:)`.
- **Top-of-screen app bar**: `SliverAppBar.medium` for tab roots; full-bleed `SliverAppBar` w/ `flexibleSpace` only for cover-art detail screens.
- **Color overlays**: `.withValues(alpha:)`, never `.withOpacity()`.

Linked from `docs/three-pass-plan.md`. Update statuses inline as items ship.
