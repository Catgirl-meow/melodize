#!/bin/sh
# Throwaway Navidrome for testing Melodize (never point tests at production).
#
#   scripts/test-navidrome.sh up      create/start the server + test library
#   scripts/test-navidrome.sh reset   restore the generated library and rescan
#   scripts/test-navidrome.sh env     print the MELODIZE_TEST_* exports
#   scripts/test-navidrome.sh down    stop the server
#
# Needs podman (or docker: ENGINE=docker). Data lives in $MELODIZE_TESTND_DIR
# (default ~/.local/share/melodize-testnd).
set -eu
ENGINE=${ENGINE:-podman}
VERSION=${NAVIDROME_VERSION:-0.64.0}
PORT=${MELODIZE_TESTND_PORT:-4534}
B=${MELODIZE_TESTND_DIR:-$HOME/.local/share/melodize-testnd}
NAME=melodize-test-navidrome
IMAGE=docker.io/deluan/navidrome:$VERSION
HERE=$(cd "$(dirname "$0")" && pwd)

creds() { . "$B/credentials"; }

case "${1:-up}" in
up)
  mkdir -p "$B/data" "$B/music"
  if [ ! -d "$B/music.pristine" ]; then
    "$ENGINE" run --rm -v "$B/music:/music:Z" -v "$HERE/gen-test-library.sh:/gen.sh:ro,Z" \
      --entrypoint sh "$IMAGE" /gen.sh
    cp -a "$B/music" "$B/music.pristine"
  fi
  if "$ENGINE" container exists "$NAME" 2>/dev/null || "$ENGINE" inspect "$NAME" >/dev/null 2>&1; then
    "$ENGINE" start "$NAME" >/dev/null
  else
    "$ENGINE" run -d --name "$NAME" -p "$PORT:4533" \
      -v "$B/data:/data:Z" -v "$B/music:/music:Z" \
      -e ND_SCANNER_SCHEDULE=0 -e ND_ENABLEINSIGHTSCOLLECTOR=false -e ND_LASTFM_ENABLED=false \
      "$IMAGE" >/dev/null
  fi
  i=0; until curl -fs "http://localhost:$PORT/ping" >/dev/null; do
    i=$((i+1)); [ $i -gt 30 ] && { echo "navidrome did not start" >&2; exit 1; }; sleep 1; done
  if [ ! -f "$B/credentials" ]; then
    PW=$(openssl rand -hex 8)
    curl -fs -X POST "http://localhost:$PORT/auth/createAdmin" -H 'Content-Type: application/json' \
      -d "{\"username\":\"test\",\"password\":\"$PW\"}" >/dev/null
    umask 077
    printf 'local=http://localhost:%s\nuser=test\npassword=%s\n' "$PORT" "$PW" > "$B/credentials"
  fi
  echo "Navidrome $VERSION on http://localhost:$PORT (credentials: $B/credentials)"
  ;;
reset)
  creds
  rm -rf "$B/music"/* && cp -a "$B/music.pristine"/. "$B/music"/
  curl -fs "$local/rest/startScan?u=$user&p=$password&v=1.16.1&c=reset&f=json&fullScan=true" >/dev/null
  echo "library restored, full scan started"
  ;;
env)
  creds
  echo "export MELODIZE_TEST_SERVER=$local MELODIZE_TEST_USER=$user MELODIZE_TEST_PASSWORD=$password"
  ;;
down) "$ENGINE" stop "$NAME" >/dev/null ;;
*) echo "usage: $0 up|reset|env|down" >&2; exit 2 ;;
esac
