# Testing Melodize

Three layers, from fastest to slowest. Run the first two after any change; run the integration
tests for anything that touches playback, navigation, downloads or a screen.

| Layer | Command | Needs | Time |
|---|---|---|---|
| Lint | `./flutter/bin/flutter analyze lib test integration_test` | Flutter SDK | ~10 s |
| Unit tests | `./flutter/bin/flutter test` | Flutter SDK | ~25 s |
| Live API tests | `eval "$(scripts/test-navidrome.sh env)"; ./flutter/bin/flutter test test/live` | test server | ~10 s |
| Linux integration | `scripts/test-linux.sh` | podman, test server | ~1 min per file, ~4 min first run |
| Android integration | `scripts/test-android.sh` | Android SDK + emulator, test server | ~1 min per file, ~4 min first build |
| Companion | see [below](#companion) | uv | ~20 s |

Always analyze `lib test integration_test`, not the repo root: the root also walks the ignored
`./flutter/` SDK and `/melodize/` copy and reports thousands of bogus errors.

## Where each layer can run

**The user's laptop (Gentoo, where Remote Control sessions run) has everything**: the Flutter SDK
at `./flutter/` of the main checkout, the Android SDK and NDK at `~/Android/Sdk`, JDK 17, `adb`,
the emulator with the AVD `melodize_test` (android-36, x86_64), KVM, and podman. There is no
Android Studio and none is needed. Do not report that Android can't be built or tested there:
run `scripts/test-android.sh`.

**Cloud sessions** (claude.ai/code, containers) have no Android SDK, no emulator and no podman.
Run analyze and the unit tests there, and say that the Linux and Android integration tests need the
user's machine. Don't try to install an Android SDK in the cloud.

## The test server

Integration and live tests talk to a throwaway Navidrome with a generated library, never to a real
server:

```bash
scripts/test-navidrome.sh up      # podman container melodize-test-navidrome on localhost:4534
scripts/test-navidrome.sh reset   # restore the library (after delete-flow tests) and rescan
scripts/test-navidrome.sh env     # MELODIZE_TEST_* exports for test/live
scripts/test-navidrome.sh down
```

Credentials live in `~/.local/share/melodize-testnd/credentials`; both runners read them from there.
The library (`scripts/gen-test-library.sh`) has known albums the tests rely on: "Electro Album"
(6 FLAC tracks), "Rock Album" (4 MP3s), Cyrillic and Japanese tags, Opus, AAC and Vorbis files,
edge cases (no tags, a 1-second and a 9-minute track, 96 kHz FLAC), a "Delete Me" album and
"Long Names" for layout checks. **Never point any test at a production server.**

## Integration tests

Files in `integration_test/`, each a separate app launch with an empty app profile:

| File | Covers |
|---|---|
| `test_server_smoke_test.dart` | setup form validation, wrong password, connect, library list, play and skip, Remove missing files, switching server |
| `app_flows_test.dart` | album and artist pages, Play on an album, search, Play next, Add to queue, skip, shuffle and smart-shuffle cycling, repeat modes, the queue sheet, the sleep timer |
| `downloads_test.dart` | downloading a song for offline, the Downloaded songs screen, removing the download |
| `shuffle_transition_test.dart` | natural song changes in shuffle and smart shuffle go straight to the planned next song (drives the audio handler, ~2.5 min) |
| `text_overflow_tour_test.dart` | walks every main screen with the "Long Names" library and fails on any layout overflow |

Shared helpers are in `integration_test/helpers.dart` (`connectIfNeeded`, `tapVisible`,
`searchSong`, `openSongOptions`, `handlerOf`, ...). Use them in new tests:

- Check behavior through the real handler and providers (`handlerOf(tester).queueSnapshot`,
  `container(tester).read(...)`), not only through what is on screen.
- Never `pumpAndSettle`: a playing song or a spinner never settles. Use `pumpUntil` /
  `pumpUntilTrue`, which print the texts on screen when they time out.
- Tap with `tapVisible`: it scrolls lazy lists and grids until the target is built and moves it
  clear of the mini player. `initIntegration()` makes a tap that would land on another widget
  fail on the spot.
- `app.main()` may run only once per file (audio_service can't be initialized twice), so keep one
  `testWidgets` per file or share one launch.

### Linux: `scripts/test-linux.sh`

```bash
scripts/test-linux.sh                                       # all files
scripts/test-linux.sh integration_test/app_flows_test.dart  # one file
scripts/test-linux.sh --shell                               # shell in the test container
```

Runs the tests in an Ubuntu 22.04 container (`melodize-linux-test:22.04`, built on first use):
the app draws on **Xvfb**, audio goes to a **PulseAudio null sink**, and app data lives in the
container. Nothing appears on the desktop, nothing plays on the speakers, and the user's own
`~/.local/share/com.catgirl.melodize` is never touched. The checkout, SDK and pub cache are mounted
at their host paths so the generated files stay valid for host builds; `build/` and `.dart_tool/`
live in per-checkout podman volumes (`melodize-test-<hash>-*`), so the second run skips the CMake
configure step. The host's system D-Bus socket is passed in read-only use for connectivity_plus,
which asks NetworkManager whether the device is online.

Don't run integration tests with plain `flutter test integration_test -d linux` on the host: a window
opens on the user's screen, test tones play out loud, and the app uses the real app data.

### Android: `scripts/test-android.sh`

```bash
scripts/test-android.sh                                     # all files
scripts/test-android.sh integration_test/downloads_test.dart
KEEP_EMULATOR=1 scripts/test-android.sh ...                 # leave the emulator up for the next run
ANDROID_SERIAL=emulator-5554 scripts/test-android.sh ...    # use a running device
```

If no emulator is connected, it boots `melodize_test` **headless** (`-no-window -no-audio
-gpu swiftshader_indirect`, ~30 s cold boot) and shuts it down at the end. Before each file it turns
off animations, keeps the screen on, clears the app's data (`pm clear com.hiby.music`) and grants
the notification permission so its dialog never covers the app. The server URL is
`http://10.0.2.2:4534` (the emulator's name for the host's localhost); debug builds allow cleartext
HTTP to private hosts.

The first APK build takes ~3 min; later builds are incremental (~30 s). Emulator audio is off, so
positions advance but nothing is heard. To look at the app by hand, start the emulator with a window
(`~/Android/Sdk/emulator/emulator -avd melodize_test`) and use
`./flutter/bin/flutter run -d emulator-5554`; `adb shell input text` drops characters on the slow
emulator, so prefer an integration test over typing through adb.

## Companion

```bash
uv run --no-project --with numpy --with soundfile --with librosa --with pyrubberband \
  python -m unittest discover -s companion/tests
```

## Worktrees

The Flutter SDK only lives in the main checkout (`~/src/melodize/flutter`). Both runners find it from
a `git worktree` on their own; for other commands use `../melodize/flutter/bin/flutter` or set
`FLUTTER_SDK`. Each worktree gets its own Linux build volumes, so two worktrees can run
`scripts/test-linux.sh` at once. Android runs share the one emulator, so run them one at a time.
