#!/usr/bin/env bash
# Run the integration tests on a headless Android emulator against the
# throwaway Navidrome (scripts/test-navidrome.sh). The emulator runs with
# -no-window -no-audio, so nothing opens on your desktop or plays aloud.
#
# Usage:
#   scripts/test-android.sh                     # every file in integration_test/
#   scripts/test-android.sh integration_test/app_flows_test.dart [...]
#
# Env:
#   AVD=melodize_test        emulator to boot when no device is connected
#   ANDROID_SERIAL=...       use this device instead (a running emulator or phone)
#   KEEP_EMULATOR=1          leave an emulator this script booted running
#   FLUTTER_SDK              default ./flutter, or the main checkout's in a worktree
#   EXTRA_DEFINES            extra "--dart-define=K=V ..." flags
#
# Needs the Android SDK (ANDROID_HOME, default ~/Android/Sdk) with the
# emulator and an x86_64 system image. The first APK build takes ~3 min;
# later builds are incremental.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

sdk_android="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
adb="$sdk_android/platform-tools/adb"
emulator="$sdk_android/emulator/emulator"
avd="${AVD:-melodize_test}"
pkg=com.hiby.music
if [ -z "${FLUTTER_SDK:-}" ]; then
  if [ -x ./flutter/bin/flutter ]; then FLUTTER_SDK=./flutter
  else FLUTTER_SDK="$(git worktree list --porcelain | awk 'NR==1{print $2}')/flutter"; fi
fi
flutter="$(realpath "$FLUTTER_SDK")/bin/flutter"
creds="${MELODIZE_TESTND_DIR:-$HOME/.local/share/melodize-testnd}/credentials"

[ -x "$adb" ] || { echo "No Android SDK at $sdk_android (set ANDROID_HOME)" >&2; exit 1; }
[ -x "$flutter" ] || { echo "Flutter SDK not found at $FLUTTER_SDK" >&2; exit 1; }
[ -f "$creds" ] || { echo "No test server: run scripts/test-navidrome.sh up" >&2; exit 1; }
# shellcheck disable=SC1090
. "$creds"
curl -fs "$local/ping" >/dev/null || { echo "Test server $local is down: scripts/test-navidrome.sh up" >&2; exit 1; }
port="${local##*:}"
# The emulator reaches the host's localhost as 10.0.2.2.
nd_url="http://10.0.2.2:$port"

started=""
serial="${ANDROID_SERIAL:-}"
if [ -z "$serial" ]; then
  serial="$("$adb" devices | awk '/^emulator-[0-9]+\tdevice$/{print $1; exit}')"
fi
if [ -z "$serial" ]; then
  log="${XDG_RUNTIME_DIR:-/tmp}/melodize-emulator.log"
  echo "Booting headless emulator $avd (log: $log)"
  setsid "$emulator" -avd "$avd" -no-window -no-audio -no-boot-anim \
    -gpu swiftshader_indirect -no-snapshot-save >"$log" 2>&1 < /dev/null &
  started=1
  "$adb" wait-for-device
  serial="$("$adb" devices | awk '/^emulator-[0-9]+\t/{print $1; exit}')"
  for _ in $(seq 1 120); do
    [ "$("$adb" -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ] && break
    sleep 1
  done
fi
export ANDROID_SERIAL="$serial"
cleanup() {
  if [ -n "$started" ] && [ -z "${KEEP_EMULATOR:-}" ]; then
    "$adb" -s "$serial" emu kill >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT
echo "Device: $serial"

# No animations (faster, steadier frames), screen always on.
for k in window_animation_scale transition_animation_scale animator_duration_scale; do
  "$adb" shell settings put global "$k" 0
done
"$adb" shell svc power stayon true >/dev/null 2>&1 || true
"$adb" shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1 || true

[ $# -eq 0 ] && set -- integration_test/*_test.dart

fail=0
for f in "$@"; do
  echo "=== $f"
  start=$(date +%s)
  # Each file starts from an empty app profile, with the notification
  # permission already granted so its dialog never covers the app.
  if "$adb" shell pm path "$pkg" >/dev/null 2>&1; then
    "$adb" shell pm clear "$pkg" >/dev/null
    "$adb" shell pm grant "$pkg" android.permission.POST_NOTIFICATIONS >/dev/null 2>&1 || true
  fi
  # shellcheck disable=SC2086
  if "$flutter" test "$f" -d "$serial" \
      --dart-define=ND_URL="$nd_url" --dart-define=ND_USER="$user" \
      --dart-define=ND_PASS="$password" ${EXTRA_DEFINES:-}; then
    echo "=== PASS $f ($(( $(date +%s) - start ))s)"
  else
    echo "=== FAIL $f ($(( $(date +%s) - start ))s)"; fail=1
  fi
done
exit $fail
