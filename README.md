# Melodize

A Flutter music player for [Navidrome](https://www.navidrome.org/) /
Subsonic-compatible servers. Supports **Android** and **Linux** with a focus
on lossless playback, a polished Material 3 UI, and offline support.

---

## Features

- **Lossless playback** — streams original FLAC/OPUS/MP3 without re-encoding
- **Offline / downloads** — download songs to device for playback without a connection
- **Synced lyrics** — fetches time-synced LRC lyrics from LRClib, auto-scrolls with the song
- **Now Playing screen** — album-art colour-extracted gradient, swipe between player and lyrics
- **Queue management** — drag to reorder, play next, add to queue
- **Library sorting** — sort by name, artist, recently added, downloaded
- **Home screen** — time-aware greeting, recently added albums, random picks
- **Recommendations** — Deezer-powered "Recommended for You" based on your listening history; tap to play a 30s preview, long-press to download the full FLAC to your Navidrome server
- **Deezer search** — search the Deezer catalog from the Search tab; play previews or save to server
- **Sleep timer**
- **Scrobbling** — submits plays to the server (Navidrome tracks history)
- **Delete from server** — remove songs directly from your Navidrome library via the companion service
- **Floating nav dock** — optional frosted-glass floating navigation bar (toggleable in Settings)
- **Origin Island** — automatic integration via Android MediaSession (no setup needed)

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

- [x] Recommendations tab (Deezer-powered)
- [x] Download recommended songs to server via companion
- [x] Deezer catalog search with previews
- [ ] Playlist creation / editing
- [ ] Star / favourite songs
- [ ] CarPlay / Android Auto

---

## License

MIT
