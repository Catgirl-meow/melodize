# Installing Melodize

You need a running [Navidrome](https://www.navidrome.org/) (or another Subsonic-compatible
server). On first start, Melodize asks for its URL, your username and your password.

## Android

Android 8.0 or later. Download `app-release.apk` from
[Releases](https://github.com/Catgirl-meow/melodize/releases) and install it (allow installs from
your browser or file manager when asked). Updates install over the old version and keep your
settings and downloads.

## Linux

Melodize plays audio through **libmpv**, so install it first:

| Distro | Command |
|---|---|
| Debian / Ubuntu 22.04+ | `apt install libmpv2` |
| Fedora | `dnf install mpv-libs` |
| Arch | `pacman -S mpv` |
| Gentoo | `emerge media-video/mpv` |

Then unpack the release and run it:

```sh
mkdir -p ~/melodize
tar -xzf melodize-*-linux-x64.tar.gz -C ~/melodize
~/melodize/melodize
```

If it fails to start, GTK 3 is missing (`apt install libgtk-3-0` or `pacman -S gtk3`).
Settings, the library cache and downloads live in `~/.local/share/com.catgirl.melodize/`.
Playback shows up in MPRIS, so `playerctl` and your desktop's media keys work.

## macOS

macOS 12 or later. There is no prebuilt app yet; build it on a Mac with
Xcode 15+:

```sh
xcode-select --install
flutter pub get
flutter build macos --release   # build/macos/Build/Products/Release/melodize.app
```

The build is ad-hoc signed, so it runs on the Mac that built it; giving it to others needs a
Developer ID signature and notarization. The app is sandboxed and keeps its data in
`~/Library/Containers/com.catgirl.melodize/Data/`.

- Plain-HTTP servers work (there is an App Transport Security exception).
- macOS playback (AVFoundation) does not accept self-signed HTTPS certificates. Use plain HTTP on
  your LAN or a trusted certificate.

## Building from source

Flutter 3.44 (the repo expects it at `./flutter/`, but a system Flutter works too).

| Target | Needs | Command | Output |
|---|---|---|---|
| Android | Android SDK | `flutter build apk` | `build/app/outputs/flutter-apk/` |
| Linux | GTK 3 headers, CMake, Ninja, clang, libmpv-dev | `flutter build linux --release` | `build/linux/x64/release/bundle/` |
| macOS | a Mac with Xcode 15+ | `flutter build macos --release` | `build/macos/Build/Products/Release/` |

`scripts/package-linux-release.sh` packs the Linux bundle into the release tarball.

## Deezer

Recommendations, Deezer search and 30-second previews use Deezer's public API and need no
account. Downloading full FLAC tracks into your library needs the
[companion](companion.md) and a Deezer HiFi account:

1. Log in at [deezer.com](https://www.deezer.com) in a desktop browser.
2. Open DevTools, then **Application → Cookies**, and copy the value of the `arl` cookie.
3. Paste it into **Settings → Deezer → Connect account**.

Melodize checks the ARL and shows a banner on Home when it expires.

## Keyboard shortcuts (Linux and macOS)

| Key | Action |
|---|---|
| `Space` | Play / pause |
| `N` / `P` | Next / previous |
| `L` / `H` | Seek forward / back 5 s (`Shift` for 30 s) |
| `0` | Back to the start of the song |
| `K` / `J` | Volume up / down |
| `M` | Mute |
| `S` | Cycle shuffle mode |
| `R` | Cycle repeat mode |

Shortcuts are ignored while a text field has focus or Ctrl, Cmd or Alt is held.
