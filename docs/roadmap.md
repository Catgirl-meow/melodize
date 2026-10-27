# Roadmap

What is still open as of v1.13.0. Everything that shipped (the old Pass 1 and Pass 2 plans, the
playback rework, the queue rewrite) is in git history and the release notes.

## Fixes

| Item | Effort | Notes |
|---|---|---|
| Wrong password shows as "server unreachable" on Home | small | `SubsonicClient.pingDetailed` maps a Subsonic `status: failed` reply (HTTP 200) to `unreachable`. Setup already uses `checkConnection()`; Home's banner should do the same. |
| Phrase comment says "16-bar" | trivial | `companion/audio_analysis.py` places phrases every 16 *beats*. The transition planner is tuned to that, so fix the comment, not the code. |
| Unused `SubsonicClient.getSimilarSongs` | trivial | Recommendations deliberately come from Deezer, so nothing calls it. Delete it. |
| Unused dependencies | trivial | Nothing imports `rxdart`, `uuid`, `intl`, `flutter_staggered_animations` or `riverpod_annotation` (and `riverpod_generator` with it). Drop them from `pubspec.yaml`. |

## Security

| Item | Effort | Notes |
|---|---|---|
| Keep the password, companion key and Deezer ARL in the platform keystore | medium | They sit in plain text in the app database and preferences ([audit](audit-2026-10.md)). `flutter_secure_storage` with a one-time migration. On Linux it needs a Secret Service (GNOME Keyring or KWallet), which minimal desktops don't run, so keep a file fallback there. |

## Visual polish (Material 3 Expressive)

| Item | Effort | Notes |
|---|---|---|
| Hard-coded detail headers | trivial | Album and playlist titles use `fontSize: 20`, the artist header `fontSize: 22`. Use `titleLarge` / `headlineSmall` with bold weight. |
| Quality badge radius | trivial | `_QualityBadge` in `song_tile.dart` uses radius 4; everything around it uses 8. |
| Section spacing | small | Sort-row padding differs between Library tabs (`16,16,16,8` vs `16,10,8,4`), and the header-to-content gap is 12 px on Home and 4 px in Library. Pick one rhythm (M3E says 16). |
| Medium collapsing app bars | small | Downloads, Downloaded songs and the Settings sub-pages still use a plain `AppBar`. Library and Home keep theirs (see [design.md](design.md#app-bars)). |

## Features

| Item | Effort | Notes |
|---|---|---|
| Prebuilt macOS app | needs an Apple Developer ID | Without signing and notarization a downloaded build won't open on other Macs. |

## Not planned

Starred songs and favourites, CarPlay / Android Auto, and recommendations from Navidrome's
similar-songs API (Deezer finds music you don't already have).

Dropped for now (October 2026): a wavy progress bar, haptics, "not interested" on
recommendations, and a collapsing app bar on Library.
