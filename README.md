# Melodize

A Flutter music player for [Navidrome](https://www.navidrome.org/) /
Subsonic-compatible servers. Built for Android with a focus on lossless
playback, a polished Material 3 UI, and offline support.

---

## Features

- **Lossless playback** — streams original FLAC/OPUS/MP3 without re-encoding
- **Offline / downloads** — download songs to device for playback without a connection
- **Synced lyrics** — fetches time-synced LRC lyrics from LRClib, auto-scrolls with the song
- **Now Playing screen** — album-art colour-extracted gradient, swipe between player and lyrics
- **Queue management** — drag to reorder, play next, add to queue
- **Library sorting** — sort by name, artist, recently added, downloaded
- **Home screen** — time-aware greeting, recently added albums, random picks
- **Sleep timer**
- **Scrobbling** — submits plays to the server (Navidrome tracks history)
- **Delete from server** — remove songs directly from your Navidrome library via the companion service
- **Origin Island** — automatic integration via Android MediaSession (no setup needed)

---

## Screenshots

> coming soon

---

## Getting Started

### Requirements

- Android 8.0+ device
- A running [Navidrome](https://www.navidrome.org/) instance (or any
  Subsonic-compatible server)

### Install

Download the latest APK from the
[Releases](https://github.com/your-username/melodize/releases) page and
install it on your device.

On first launch, enter your server URL, username, and password. That's it.

---

## Melodize Companion (optional)

The companion is a small Python service that runs on your Navidrome host and
unlocks server-management features in the app:

| Feature | Without companion | With companion |
|---------|-------------------|----------------|
| Delete song from server | ✗ | ✓ |
| Download from recommendation to server | ✗ (coming soon) | ✓ (coming soon) |

→ **[Full installation guide](COMPANION.md)**

Quick summary: it's a single Python file, a config JSON, and a systemd unit.
No Docker, no dependencies, no compilation.

---

## Building from source

### Requirements

- Flutter 3.x (`flutter --version`)
- Android SDK / Android Studio
- A physical device or emulator

### Steps

```bash
git clone https://github.com/your-username/melodize.git
cd melodize
flutter pub get
flutter run            # debug on connected device
flutter build apk      # release APK
```

The APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

---

## Architecture

```
lib/
├── core/
│   ├── api/           # SubsonicClient, CompanionClient, LrcLibClient
│   ├── audio/         # MelodizeAudioHandler (just_audio + audio_service)
│   ├── db/            # Drift SQLite database (songs, downloads, queue, lyrics cache)
│   ├── models/        # Song, Album, Artist, Playlist, AppPreferences, ...
│   └── providers.dart # All Riverpod providers
├── features/
│   ├── home/          # Home screen
│   ├── library/       # Library (songs, albums, artists, playlists)
│   ├── player/        # Now Playing screen, Mini Player, Queue, Lyrics
│   ├── search/        # Search screen
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
└── melodize-companion    # Single Python 3 script, zero pip dependencies
```

See [COMPANION.md](COMPANION.md) for full installation and API documentation.

---

## Roadmap

- [ ] Recommendations tab (Last.fm / similar APIs)
- [ ] Download recommended songs to server via companion
- [ ] Playlist creation / editing
- [ ] Star / favourite songs
- [ ] CarPlay / Android Auto

---

## License

MIT
