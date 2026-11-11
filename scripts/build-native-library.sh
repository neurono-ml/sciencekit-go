#!/usr/bin/env bash
# Build the `sciencekit_ffi` shared library that the Go binding links against
# and install it into `lib/` next to the cgo directives.
#
# The native library lives in the main sciencekit repository
# (https://github.com/neurono-ml/sciencekit). This script builds it from a
# checkout of that repository and copies the shared object next to the Go
# package, so `go build` and `go test` work without extra flags.
#
# Usage:
#   scripts/build-native-library.sh [path-to-sciencekit-checkout]
#
# The checkout defaults to $SCIENCEKIT_REPOSITORY, then to a sibling
# `../sciencekit` directory.
set -euo pipefail

binding_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repository_root="${1:-${SCIENCEKIT_REPOSITORY:-}}"

if [[ -z "$repository_root" ]]; then
  candidate="$binding_root/../sciencekit"
  if [[ -f "$candidate/Cargo.toml" ]]; then
    repository_root="$(cd "$candidate" && pwd)"
  fi
fi

if [[ -z "$repository_root" || ! -f "$repository_root/Cargo.toml" ]]; then
  cat >&2 <<'USAGE'
error: no sciencekit checkout found.

Pass the path to a checkout of https://github.com/neurono-ml/sciencekit:

  scripts/build-native-library.sh /path/to/sciencekit

or set SCIENCEKIT_REPOSITORY to the same path.
USAGE
  exit 2
fi

cd "$repository_root"

echo "Building sciencekit_ffi from $repository_root"
cargo build -p sciencekit_ffi --release

target_directory="${CARGO_TARGET_DIR:-$repository_root/target}"
library_directory="$target_directory/release"

case "$(uname -s)" in
  Darwin) library_name="libsciencekit_ffi.dylib" ;;
  MINGW* | MSYS* | CYGWIN*) library_name="sciencekit_ffi.dll" ;;
  *) library_name="libsciencekit_ffi.so" ;;
esac

install -m 0755 "$library_directory/$library_name" "$binding_root/lib/$library_name"

echo
echo "Installed $binding_root/lib/$library_name"
echo
echo "The cgo directives in this repository already point at lib/, so:"
echo
echo "  go test ./..."
echo
echo "To link against a library built elsewhere, export these instead:"
echo
echo "  export CGO_CFLAGS=\"-I/path/to/sciencekit/crates/sciencekit_ffi/include\""
echo "  export CGO_LDFLAGS=\"-L/path/to/target/release -lsciencekit_ffi\""
echo "  export LD_LIBRARY_PATH=\"/path/to/target/release:\$LD_LIBRARY_PATH\""
