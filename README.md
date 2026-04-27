# Melodize

A Flutter music player for [Navidrome](https://www.navidrome.org/) /
Subsonic-compatible servers. Supports **Android** and **Linux** with a focus
on lossless playback, a polished Material 3 UI, and offline support.

---

## Features

- **Lossless playback** — streams original FLAC/OPUS/MP3 without re-encoding
- **Offline / downloads** — download songs to device for playback without a connection; batch "download all" option; browse downloads with live search, lossless/lossy filter, and multi-field sort
- **Synced lyrics** — fetches time-synced LRC lyrics from LRClib, auto-scrolls with the song
- **Now Playing screen** — album-art colour-extracted gradient, swipe between player and lyrics
- **Queue management** — drag to reorder, play next, add to queue
- **Library sorting** — sort by name, artist, recently added, downloaded
- **Home screen** — collapsing large app bar with time-aware greeting, snap-to-card carousels (recently added, random picks, recently played, playlists), M3 Expressive entrance animations
- **Discovery / Recommendations** — Deezer-powered "Recommended for You" based on your listening history, surfacing new tracks you don't already have; tap to play a 30s preview, long-press to download the full FLAC to your Navidrome server; "More like this" on any card seeds the whole section from that artist
- **Deezer search** — search the Deezer catalog from the Search tab; play previews or save to server
- **Deezer account (ARL)** — paste your Deezer `arl` cookie in Settings to unlock full-FLAC downloads via the companion
- **Sleep timer**
- **Scrobbling** — submits plays to the server (Navidrome can forward to Last.fm if configured server-side)
- **Delete from server** — remove songs directly from your Navidrome library via the companion service
- **Dock toggle** — switch between classic Material `NavigationBar` and the new floating pill dock (Settings → Appearance)
- **Android 15-style grouped settings tiles** — rounded clustered rows in the Settings screen; server, Deezer, and companion settings each on their own sub-page
- **Origin Island / MediaSession** — Android lock-screen + notification controls wired automatically
- **Linux MPRIS2** — exposes playback to `playerctl`, niri / Hyprland media keybindings, KDE / GNOME media widgets
- **Keyboard shortcuts** — space play/pause, `j`/`k` prev/next, `l`/`h` seek, `n`/`p` prev/next, `s` shuffle, `r` repeat, XF86 media keys; `1`/`2`/`3`/`4` switch nav tabs; `Esc` closes the Now Playing screen
- **Shape-morphing mini player** — mini-player radius and thumbnail morph between paused and playing states (Material 3 Expressive)

---

## Screenshots

> coming soon

---

## Getting Started

### Android

**Requirements:** Android 8.0+, a running [Navidrome](https://www.navidrome.org/) instance (or any Subsonic-compatible server)

Download the latest APK from the [Releases](https://github.com/Catgirl-meow/melodize/releases) page, install it, and enter your server URL, username, and password.

---

### Linux

**Requirements:** a running Navidrome instance and **libmpv** installed.

Audio playback on Linux uses [media_kit](https://pub.dev/packages/media_kit) (libmpv FFI) via [just_audio_media_kit](https://pub.dev/packages/just_audio_media_kit).

#### Install libmpv

```bash
# Gentoo
emerge media-video/mpv

# Ubuntu / Debian
apt install libmpv2   # Ubuntu 22.04+
# or: apt install libmpv1  (older releases)

# Arch / Manjaro
pacman -S mpv

# Fedora
dnf install mpv-libs
```

#### Install Melodize

Download the `melodize-*-linux-x64.tar.gz` archive from the [Releases](https://github.com/Catgirl-meow/melodize/releases) page and extract it:

```bash
tar -xzf melodize-*-linux-x64.tar.gz -C ~/melodize
~/melodize/melodize
```

You can create a `.desktop` launcher pointing at the extracted `melodize` binary.

#### Additional Linux libraries (usually pre-installed)

The app uses GTK 3 and a few common system libraries. If the binary fails to start, install these:

```bash
# Ubuntu / Debian
apt install libgtk-3-0 libglib2.0-0 libepoxy0

# Arch
pacman -S gtk3
```

---

## Melodize Companion (optional)

The companion is a small Python service that runs on your Navidrome host and
unlocks server-management features in the app:

| Feature | Without companion | With companion |
|---------|-------------------|----------------|
| Delete song from server | ✗ | ✓ |
| Download recommended song to server | ✗ | ✓ |
| Download Deezer search result to server | ✗ | ✓ |

→ **[Full installation guide](COMPANION.md)**

Quick summary: it's a single Python file, a config JSON, and a systemd unit.
Requires **yt-dlp** and **deemix** on the server for downloads.

---

## Deezer integration

Melodize uses the free Deezer public API (no account needed) to power
recommendations and search with 30-second previews.

**For full FLAC downloads** (requires a Deezer HiFi subscription):

1. Log in to [deezer.com](https://www.deezer.com) in your browser
2. Open DevTools → Application → Cookies → find the `arl` cookie
3. Copy its value and paste it into **Settings → Deezer → Connect account**

With the ARL configured, long-pressing a recommendation or tapping the download
icon in search will save the full lossless FLAC to your Navidrome server via
the companion.

---

## Building from source

### Requirements

- Flutter 3.x (`flutter --version`)
- **Android:** Android SDK / Android Studio + a physical device or emulator
- **Linux:** GTK 3 dev headers + libmpv + standard build tools

```bash
# Ubuntu/Debian Linux build deps
apt install libgtk-3-dev ninja-build cmake clang libmpv-dev

# Gentoo
emerge dev-libs/glib x11-libs/gtk+ media-video/mpv
```

### Steps

```bash
git clone https://github.com/Catgirl-meow/melodize.git
cd melodize
flutter pub get

# Android
flutter run            # debug on connected device
flutter build apk      # release APK → build/app/outputs/flutter-apk/app-release.apk

# Linux
flutter build linux    # release build → build/linux/x64/release/bundle/
```

---

## Architecture

```
lib/
├── core/
│   ├── api/           # SubsonicClient, NavidromeClient, CompanionClient, DeezerClient, LrcLibClient
│   ├── audio/         # MelodizeAudioHandler (just_audio + audio_service)
│   ├── db/            # Drift SQLite database (songs, downloads, queue, lyrics cache)
│   ├── models/        # Song, Album, Artist, Playlist, AppPreferences, RecommendedTrack, ...
│   └── providers.dart # All Riverpod providers
├── features/
│   ├── home/          # Home screen (incl. Deezer recommendations)
│   ├── library/       # Library (songs, albums, artists, playlists)
│   ├── player/        # Now Playing screen, Mini Player, Queue, Lyrics
│   ├── search/        # Search screen (library + Deezer catalog)
│   ├── settings/      # Settings, Downloaded Songs
│   └── shell/         # Root scaffold, bottom nav, player slide-up
└── shared/
    └── widgets/       # SongTile, CoverArtImage, ...
```

**Key dependencies:**
- [`just_audio`](https://pub.dev/packages/just_audio) — audio playback engine
- [`audio_service`](https://pub.dev/packages/audio_service) — background audio, MediaSession, lock screen controls
- [`flutter_riverpod`](https://pub.dev/packages/flutter_riverpod) — state management
- [`drift`](https://pub.dev/packages/drift) — SQLite ORM for offline cache
- [`dio`](https://pub.dev/packages/dio) — HTTP client

---

## Project structure (companion)

```
companion/
└── melodize-companion    # Single Python 3 script
```

See [COMPANION.md](COMPANION.md) for full installation and API documentation.

---

## Roadmap

Work is organized into three passes. Full detail in [`docs/three-pass-plan.md`](docs/three-pass-plan.md).

### Pass 1 — Docs + dead-code cleanup ✅
- Rewrite README + `memory/project_overview.md` to match real code
- Drop the orphaned `QueueEntries` Drift table and unused star/favourite Subsonic methods
- Schema migration v3 → v4

### Pass 2 — Bug + design fixes (in progress)
- **Recommendations quality** — parallel seed fetches, artist-diversity enforcement, better library cross-check, real error messages instead of silent empty
- **Connection-error specificity** — differentiate no-network / DNS / TLS / HTTP 401 / 403 / 5xx / timeout on the Home offline banner
- **Download reliability + notifications** — audit companion polling, snackbar on every completion / failure, de-jank library refresh
- **Companion availability** — periodic re-check instead of one-shot `FutureProvider`
- **Auto-download idempotency** — guard `ref.listen(allSongsProvider)` with a song-list signature
- **Mini-player + dock redesign** — shape-morph radius consistency + dock pill geometry shipped in v1.8.4; grouped-settings-tile visual pass still pending
- **Menu + visual-glitch triage** — per-screen iteration

### v1.8.5 additions (outside pass plan)
- **Downloaded songs overhaul** — live search (title/artist/album/genre/format), lossless/lossy filter, sort by name/artist/album/recently added with ascending/descending toggle
- **Settings sub-pages** — library server, Deezer, and companion settings moved to dedicated sub-screens

### v1.9.9 — Pass 2c download polish + 2g menu pass
**2c — Companion download reliability:**
- **Timeout snackbar** — 5-min poll budget exhaustion now surfaces "Download timed out" instead of silently dropping the job
- **Connection-loss snackbar** — 3 consecutive poll errors (≈30 s) trigger a one-time "Lost connection to companion — still trying…" so the user knows
- **Re-failure snackbar fix** — main shell listener now re-fires when the same song fails a second time after retry (was checking only status transitions, missed identical-status repeated errors)
- **Single library refresh** — dropped the redundant immediate `ref.invalidate(allSongsProvider)` after companion completion; only the 12 s delayed one now (the immediate one always missed because Navidrome hadn't indexed the song yet — pure jank)

**2g — Menu visual pass:**
- **Song tile context menu** — added drag handle + cover/title/artist header (matches recommendation card pattern)
- **Now Playing 3-dot menu** — same drag handle + song header treatment
- **Library sort sheets** (3) — added `showDragHandle: true`
- **Sleep timer sheet** — corner radius bumped 20 → 28 dp (M3 spec)

### v1.9.8 — Home greeting + Linux log noise
- **Greeting clipping fix** — v1.9.5 manually overrode `flexibleSpace` on `SliverAppBar.medium`, breaking the framework's smart expanded↔collapsed interpolation and forcing `headlineMedium` size on the collapsed bar. Now passes only `fontWeight: bold` so the variant-aware `_ScrollUnderFlexibleSpace` controls sizing — clean transition, no clipping
- **Linux shuffle log spam gone** — `addAll(items)` triggered a bug in `just_audio_media_kit` 2.1.0's `concatenatingInsertAll` (loop reads stale `request.index` against growing playlist length, emitting bogus `playlist-move` per item). Replaced with a `.add()`-per-item loop that takes the single-item path through the same code, skipping the buggy move branch

### v1.9.7 — Linux shuffle no longer kills audio
- **In-place shuffle/unshuffle** — `_toggleShuffleLinux` previously called `setAudioSource()` which forced mpv to reopen PipeWire/PulseAudio: audio muted, jumped to track start, and froze for 2+ s. New path mutates only the *upcoming* portion of the queue via `removeRange` + `addAll` (one batched op each, not N moves), so the currently-playing source is untouched. No mute, no seek, no freeze.
- Gapless prefetch (`JustAudioMediaKit.prefetchPlaylist = true`) was already enabled — verified intact.

### v1.9.6 — Pass 2 bug fixes
- **Connection-error specificity (2b)** — `serverReachableProvider` now returns a typed `ServerReachability` enum (offline / unreachable / TLS / 401 / 403 / 5xx); Home chip shows specific message + matching icon per failure mode
- **Companion staleness (2d)** — `companionAvailableProvider` migrated `FutureProvider<bool>` → `StreamProvider<bool>` re-checking every 30 s, so UI reflects companion going offline mid-session
- **Auto-download idempotency (2e)** — `ref.listen(allSongsProvider)` guarded by song-ID hash signature; no longer re-fires `downloadBatch` on every cache/fresh emission

### v1.9.5 — Home screen M3 Expressive polish
- **Collapsing greeting restored** — `SliverAppBar.medium` back on Home; expanded state `headlineMedium bold`, collapsed `titleLarge bold`
- **Staggered section entrance** — sections cascade in with 60 ms gaps instead of all animating at once
- **400 ms entrance duration** — matches M3E emphasized-decelerate spec (was 350 ms)
- **Carousel trailing affordance** — leading-only padding so the next card peeks from the right edge
- **Section header tracking** — tightened to `-0.2` matching `titleLargeEmphasized` spec
- **Card radii** — error/empty/banner containers bumped to 16 px (M3E medium shape token)

### v1.9.2–v1.9.4 — Square cover art fixes
- Three-release fix for portrait carousel covers introduced by v1.9.0; root cause was `CarouselView(shrinkExtent: 40)` passing tight width to edge items — fixed with `AspectRatio(1.0)` wrapping every cover image

### v1.9.1 — Home screen bug fixes
- **Cover art ratio** — carousel cards now enforce 1:1 square images (CarouselView was stretching covers to full card height)
- **Greeting gap** — switched to `SliverAppBar.medium`; removes the oversized gap introduced by v1.9.0's `SliverAppBar.large`
- **Carousel tap** — moved all tap handling to `CarouselView.onTap`; inner InkWells were intercepting gestures and silently eating taps

### v1.9.0 — M3 Expressive home screen redesign
- **Collapsing app bar** — greeting expands/collapses on scroll (`SliverAppBar.medium`); Home screen is now M3E-compliant (Pass 3 item 02 ✅ for Home)
- **Snap carousels** — all horizontal rows converted to `CarouselView` with 160 px cards and snap-to-card physics; partially-visible next card acts as scroll affordance
- **Section header typography** — `titleLarge w700` matching M3E spec (Pass 3 item 07 partial ✅)
- **Section entrance motion** — fade + 16 px upward slide on first data load using M3E emphasized-decelerate curve
- **Error state tokens** — recommendation errors use `errorContainer` / `onErrorContainer` for consistent visual language; server-unreachable becomes an `ActionChip` with built-in retry
- **`DynamicSchemeVariant.expressive`** — fallback color scheme (no Material You) uses the expressive tonal palette (Pass 3 item 05 ✅)
- **PREVIEW badge** — `inverseSurface` / `onInverseSurface` tokens (theme-aware, works in light mode)
- **Recommendations refresh** — `IconButton.filledTonal` for visual weight; bottom sheet context menu gains song title/artist header

### Pass 3 — Material 3 Expressive upgrade
Driven by [`Material 3 Expressive Roadmap.html`](Material 3 Expressive Roadmap.html):
1. Shape-morphing mini player (P0, rework)
2. Large / medium `SliverAppBar` (P0) — ✅ Home done in v1.9.0; Library + Settings pending
3. Grouped settings tiles (P0, visual pass)
4. Wavy progress + FAB shape morph (P1, Flutter 3.27+)
5. `DynamicSchemeVariant.expressive` (P1) — ✅ done in v1.9.0
6. Motion tokens (P1, codebase-wide) — Home stagger + 400 ms landed v1.9.5; full token refactor pending
7. `displayLargeEmphasized` typography (P2) — section header tracking -0.2 landed v1.9.5; Now Playing title pending
8. Haptics w/ opt-out preference (P2)

### Optional / future
- Crossfade
- Persistent queue (table dropped in Pass 1; reintroduce with proper wiring when the feature is built)
- Playlist creation / editing
- ListenBrainz scrobbling (Navidrome already forwards to Last.fm server-side)

---

## License

MIT
