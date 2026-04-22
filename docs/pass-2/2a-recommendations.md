# 2a — Recommendations quality rewrite

**Goal:** Home-screen "Recommended for You" surfaces **new, relevant** music the user doesn't already have — not library-similar, not library-duplicate. Discovery stays Deezer-based; Subsonic `getSimilarSongs` stays unwired.

---

## Current state

**Files:**
- `lib/core/providers.dart:254–310` — `recommendationsProvider` (FutureProvider.autoDispose).
- `lib/core/api/deezer_client.dart:25–58` — `DeezerClient.getRecommendations(artist, title)`.
- `lib/features/home/home_screen.dart:219–257` — renders "Recommended for You" horizontal list.
- `lib/features/home/home_screen.dart:492–644` — `_RecommendationCard` (tap → play 30s preview, long-press → companion download).

**Flow today:**
1. Pull `db.getRecentHistory(limit: 30)` → shuffle → take first 10 as seeds.
2. For each seed, call `deezer.getRecommendations(artist, title)` **sequentially** (each call = Deezer `/search` + Deezer `/artist/{id}/radio`, so up to 20 HTTP round-trips in series).
3. Dedupe by Deezer ID, stop once the candidate pool hits 40.
4. Take first 30 candidates → call `SubsonicClient.search` in parallel (`Future.wait`) for each, checking if the library already has that title.
5. Exact `title.toLowerCase().trim()` equality check excludes library hits.
6. Take first 20 non-library tracks, wrap in `Song.fromRecommendation`, return.
7. Anywhere on failure → return `[]` silently.

## Problems (from user + audit)

1. **Slow.** Sequential seed fetches + Subsonic round-trips per candidate = multi-second wait, sometimes >10 s on shaky connections.
2. **Wrong artist on common titles.** `tracks.first` on a Deezer search for "Creep Radiohead" might pick a random cover by someone else; artist radio then seeds from the wrong artist.
3. **No artist diversity.** A single seed can dominate; if the user's last 10 plays are all Deftones, every recommendation is Deftones-adjacent.
4. **Library cross-check misses near-duplicates.** Exact title equality fails on `Song (Remastered 2019)` vs `Song`, `Song (feat. X)` vs `Song`, `Live at Y` variants, and doesn't check artist (different songs with the same title survive).
5. **Silent empty on failure.** User sees an empty section and can't tell: no history yet vs Deezer down vs server down vs genuinely no new music found.
6. **`autoDispose` churn.** Provider re-runs on every home-screen mount — tapping a tab and coming back triggers a fresh ~5 s fetch.
7. **No "refresh recs" affordance.** Pull-to-refresh on the whole Home screen works but is heavy; a per-section refresh would be lighter.

## Proposal (pending user sign-off, see Open questions)

### Pipeline rewrite (`recommendationsProvider`)

```
history(30) → dedupe-by-artist → shuffle → take N distinct seeds
        ↓
    parallel seed fan-out (Future.wait)
        ↓
  per seed: search → fuzzy-match artist from top-5 hits → artist/radio
        ↓
  merge pool (dedupe by Deezer ID) — target ~60 candidates
        ↓
  parallel library cross-check (Future.wait)
  - normalized title+artist comparison (strip parens, feat., remasters)
        ↓
  filter out library hits
        ↓
  artist-diversity cap (max 2 per artist)
        ↓
  shuffle → take 20
```

### Specific changes

- **`DeezerClient.getRecommendations`** → split into two calls; expose `searchArtistId(title, artist)` + `artistRadio(artistId, limit)` so the provider can parallelize.
- **Fuzzy artist resolution:** search with `limit=5`, pick hit whose artist name matches the seed artist when normalized (lowercased, accent-stripped, whitespace-collapsed). Fallback to `tracks.first` only when no good match.
- **Normalization helper** `_normalize(title, artist)`:
  - Lowercase, NFD decompose → strip combining marks (accents).
  - Strip parenthetical suffixes: `\s*\([^)]*\)\s*$`, `\s*\[[^\]]*\]\s*$`.
  - Strip `feat\.?\s.*`, `ft\.?\s.*`, `featuring .*`.
  - Strip trailing `- Remastered( \d{4})?`, `- Live(.*)`, `- Acoustic`, etc.
  - Collapse whitespace.
