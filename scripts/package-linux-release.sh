#!/usr/bin/env bash
set -euo pipefail

# Package Linux release bundle into tar.gz for GitHub Releases.
# Usage: ./scripts/package-linux-release.sh
# Run from project root. Requires: flutter build linux --release already done.

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

cd "$build_dir"
tar -czf "$archive" bundle/
echo "Created: ${build_dir}/${archive}"
