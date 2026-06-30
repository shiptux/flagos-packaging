#!/usr/bin/env bash
# Launch the FlagGems-on-AMD verification in a rocm/pytorch container with
# the host AMD GPU passed through.
#
# Requirements (host): amdgpu kernel driver loaded; /dev/kfd + /dev/dri
# present; the invoking user in the render + video groups (so no sudo).
#
# Env:
#   FLAGGEMS_SRC   path to a FlagGems checkout (default ~/git/github/FlagGems)
#   GFX_OVERRIDE   HSA_OVERRIDE_GFX_VERSION value. Needed for gfx1103
#                  (Radeon 780M, Phoenix) -> 11.0.0. Leave EMPTY for a
#                  natively-supported card (e.g. 880M / gfx1150).
#   ROCM_IMAGE     container image (default rocm/pytorch:latest, ~30 GB)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
FLAGGEMS_SRC="${FLAGGEMS_SRC:-$HOME/git/github/FlagGems}"
GFX_OVERRIDE="${GFX_OVERRIDE:-11.0.0}"
ROCM_IMAGE="${ROCM_IMAGE:-rocm/pytorch:latest}"

# render/video GIDs from the host (docker --group-add wants numeric GIDs)
RENDER_GID="$(getent group render | cut -d: -f3)"
VIDEO_GID="$(getent group video  | cut -d: -f3)"

args=( --rm --device=/dev/kfd --device=/dev/dri
       --group-add "${VIDEO_GID}" --group-add "${RENDER_GID}"
       --security-opt seccomp=unconfined
       -v "${FLAGGEMS_SRC}:/FlagGems:ro"
       -v "${here}/verify.sh:/verify.sh:ro" )
[ -n "${GFX_OVERRIDE}" ] && args+=( -e "HSA_OVERRIDE_GFX_VERSION=${GFX_OVERRIDE}" )

echo "[run] image=${ROCM_IMAGE} gfx_override=${GFX_OVERRIDE:-<none>} flaggems=${FLAGGEMS_SRC}"
docker run "${args[@]}" "${ROCM_IMAGE}" bash /verify.sh
