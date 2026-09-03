# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Melodize — a Flutter music player for Navidrome/Subsonic servers, targeting Android and Linux. Lossless streaming, offline downloads, Deezer-powered discovery, DJ-style smart shuffle, crossfade. See `README.md` for the feature overview and `docs/three-pass-plan.md` for the roadmap state (Pass 1 ✅, Pass 2 mostly ✅, Pass 3 M3 Expressive partially shipped).

A companion Python service (`companion/`, see `COMPANION.md`) runs on the Navidrome host and unlocks audio analysis (BPM/key/energy), rendered transitions, server-side deletes, and Deezer downloads. The app must remain fully functional without it.

## Commands

The repo has a gitignored local Flutter SDK checkout at `./flutter/` (3.44.4 stable). Use it explicitly so builds don't depend on a system Flutter:

```bash
./flutter/bin/flutter pub get
./flutter/bin/flutter analyze          # lint (flutter_lints, see analysis_options.yaml)
./flutter/bin/flutter test             # all tests
./flutter/bin/flutter test test/playback_core_test.dart   # single test file
./flutter/bin/flutter run              # debug run (Linux desktop is the fast dev loop)
./flutter/bin/flutter build linux --release
./flutter/bin/flutter build apk        # Android release → build/app/outputs/flutter-apk/
./scripts/package-linux-release.sh     # tar.gz the release bundle for GitHub Releases
```

**Codegen:** drift uses build_runner; providers are hand-written (riverpod_generator is a dev dependency but unused in lib/):

```bash
./flutter/bin/dart run build_runner build --delete-conflicting-outputs
```

The generated `lib/core/db/database.g.dart` is committed — never hand-edit it; regenerate after schema changes.

Tests are pure-Dart unit tests of the audio logic (no widget tests of substance; `widget_test.dart` is boilerplate). Linux playback needs libmpv.

## Architecture

### Audio core (`lib/core/audio/`) — the heart

Playback logic is deliberately split into pure, unit-testable classes plus one integration monolith:

- **`PlaybackQueue`** (`playback_core.dart`) — queue model: songs, current index, `PlaybackMode` (normal/shuffle/smartShuffle), reorder/insert/remove. `reorder()` expects Flutter's ReorderableListView semantics (newIndex pre-decremented for downward moves).
- **`PlaybackPlanner`** (`playback_core.dart`) — takes a queue and returns a reordered one. Heard songs + current always stay at the front; only the *upcoming* segment is reordered. Shuffle is seeded (stable seed derived from content when none given).
- **`TransitionPolicy`** (`playback_core.dart`) — plans 1–3 upcoming transitions using companion analysis: auto crossfade duration from BPM/energy/tail silence, phrase-boundary and vocal-aware fade starts, beat-grid-aligned starts, DJ-blend eligibility (BPM ±15 % + Camelot key distance ≤ 2).
- **`SmartShuffleEngine`** — `BpmCache` (bpm/key/energy/phrases/tail silence per song, with an `isEstimated` flag), `buildBpmCache()` (estimates from genre when no real data), `orderSongs()` (entry point), `buildDjArc()` (energy-curve warm-up → peak → cool-down). Three auto-detected tiers: Full DJ (companion data), Partial DJ (Deezer BPM), Simple DJ (genre estimates only).
- **`MelodizeAudioHandler`** (`audio_handler.dart`, ~2.5k lines) — the integration point: `extends BaseAudioHandler` (audio_service). Owns the just_audio player, keeps a **virtual order** mapping over the physical just_audio playlist (shuffle reorders virtually; queue edits translate virtual ↔ physical indices — see `_insertIntoVirtualOrder`/`_removePhysicalIndicesFromVirtualOrder`). Implements two transition mechanisms: volume crossfade on the main player, and companion-**rendered** transition mixdowns played on a second deck (`_prepareRenderedTransition`/`_startRenderedTransition`). Also: scrobbling (50 % or 4 min), sleep timer, MPRIS setup, handler disposal rules (Linux disposes on detach; Android keeps the handler for background audio).

