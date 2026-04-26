#!/usr/bin/env bash
# Collect built .deb/.rpm artifacts from upstream repos into ./collected/.
#
# Reads components/*.yml and pulls artifacts from each upstream's GitHub
# Actions runs via dawidd6/action-download-artifact (called from the
# publish.yml workflow, not here — this script handles the matrix
# expansion logic locally).
#
# Output layout:
#   collected/<component>/deb/<artifact>/*.deb
#   collected/<component>/rpm/<artifact>/*.rpm
#
# Env (set by publish.yml or operator):
#   GITHUB_TOKEN   for cross-repo artifact reads
#   COMPONENTS_DIR default: ../components

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPONENTS_DIR="${COMPONENTS_DIR:-${REPO_ROOT}/components}"
OUT_DIR="${OUT_DIR:-${REPO_ROOT}/collected}"

if ! command -v yq >/dev/null 2>&1; then
    echo "ERROR: yq is required (https://github.com/mikefarah/yq)" >&2
    exit 1
fi

mkdir -p "${OUT_DIR}"

# Emit a JSON matrix consumed by GitHub Actions when invoked via
# `--emit-matrix`. Otherwise, just print the list of components.
case "${1:-list}" in
    --emit-matrix)
        # Format: {"include": [{"component":"flagcx","upstream":"flagos-ai/FlagCX","format":"deb",...}, ...]}
        printf '{"include":['
        first=1
        for f in "${COMPONENTS_DIR}"/*.yml; do
            [ "$f" = "${COMPONENTS_DIR}/README.md" ] && continue
            name=$(yq -r '.name' "$f")
            upstream=$(yq -r '.upstream' "$f")
            for fmt in deb rpm; do
                workflow=$(yq -r ".workflows.${fmt}.name // empty" "$f")
                pattern=$(yq -r ".workflows.${fmt}.artifact_pattern // empty" "$f")
                if [ -n "$workflow" ] && [ -n "$pattern" ]; then
                    [ $first -eq 0 ] && printf ','
                    first=0
                    printf '{"component":"%s","upstream":"%s","format":"%s","workflow":"%s","pattern":"%s"}' \
                        "$name" "$upstream" "$fmt" "$workflow" "$pattern"
                fi
            done
        done
        printf ']}\n'
        ;;
    list)
        for f in "${COMPONENTS_DIR}"/*.yml; do
            [ "$f" = "${COMPONENTS_DIR}/README.md" ] && continue
            yq -r '.name + " (" + .upstream + ")"' "$f"
        done
        ;;
    *)
        echo "Usage: $0 [list|--emit-matrix]" >&2
        exit 1
        ;;
esac
