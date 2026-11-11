#!/usr/bin/env bash
# Copy the stable C ABI header from a checkout of the main sciencekit
# repository into `include/`, so the vendored copy used by the cgo directives
# never drifts from the ABI it targets.
#
# Usage:
#   scripts/sync-header.sh [path-to-sciencekit-checkout]
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

  scripts/sync-header.sh /path/to/sciencekit

or set SCIENCEKIT_REPOSITORY to the same path.
USAGE
  exit 2
fi

source_header="$repository_root/crates/sciencekit_ffi/include/sciencekit.h"
if [[ ! -f "$source_header" ]]; then
  echo "error: $source_header not found" >&2
  exit 1
fi

install -m 0644 "$source_header" "$binding_root/include/sciencekit.h"
echo "Updated $binding_root/include/sciencekit.h from $source_header"