- **Library cross-check:** query library **once** (prefer `allSongsProvider` value if cached; else issue one search with broader terms) and match candidates locally against a `Set<String>` of normalized `"$title|$artist"` keys. Replaces N per-candidate Subsonic searches with one bulk comparison.
- **Result type** (sealed class `RecommendationsState`):
  - `Ready(List<Song> songs)`
  - `EmptyNoHistory` — user hasn't played anything yet.
  - `EmptyAllInLibrary` — Deezer returned candidates, but everything was already on the server.
  - `EmptyAllFailed(String reason)` — all seed fetches errored.
  - `PartialReady(List<Song> songs, int failedSeeds)` — some seeds failed but we got usable output.
- **Artist diversity:** after the library filter, bucket by artist → interleave → cap at 2 per artist → shuffle → take 20.
- **Cache:** drop `autoDispose`; keep the result until invalidated (pull-to-refresh, explicit refresh button, or server-config change). Saves ~5 s every time the user leaves and returns to Home.
- **Per-section refresh button:** small `IconButton(Icons.refresh_rounded)` in the `_Section` trailing row next to Play / Shuffle.
- **Error UI in the section itself** (not just silent empty): one-line muted-foreground message below the title with a retry button when state is `EmptyAllFailed`.

### Expected wins

- Cold fetch time: ~10 s → ~2–3 s (parallelism + single bulk library check).
- No more "all Radiohead" recommendation lists on days where the user binge-listens one artist.
- User can tell broken from empty.
- Returning to Home is instant once a cache is filled.

## Open questions (need user decisions before I start)

1. **Seed diversity threshold** — how many distinct seed artists? I suggest **6**. Lower = narrower taste window, higher = diluted signal. (Current: 10 with no diversity.)
2. **Candidate pool size** — I suggest **~60 candidates → 20 final**. OK?
3. **Artist-diversity cap in output** — max **2 per artist** in the 20-item list. OK? (Could be 1 for maximum variety, 3 for taste-faithful.)
4. **Library cross-check data source** —
   - (a) Reuse the `allSongsProvider` cache (fast, but may be stale if the user just added songs).
   - (b) Issue one fresh Subsonic `search3` call per session.
   - (c) Both — use the cache but refresh it opportunistically.
   My default: **(a)**. Fast, and stale-by-a-few-minutes is acceptable for this feature.
