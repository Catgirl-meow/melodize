#!/usr/bin/env bash
# Run the Linux integration tests headless, in a container, against the
# throwaway Navidrome (scripts/test-navidrome.sh). Nothing opens on your
# desktop and nothing plays on your speakers:
#
#   - the app runs under Xvfb (a virtual X display) inside the container,
#   - audio goes to a PulseAudio null sink inside the container,
#   - app data (drift DB, server config, downloads) lives in the container's
#     scratch home, never in your ~/.local/share.
#
# Usage:
#   scripts/test-linux.sh                       # every file in integration_test/
#   scripts/test-linux.sh integration_test/app_flows_test.dart [...]
#   scripts/test-linux.sh --shell               # debug shell inside the container
#
# Env: FLUTTER_SDK (default ./flutter, or the main checkout's when run from a
# worktree), CONTAINER (podman|docker), EXTRA_DEFINES ("--dart-define=K=V ...").
# The first run builds the image (~2 min) and the app (~2 min); later runs
# reuse both through named volumes and take well under a minute per file.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

engine="${CONTAINER:-podman}"
image="melodize-linux-test:22.04"
here="$PWD"
if [ -z "${FLUTTER_SDK:-}" ]; then
  if [ -x ./flutter/bin/flutter ]; then
    FLUTTER_SDK=./flutter
  else
    # Worktrees: the SDK only lives in the main checkout.
    main="$(git worktree list --porcelain | awk 'NR==1{print $2}')"
    FLUTTER_SDK="$main/flutter"
  fi
fi
sdk="$(realpath "$FLUTTER_SDK")"
pub_cache="${PUB_CACHE:-$HOME/.pub-cache}"
creds="${MELODIZE_TESTND_DIR:-$HOME/.local/share/melodize-testnd}/credentials"

[ -x "$sdk/bin/flutter" ] || { echo "Flutter SDK not found at $sdk (set FLUTTER_SDK)" >&2; exit 1; }
[ -f "$creds" ] || { echo "No test server: run scripts/test-navidrome.sh up" >&2; exit 1; }
# shellcheck disable=SC1090
. "$creds"
curl -fs "$local/ping" >/dev/null || { echo "Test server $local is down: scripts/test-navidrome.sh up" >&2; exit 1; }
mkdir -p "$pub_cache"

"$engine" build -q -t "$image" - >/dev/null <<'EOF'
FROM docker.io/library/ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates clang cmake curl file git libgtk-3-dev liblzma-dev \
      libstdc++-12-dev make ninja-build pkg-config unzip xz-utils \
      libmpv-dev xvfb xauth dbus dbus-x11 pulseaudio \
    && rm -rf /var/lib/apt/lists/*
RUN git config --global --add safe.directory '*'
EOF

if [ "${1:-}" = "--shell" ]; then
  cmd=(bash)
  shift
else
  if [ $# -eq 0 ]; then
    set -- integration_test/*_test.dart
  fi
  # One file per `flutter test` call: on desktop each file is its own app
  # launch anyway, and a crash in one file then can't hide the others.
  inner='set -u
export HOME=/tmp/home XDG_RUNTIME_DIR=/tmp/run
# The container user is root (your own uid outside); silence the warning.
export FLUTTER_SUPPRESS_ANALYTICS=true CI=true
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
pulseaudio --daemonize=yes --exit-idle-time=-1 --log-target=stderr 2>/dev/null \
  && pactl load-module module-null-sink sink_name=null >/dev/null && pactl set-default-sink null
$FLUTTER config --no-analytics >/dev/null
$FLUTTER pub get >/dev/null || exit 1
fail=0
for f in "$@"; do
  echo "=== $f"
  start=$(date +%s)
  # shellcheck disable=SC2086
  if xvfb-run -a -s "-screen 0 1280x900x24" dbus-run-session -- \
      $FLUTTER test "$f" -d linux --no-pub \
      --dart-define=ND_URL="$ND_URL" --dart-define=ND_USER="$ND_USER" \
      --dart-define=ND_PASS="$ND_PASS" $EXTRA_DEFINES; then
    echo "=== PASS $f ($(( $(date +%s) - start ))s)"
  else
    echo "=== FAIL $f ($(( $(date +%s) - start ))s)"; fail=1
  fi
  # Each file starts from an empty app profile.
  rm -rf "$HOME/.local/share" "$HOME/.config" "$HOME/.cache"
done
exit $fail'
  cmd=(bash -c "$inner" bash "$@")
fi

# One pair of cache volumes per checkout, so worktrees can test in parallel.
vol="melodize-test-$(printf %s "$here" | sha1sum | cut -c1-8)"

# connectivity_plus asks NetworkManager on the system bus whether the device
# is online; lend it the host's bus (read-only queries) when there is one.
sysbus=()
[ -S /run/dbus/system_bus_socket ] &&
  sysbus=(-v /run/dbus/system_bus_socket:/run/dbus/system_bus_socket)

tty=()
[ -t 0 ] && [ -t 1 ] && tty=(-it)

# The checkout, SDK and pub cache are mounted at their host paths: pub get and
# the build write absolute paths (linux/flutter/ephemeral plugin symlinks,
# android/local.properties) that must stay valid for host builds and other
# threads using the same checkout. build/ and .dart_tool/ are named volumes so
# the container's CMake cache never mixes with a host build.
exec "$engine" run --rm "${tty[@]}" "${sysbus[@]}" --network host \
  -v "$here:$here" \
  -v "$vol-build:$here/build" \
  -v "$vol-dart-tool:$here/.dart_tool" \
  -v "$sdk:$sdk" \
  -v "$pub_cache:$pub_cache" \
  -w "$here" \
  -e FLUTTER="$sdk/bin/flutter" -e PUB_CACHE="$pub_cache" \
  -e ND_URL="$local" -e ND_USER="$user" -e ND_PASS="$password" \
  -e EXTRA_DEFINES="${EXTRA_DEFINES:-}" \
  "$image" "${cmd[@]}"