UI code never touches the handler directly: it reads provider streams and calls handler methods.

### Wiring (`lib/core/providers.dart`)

Every Riverpod provider lives here (~1.4k lines). Key patterns:

- `AudioHandlerNotifier` (`StateNotifier<MelodizeAudioHandler?>`) exposes the handler; `main.dart` overrides it with a `createAudioHandler()` instance created before `runApp`.
- Handler inputs are pushed via `ref.listen` in `_StartupRouter` (main.dart): `serverConfigProvider` → `setConfig`, prefs → `setStreamQuality`, `companionAnalysisProvider` → `setCompanionAnalysis`, `companionAudioApiProvider` → `setCompanionAudioApi`.
- Playback UI state comes from stream providers (`currentSongStreamProvider`, `playerStateStreamProvider`, `positionStreamProvider`, `queueSnapshotStreamProvider`, `shuffleModeStreamProvider`, …) that mirror handler streams — all updates flow handler → stream → UI, never through Riverpod state.
- `serverConfigProvider` (FutureProvider) doubles as the startup router: loading → spinner, error/null → `SetupScreen`, data → `MainShell`.

### Data

- **drift/SQLite** (`lib/core/db/database.dart`): 5 tables — `CachedSongs` (library cache incl. download state), `PlayHistory` (deliberately stores artist/title strings, not IDs, so Deezer recommendations survive server switches), `ServerConfig` (single active), `DownloadQueue`, `LyricsCache`. Schema v4; migrations in `MigrationStrategy.onUpgrade`. Singleton via `AppDatabase()`.
- **APIs** (`lib/core/api/`): `SubsonicClient` (MD5-salted auth), `CompanionAudioApi` (analysis cache fetch, rendered-transition jobs, downloads with auth headers), `DeezerClient` (public API + ARL session validation), `LrcLibClient` + `lyrics_ovh_client.dart` (multi-provider lyrics fallback).

### Platforms

- **Android**: `audio_service` provides MediaSession/lock-screen; edge-to-edge UI (Linux skips it); clamping scroll physics.
- **Linux**: media_kit/mpv backend (just_audio_media_kit, `prefetchPlaylist = true` for gapless); MPRIS2 via `lib/core/linux/linux_mpris.dart` (playerctl/keyboard shortcuts); bouncing scroll physics; handler disposed on app detach.
- Downloads live in `melodize_downloads/` under the app storage dir (`core/utils/platform_dirs.dart`).

### UI

`lib/features/` (home, library, player, search, settings, downloads, setup, shell) + `lib/shared/` (widgets, theme, utils). Theming: `AppTheme` with `DynamicColorBuilder` + `DynamicSchemeVariant.expressive`; Now Playing derives accent colors from album art via `palette_generator` (`dominantColorProvider`/`currentAccentColorProvider`). `docs/design-consistency.md` holds the visual conventions backlog.

## Gotchas

- `PlaybackQueue.reorder` uses Flutter's adjusted indices — a plain list-move is a bug; the current song must keep its logical position unless it is the moved item (see the comment block in `removeAt`/`reorder`).
- The audio handler deliberately keeps shuffle state internal (virtual order, seeds, generations). Queue edits during shuffle are generation-guarded (`_recalculateShuffleOrderImpl(int generation)`).
- Crossfade and rendered transitions have their own state machines with generation counters; the safest change is usually inside `_startCrossfadeFadeOut`/`_prepareRenderedTransition`, never the outer call sites.
- Smart-shuffle behavior is pinned by regression tests (`smart_shuffle_queue_regression_test.dart`, `shuffle_edge_cases_test.dart`, `shuffle_stress_test.dart`) — run them after any change to `PlaybackQueue`, `PlaybackPlanner`, or the shuffle engine.
- `/melodize/` at the repo root is a gitignored accidental project copy; `./flutter/` is the gitignored SDK. Neither is part of the repo.
- Version bumps: `pubspec.yaml` `version:` (e.g. `1.12.2+88`); releases are cut with `chore: release vX.Y.Z` commits.
