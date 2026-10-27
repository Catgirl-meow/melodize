#!/usr/bin/env bash
set -euo pipefail

# Package Linux release bundle into tar.gz for GitHub Releases.
# Usage: ./scripts/package-linux-release.sh
# Run from project root. Requires: flutter build linux --release already done.
# For a release, build with ./scripts/build-linux-release.sh instead, which builds
# in a container and then calls this script.

cd "$(git rev-parse --show-toplevel)"

version="$(grep '^version:' pubspec.yaml | sed 's/version: //' | sed 's/+.*//')"
archive="melodize-v${version}-linux-x64.tar.gz"

build_dir="build/linux/x64/release"
bundle_dir="${build_dir}/bundle"

if [ ! -d "$bundle_dir" ]; then
  echo "ERROR: bundle not found at ${bundle_dir}"
  echo "Run 'flutter build linux --release' first."
  exit 1
fi

# Refuse to ship a bundle that won't start on ordinary x86-64 machines:
# nothing may require more than x86-64-v2, or a glibc newer than max_glibc.
max_glibc="2.35"
bad=0
while IFS= read -r -d '' f; do
  file -b "$f" | grep -q '^ELF' || continue
  if readelf -n "$f" | grep 'ISA needed' | grep -qE 'x86-64-v[34]'; then
    echo "ERROR: ${f} is marked as needing $(readelf -n "$f" | grep -o 'x86-64-v[34]' | tail -1)"
    bad=1
  fi
  newest="$(objdump -T "$f" | grep -o 'GLIBC_[0-9.]*' | sed 's/GLIBC_//' | sort -uV | tail -1 || true)"
  if [ -n "$newest" ] && [ "$(printf '%s\n%s\n' "$newest" "$max_glibc" | sort -V | tail -1)" != "$max_glibc" ]; then
    echo "ERROR: ${f} needs GLIBC_${newest} (max ${max_glibc})"
    bad=1
  fi
done < <(find "$bundle_dir" -type f -print0)
if [ "$bad" -ne 0 ]; then
  echo "The bundle was linked against this machine's toolchain and is not portable."
  echo "Build it with ./scripts/build-linux-release.sh instead."
  exit 1
fi

cd "$build_dir"
tar -czf "$archive" bundle/
echo "Created: ${build_dir}/${archive}"