5. **`autoDispose` drop** — OK to keep results cached until explicit invalidation? Or do you want recs to re-generate on every Home mount (current behavior)?
6. **Refresh button in the section** — yes / no? (I'd add it.)
7. **"Play all" and "Shuffle" already present on the section** — keep or remove when recs include preview-only tracks? (Preview-only tracks in a queue can't really "play all" smoothly — each is 30 s.)
8. **Fallback when history is empty** — current behavior: empty section. Should we fall back to something else (genre-based Deezer charts, random Discover overlap)? Or just show a "Play some music first — recs appear after a few plays" hint?
9. **Error retry** — should a failing fetch auto-retry once in the background, or only when the user taps the retry button?
10. **Remember user dismissals?** — e.g. if user long-presses a card and picks "not interested", filter that Deezer ID forever. Want this, or out of scope for 2a?

## Files to touch

- `lib/core/api/deezer_client.dart` — split into `searchArtistMatch` + `artistRadio`; add fuzzy-match helper.
- `lib/core/providers.dart` — rewrite `recommendationsProvider`; add `RecommendationsState` sealed class.
- `lib/core/utils/title_normalize.dart` — **NEW** — normalization helpers (reusable in 2c for download dedup too).
- `lib/features/home/home_screen.dart` — switch on new `RecommendationsState`; add per-section refresh button; surface error/empty reasons.
- `lib/core/models/recommended_track.dart` — no changes expected.

## Verification

1. `flutter analyze` clean.
2. Cold-launch, fresh Home: recs load in < 3 s on LAN.
3. Hot-return to Home tab: recs cached (no spinner).
4. Pull-to-refresh: new recs arrive; no crash on mid-fetch cancel.
5. With server down: section shows specific "could not reach server" chip with a retry button, not blank.
6. With no play history: section shows "listen to a few songs to see recommendations".
7. Binge-listen one artist, refresh: still see > 1 artist in the output (diversity cap working).
8. Library song appears in Deezer results → verify excluded (check with a song you know you own that Deezer also lists).
9. `Song (Remastered)` in library → Deezer returns non-remaster → verify filtered as duplicate.
10. Long-press → companion download still works on preview-only cards.

## Decisions (locked 2026-04-21)

**Clarifying Q2 restated:** "Fetch ~60" means fetch ~60 candidates *from Deezer* (new music), cross-check against the user's library to drop already-owned tracks, then return a final list for the Home section. Over-fetch is a safety buffer: library-filter + artist-diversity cap + tracks-without-preview-URL all shrink the list before the cap.

| # | Question | Decision |
|---|---|---|
| 1 | Seed count | 6 distinct seed artists (default) |
| 2 | Pool → final | Fetch ~60 Deezer candidates, return up to **30** |
| 3 | Artist cap | Max 2 per artist in output (default) |
| 4 | Library source | Reuse `allSongsProvider` cache (default) |
| 5 | Drop `autoDispose` | **Yes, drop it.** User reports recs "stop working after long time in the app without a refresh" — caching a failed empty fetch while Home stays watched. Drop autoDispose + rely on explicit invalidation (pull-to-refresh, section refresh, server-config change). Root cause of the stuck-recs bug gets investigated during the rewrite. |
| 6 | Section refresh button | **Yes.** Replace the existing Play / Shuffle icons (they duplicate tap-to-play and have bugs). Single `Icons.refresh_rounded` in the trailing slot. |
| 7 | Play / Shuffle section buttons | **Removed** (see Q6). Tap on a card already plays; the buttons were redundant + buggy. |
| 8 | Empty-history fallback | Subtle inline hint (one muted text line): "Play a few songs — recommendations appear after." No layout-breaking fallback UI. |
| 9 | Retry-on-failure UX | Provider auto-retries the seed fan-out **once** silently. On final failure, show a small inline error in the section ("Couldn't load recommendations — {reason}") with a **Retry** button. **No popup / snackbar** for this — it's not user-action-driven. |
| 10 | Persistent dismissals | **Deferred.** Saved to `docs/ideas/future-ideas.md` as a future feature. |
| 11 | Precache album art | **Yes.** Once the final list is built, `precacheImage` all 30 covers in the background. |
| 12 | "More like this" | **3-dot menu on the card** — user dislikes long-press actions (breaks design). Long-press action is **removed**. 3-dot menu gets: "Add to library" (the current long-press action — download via companion) and "More like this" (regenerates recs from that one seed). |
| 13 | Genre-biased seeding | **Yes.** When the seed song has a genre, bias the Deezer search query toward same-genre hits. Graceful fallback if genre is missing. |

## Implementation plan (locked)

### New types

`lib/core/models/recommendations_state.dart` — sealed class:
```dart
sealed class RecommendationsState {}
class RecsLoading extends RecommendationsState {}
class RecsReady extends RecommendationsState { final List<Song> songs; ... }
class RecsEmptyNoHistory extends RecommendationsState {}
class RecsError extends RecommendationsState { final String reason; }
```

### `lib/core/api/deezer_client.dart` changes

- Split `getRecommendations(artist, title)` into:
  - `searchBestArtist({required String artistName, String? trackTitle, String? genreHint}) → Future<int?>` — fuzzy-matched Deezer artist ID.
  - `artistRadio(int artistId, {int limit}) → Future<List<RecommendedTrack>>`.
- Keep existing `search(query, limit)` for the Deezer catalog search tab.
- Fuzzy match helper: normalize (lowercase, accent strip, whitespace collapse), pick first hit whose normalized artist name contains or is contained in the seed's normalized name. Falls back to `tracks.first` when no good match.

### `lib/core/utils/title_normalize.dart` — NEW

Shared helpers so 2c download-dedup can reuse:
- `String normalize(String s)` — lowercase, NFD accent strip, strip parens `(...)`, brackets `[...]`, strip `- Remastered`, `- Remaster <year>`, `- Live`, `- Acoustic`, `feat. X`, `ft. X`, `featuring ...`, collapse whitespace.
- `String keyFor(String title, String artist)` — `"${normalize(title)}|${normalize(artist)}"`.

### `lib/core/providers.dart` changes

Replace `recommendationsProvider`:
- Non-autoDispose `FutureProvider<RecommendationsState>`.
- Pipeline:
  1. Pull history; if empty → `RecsEmptyNoHistory`.
  2. Dedupe seeds by artist (normalized); shuffle; take 6.
  3. `Future.wait` over seeds: `searchBestArtist(genreHint: seed.genre)` → `artistRadio(id, limit: 10)`.
  4. If *all* seeds failed: retry once (small delay). Still all failed → `RecsError(reason)`.
  5. Flatten, dedupe by Deezer ID, filter out previewless, keep up to ~60.
  6. Build `Set<String>` of normalized library keys from `allSongsProvider` cache.
  7. Drop candidates whose `keyFor(title, artist)` is in the library set.
  8. Bucket by artist; interleave across buckets; cap 2 per artist.
  9. Shuffle; take 30.
  10. `precacheImage` all covers (fire-and-forget).
  11. Return `RecsReady(songs)`.

### `lib/features/home/home_screen.dart` changes

- Replace `recsAsync.when` block with a switch on `RecommendationsState`.
- Remove Play / Shuffle icons from the section trailing row; add single **Refresh** icon.
- Add `_RecommendationCardMenu` for the 3-dot button (replaces the long-press):
  - "Add to library" → existing `_addToLibrary` flow.
  - "More like this" → writes a per-seed override, invalidates `recommendationsProvider` → pipeline runs with only that seed.
- Remove `onLongPress: canDownload ? () { _addToLibrary(); } : null` from `_RecommendationCard`.
- Add inline error state with Retry button.
- Add inline hint when `RecsEmptyNoHistory` ("Play a few songs — recommendations appear after.").

### "More like this" seed override

Simple approach: a `StateProvider<Song?> recommendationsSeedOverrideProvider`. When set, the provider uses just that single seed; when null, normal pipeline. Card's 3-dot "More like this" sets the override + invalidates; a "Clear" action at the top of the section clears the override.

## Files to touch (final list)

- `lib/core/api/deezer_client.dart` — split API, fuzzy match.
- `lib/core/utils/title_normalize.dart` — NEW.
- `lib/core/models/recommendations_state.dart` — NEW.
- `lib/core/providers.dart` — rewrite `recommendationsProvider`, add seed override.
- `lib/features/home/home_screen.dart` — switch rendering, remove long-press, add 3-dot menu, refresh button, error / hint states.

## Verification (final)

1. `flutter analyze` clean.
2. Fresh Home, cold: recs load < 3 s on LAN.
3. Tab-away → tab-back: cached (no spinner).
4. Leave app open for 30+ min: recs still valid; no "stuck empty" state.
5. Pull-to-refresh: new recs, no crash.
6. Section refresh button: same behavior, quicker (just the section invalidates).
7. No-history install: hint shows, no layout break.
8. All Deezer requests fail: retry fires once, then error + Retry button shown in section.
9. Binge-listen one artist, refresh: > 1 artist in output.
10. Known library duplicates (incl. `(Remastered)`, `feat.`) excluded from recs.
11. Long-press: no action (long-press removed).
12. 3-dot menu: "Add to library" works as before; "More like this" regenerates from that seed.
13. Tap on any card: plays 30-s preview.
14. Covers visible instantly on horizontal scroll (precache working).

**Q7 resolution (2026-04-21):** Option A. Tap on any card → 30-s Deezer preview, always. 3-dot menu → "Add to library" for full-FLAC companion download (normal library playback after). No download-then-play auto-handoff.

## Status

- 2026-04-21: decisions locked (all 13 questions + Q7 follow-up). Implementation starting.
