#!/usr/bin/env bash
set -euo pipefail

# Build the Linux release bundle inside an Ubuntu 22.04 container, then package it.
# Usage: ./scripts/build-linux-release.sh
# Requires: podman (or docker via CONTAINER=docker) and a Flutter SDK at ./flutter
# (override with FLUTTER_SDK=/path/to/flutter).
#
# Why a container: a bundle linked on the dev machine inherits that machine's
# toolchain. On a Gentoo host whose glibc was built with -march=native, every
# executable gets an "x86 ISA needed: x86-64-v4" note from Scrt1.o and the
# loader refuses to start it on CPUs without AVX-512 ("CPU ISA level is lower
# than required"). It also picks up symbols from a bleeding-edge glibc
# (e.g. GLIBC_2.44). Ubuntu 22.04 gives a baseline x86-64, glibc 2.35 build.

cd "$(git rev-parse --show-toplevel)"

engine="${CONTAINER:-podman}"
image="melodize-linux-build:22.04"
sdk="$(realpath "${FLUTTER_SDK:-./flutter}")"
pub_cache="${PUB_CACHE:-$HOME/.pub-cache}"

if [ ! -x "$sdk/bin/flutter" ]; then
  echo "ERROR: Flutter SDK not found at ${sdk} (set FLUTTER_SDK)."
  exit 1
fi
mkdir -p "$pub_cache"

"$engine" build -t "$image" - <<'EOF'
FROM docker.io/library/ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates clang cmake curl file git libgtk-3-dev liblzma-dev \
      libstdc++-12-dev make ninja-build pkg-config unzip xz-utils \
    && rm -rf /var/lib/apt/lists/*
RUN git config --global --add safe.directory '*'
EOF

# The worktree's own build/ would otherwise mix host and container CMake caches.
rm -rf build/linux

"$engine" run --rm \
  -v "$PWD:/src" \
  -v "$sdk:/flutter" \
  -v "$pub_cache:/root/.pub-cache" \
  -w /src \
  -e PUB_CACHE=/root/.pub-cache \
  "$image" \
  bash -c '/flutter/bin/flutter config --no-analytics >/dev/null &&
           /flutter/bin/flutter pub get &&
           /flutter/bin/flutter build linux --release'

./scripts/package-linux-release.sh
