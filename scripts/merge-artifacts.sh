#!/usr/bin/env bash
# Merge freshly collected artifacts with the previously published set.
#
# Why: GitHub Releases keep binaries forever, while upstream Actions
# artifacts expire after 7 days. A publish that only sees today's
# fresh artifacts would silently DROP every component that didn't
# rebuild this week (observed 2026-08-20: ecosystem-wide expiry, zero
# collectable artifacts). Merging with the last release keeps the
# repository monotonic: new files override same-name old ones, other
# versions coexist (dnf/apt pick the newest), nothing vanishes.
#
# Output: ./merged/ containing the union. New files are expected to be
# already signed (run sign-packages.sh on collected/ BEFORE this);
# carried-over files keep their existing signatures.
#
# Removing a component from the repo is deliberately NOT automatic:
# delete the asset from the latest GitHub Release, then rerun publish.
#
# Env:
#   RELEASE_TAG   tag being published now (its own release is excluded
#                 from the "previous" lookup so reruns are idempotent)
#   GH_REPO       owner/name
#   GITHUB_TOKEN  for `gh release` auth
#   COLLECTED_DIR default: ../collected   (new, signed artifacts)
#   MERGED_DIR    default: ../merged

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COLLECTED_DIR="${COLLECTED_DIR:-${REPO_ROOT}/collected}"
MERGED_DIR="${MERGED_DIR:-${REPO_ROOT}/merged}"

: "${GH_REPO:?GH_REPO required}"
export GH_TOKEN="${GH_TOKEN:?GITHUB_TOKEN required}"

rm -rf "${MERGED_DIR}"
mkdir -p "${MERGED_DIR}"

# Find the latest release that is NOT the tag we are publishing now.
PREV_TAG=""
for tag in $(gh release list --repo "${GH_REPO}" --limit 30 --json tagName --jq '.[].tagName'); do
    if [ "${tag}" != "${RELEASE_TAG:-}" ]; then
        PREV_TAG="${tag}"
        break
    fi
done

if [ -n "${PREV_TAG}" ]; then
    echo ">>> carrying over artifacts from previous release ${PREV_TAG}"
    gh release download "${PREV_TAG}" --repo "${GH_REPO}" \
        --dir "${MERGED_DIR}" --pattern '*.rpm' --pattern '*.deb' \
        --clobber 2>/dev/null \
        || echo "WARN: download from ${PREV_TAG} failed; publishing fresh set only" >&2
else
    echo ">>> no previous release found; publishing the fresh set only"
fi

CARRIED=$(find "${MERGED_DIR}" \( -name '*.rpm' -o -name '*.deb' \) | wc -l)

# Overlay today's fresh (signed) artifacts; same filename wins.
NEW=0
REPLACED=0
while IFS= read -r -d '' f; do
    base="$(basename "${f}")"
    if [ -f "${MERGED_DIR}/${base}" ]; then
        REPLACED=$((REPLACED + 1))
    else
        NEW=$((NEW + 1))
    fi
    cp -f "${f}" "${MERGED_DIR}/${base}"
done < <(find "${COLLECTED_DIR}" \( -name '*.rpm' -o -name '*.deb' \) -print0)

TOTAL=$(find "${MERGED_DIR}" \( -name '*.rpm' -o -name '*.deb' \) | wc -l)
echo ">>> merge result: ${TOTAL} files = ${CARRIED} carried over + ${NEW} new + ${REPLACED} replaced"

if [ "${TOTAL}" -eq 0 ]; then
    echo "ERROR: merged set is empty (no previous release, no fresh artifacts)" >&2
    exit 1
fi
