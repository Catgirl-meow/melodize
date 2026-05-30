# Melodize

A Flutter music player for [Navidrome](https://www.navidrome.org/) /
Subsonic-compatible servers. Supports **Android** and **Linux** with a focus
on lossless playback, a polished Material 3 UI, and offline support.

---

## Features

- **Lossless playback** — streams original FLAC/OPUS/MP3 without re-encoding
- **Offline downloads** — download songs for offline playback; batch "download all"; browse with search, lossless/lossy filter, and multi-field sort
- **Synced lyrics** — time-synced LRC from Lrclib, auto-scrolls with the song; plain lyrics fallback
- **Queue management** — drag to reorder, play next, add to queue; works in all shuffle modes
- **Home screen** — time-aware greeting, snap-to-card carousels, M3 Expressive entrance animations; Deezer ARL expiry / server reachability banners; pull-to-refresh for all sections
- **Deezer-powered discovery** — "Recommended for You" based on your listening history; "More like this" seeds from any artist; 30-second previews; full FLAC downloads via companion
- **Deezer search** — search the Deezer catalog from the Search tab; play previews or save to server
- **Library management** — sort songs/albums/artists by name, artist, recently added, downloaded; delete songs from server via companion
- **White & Black theme** — full light (white) / dark (black) theme + Material You dynamic color; theme-aware Now Playing screen with adaptive album-art gradient and cover-art-driven accent colors for buttons, sliders, and progress bars
- **Sleep timer & scrobbling** — timer auto-stops playback; scrobbles submitted to server at 50 % or 4 min
- **Smart Shuffle** — BPM-progressive ordering powered by companion audio analysis; Camelot-wheel harmonic mixing; energy-curve DJ arc planning with warm-up → peak → cool-down; non-deterministic (every activation produces a different sequence); heard-song preservation (only upcoming tracks are reordered); genre-transition scoring matrix; automatic tier detection based on available data quality
- **Crossfade** — deck-based overlap between tracks (0–12 s); loads the next track on a temporary second player and crossfades volumes; automatically offsets by trailing silence so the fade doesn't start during silence
- **DJ transitions** — when companion analysis is available and BPM is compatible (±15 %), transitions are tagged for enhanced blending; toggleable in Settings
- **Android lock-screen controls** — MediaSession wired automatically via `audio_service`
- **Linux MPRIS2 + keyboard shortcuts** — exposes playback to `playerctl`, media keybindings; keyboard controls for playback, seek, shuffle, repeat, nav tabs
- **Dock toggle** — switch between classic `NavigationBar` and floating pill dock
- **Shape-morphing mini player** — radius and thumbnail morph between paused and playing states
- **Offline banner** — animated inline banner ("Offline. Browse downloads") with tappable link to downloads screen
- **Server reachability diagnostics** — specific error messages for each failure mode (unreachable, TLS error, unauthorized, forbidden, server error); tap-to-retry
- **Deezer ARL session management** — paste your Deezer ARL cookie in Settings to enable FLAC downloads; inline expiry banner when the session dies
- **Linux keyboard shortcuts** — `Space` play/pause, `N` next, `P` previous, `L`/`H` seek fwd/back (Shift for 30 s), `J`/`K` volume down/up, `M` mute, `S` toggle shuffle, `R` cycle loop mode (skip when text field is focused)
- **Auto-download modes** — Never / When played / All songs

---

## Getting Started

### Android

**Requirements:** Android 8.0+, a running [Navidrome](https://www.navidrome.org/) instance (or any Subsonic-compatible server)

Download the latest APK from the [Releases](https://github.com/Catgirl-meow/melodize/releases) page, install it, and enter your server URL, username, and password.

### Linux

**Requirements:** a running Navidrome instance and **libmpv** installed.

#### Install libmpv

```bash
# Gentoo
emerge media-video/mpv

# Ubuntu / Debian
apt install libmpv2   # Ubuntu 22.04+

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

Create a `.desktop` launcher for app-menu integration.

#### Additional Linux libraries (usually pre-installed)

If the binary fails to start:

```bash
# Ubuntu / Debian
apt install libgtk-3-0 libglib2.0-0 libepoxy0

# Arch
pacman -S gtk3
```

---

## Melodize Companion (optional)

A small Python service that runs on your Navidrome host, unlocking server-management and audio-analysis features:

| Feature | Without companion | With companion |
|---------|-------------------|----------------|
| Delete song from server | ✗ | ✓ |
| Download recommended song to server | ✗ | ✓ |
| Download Deezer search result to server | ✗ | ✓ |
| Audio analysis (BPM, Camelot key, energy, spectral centroid, trailing silence) | ✗ | ✓ |
| Batch analysis of your library with incremental cache | ✗ | ✓ |
| Smart shuffle with real BPM / key / energy data | genre-estimated only | real audio analysis |
| DJ transition detection (BPM ±15 % + harmonic keys) | ✗ | ✓ |

→ **[Full installation guide](COMPANION.md)** — single Python script, config JSON, and systemd unit. Requires **librosa**, **numpy**, and **soundfile** for analysis; **deemix** and **yt-dlp** for downloads.

Analysis data flows into the Smart Shuffle engine automatically: when the companion is connected its cached BPM, key, energy, and spectral-centroid values are used to build energy-curve DJ arcs and score harmonic compatibility. Three quality tiers exist:

1. **Full DJ** (companion connected) — real BPM, Camelot keys, energy → tight beatmatching + key compatibility + energy-curve planning
2. **Partial DJ** (Deezer BPM only) — real BPM from Deezer metadata, genre-estimated energy, no key data
3. **Simple DJ** (offline) — genre-estimated BPM only, wider tolerances

The engine auto-detects which tier applies based on the fraction of songs with real data.

---

## Deezer integration

Melodize uses the free Deezer public API (no account needed) for recommendations and search with 30-second previews.

**For full FLAC downloads** (requires a Deezer HiFi subscription):

1. Log in to [deezer.com](https://www.deezer.com) in your browser
2. Open DevTools → Application → Cookies → find the `arl` cookie
3. Copy its value and paste it into **Settings → Deezer → Connect account**

With the ARL configured, long-pressing a recommendation or tapping the download icon in search will save the full lossless FLAC to your Navidrome server via the companion. The app validates the ARL against Deezer's API and shows an inline banner when it expires.

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
│   ├── api/           # SubsonicClient, NavidromeClient, CompanionAudioApi, DeezerClient, LrcLibClient
│   ├── audio/         # MelodizeAudioHandler, PlaybackQueue, PlaybackPlanner, TransitionPolicy, SmartShuffleEngine, ShuffleMode, BpmEstimator
│   ├── db/            # Drift SQLite database (songs, downloads, queue, lyrics cache)
│   ├── models/        # Song, Album, Artist, Playlist, AppPreferences, RecommendedTrack, LyricsResult, SearchResults, RecommendationsState
│   ├── utils/         # PlatformDirs, TitleNormalize
│   ├── linux/         # LinuxMprisService (MPRIS2 + playerctl)
│   └── providers.dart # All Riverpod providers
├── features/
│   ├── home/          # Home screen (greeting, carousels, recommendations)
│   ├── library/       # Library (songs, albums, artists, playlists)
│   ├── player/        # Now Playing screen, Mini Player, Queue, Lyrics, Floating Mini Player
│   ├── search/        # Search screen (library + Deezer catalog)
│   ├── settings/      # Settings, Downloaded Songs, server/Deezer/companion config
│   ├── downloads/     # Downloads screen (active + completed downloads)
│   ├── setup/         # First-run setup wizard
│   └── shell/         # Root scaffold, bottom nav, player slide-up
├── shared/
│   ├── widgets/       # SongTile, CoverArtImage, DeezerTrackTile, OfflineBanner
│   ├── utils/         # SnackBar helpers, SongActions, DownloadPollingMixin
│   └── theme/         # AppTheme (Material 3 + dynamic color)
└── widgets/           # GroupedListTile (reusable grouped-section widget)
```

**Key dependencies:**
- [`just_audio`](https://pub.dev/packages/just_audio) — audio playback engine
- [`audio_service`](https://pub.dev/packages/audio_service) — background audio, MediaSession, lock screen controls
- [`flutter_riverpod`](https://pub.dev/packages/flutter_riverpod) — state management
- [`drift`](https://pub.dev/packages/drift) — SQLite ORM for offline cache and downloads
- [`dio`](https://pub.dev/packages/dio) — HTTP client
- [`dynamic_color`](https://pub.dev/packages/dynamic_color) — Material You wallpaper colors
- [`palette_generator`](https://pub.dev/packages/palette_generator) — cover-art accent colors
- [`cached_network_image`](https://pub.dev/packages/cached_network_image) — album art caching
- [`just_audio_media_kit`](https://pub.dev/packages/just_audio_media_kit) — Linux mpv backend
- [`dbus`](https://pub.dev/packages/dbus) — Linux MPRIS2

---

## Roadmap

Work is organized into three passes. Full detail in [`docs/three-pass-plan.md`](docs/three-pass-plan.md).

- **Pass 1** — Docs cleanup + dead-code removal ✅
- **Pass 2** — Bug fixes and design polish (mostly complete — recommendations, connection errors, download reliability, companion freshness, auto-download idempotency, mini-player dock, menu triage, smart shuffle + playback architecture rework)
- **Pass 3** — Material 3 Expressive upgrade (partial — cover-art-driven player accent colors shipped; pending sliver app bars, motion tokens, grouped-settings visual pass, haptics)

---

## License

MIT
