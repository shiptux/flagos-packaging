#!/usr/bin/env bash
#
# Phase 0 verification runner: stages the libtriton_jit + FlagGems source
# trees into a build context and runs the verification Dockerfile.
#
# Proves FlagGems' C++ operators build+link against a prebuilt
# libtriton_jit (both cmake-install and .deb paths) in the env matching
# the flaggems-nvidia-12.8 container.
#
# Usage:
#   ./run.sh                         # clone upstream defaults
#   LIBTRITON_REF=pr/packaging ./run.sh
#   LIBTRITON_SRC=~/git/github/libtriton_jit FLAGGEMS_SRC=~/git/github/FlagGems ./run.sh
#
# Source selection (per repo): set <NAME>_SRC to use a local checkout
# (staged via `git archive` of <NAME>_REF), else clone <NAME>_REPO@<NAME>_REF.
set -euo pipefail

LIBTRITON_REPO=${LIBTRITON_REPO:-https://github.com/flagos-ai/libtriton_jit}
LIBTRITON_REF=${LIBTRITON_REF:-master}
FLAGGEMS_REPO=${FLAGGEMS_REPO:-https://github.com/flagos-ai/FlagGems}
FLAGGEMS_REF=${FLAGGEMS_REF:-master}
LIBTRITON_SRC=${LIBTRITON_SRC:-}
FLAGGEMS_SRC=${FLAGGEMS_SRC:-}

here="$(cd "$(dirname "$0")" && pwd)"
ctx="$(mktemp -d)"
trap 'rm -rf "$ctx"' EXIT

stage() {  # <name> <dest>
  local name="$1" dest="$2"
  local src_var="${name}_SRC" repo_var="${name}_REPO" ref_var="${name}_REF"
  local src="${!src_var}" repo="${!repo_var}" ref="${!ref_var}"
  mkdir -p "$ctx/$dest"
  if [ -n "$src" ]; then
    echo "[stage] $dest <- $src @ $ref (git archive)"
    git -C "$src" archive --format=tar "$ref" | tar -x -C "$ctx/$dest"
  else
    echo "[stage] $dest <- $repo @ $ref (clone)"
    git clone --depth 1 --branch "$ref" "$repo" "$ctx/$dest"
  fi
}

stage LIBTRITON libtriton_jit
stage FLAGGEMS  FlagGems
cp "$here/Dockerfile" "$ctx/Dockerfile"

echo "[build] docker build (verification)"
docker build --target verify -t phase0-flaggems-verify "$ctx"
echo
echo "Verification image built. Markers above; 'VERIFY: ALL PASSED' = success."
