#!/usr/bin/env bash
# Build a signed APT repository from the .deb files under ./collected/.
#
# Design (revised 2026-05-19): both metadata AND binaries live on
# gh-pages. Earlier attempt at "metadata on Pages, binaries on
# Releases via Filename rewrite" doesn't work because apt treats the
# Filename: field as a relative path and prepends the repo source
# URL — it does NOT follow absolute URLs in Filename. So we keep
# pool/ in the apt-repo output and ship it to gh-pages too.
#
# Output layout (./apt-repo/):
#   dists/stable/InRelease
#   dists/stable/Release
#   dists/stable/Release.gpg
#   dists/stable/main/binary-amd64/Packages
#   dists/stable/main/binary-amd64/Packages.gz
#   pool/main/<initial>/<source>/<package>_<version>_<arch>.deb
#
# Env:
#   GPG_KEY_ID    fingerprint of the signing key
#   COLLECTED_DIR default: ../collected
#   OUT_DIR       default: ../apt-repo

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COLLECTED_DIR="${COLLECTED_DIR:-${REPO_ROOT}/collected}"
OUT_DIR="${OUT_DIR:-${REPO_ROOT}/apt-repo}"
TMPL="${REPO_ROOT}/config/apt-distributions.tmpl"

: "${GPG_KEY_ID:?GPG_KEY_ID required}"

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}/conf"

sed "s|@GPG_KEY_ID@|${GPG_KEY_ID}|g" "${TMPL}" > "${OUT_DIR}/conf/distributions"

# gh-pages rejects files over 100 MB, and pool/ ships to gh-pages
# (see design note above). Skip oversized .debs with a loud warning
# instead of failing the whole publish — serving big packages needs a
# Releases-based flat-repo route, not yet implemented.
DEB_SIZE_CAP="${DEB_SIZE_CAP:-95M}"
find "${COLLECTED_DIR}" -name '*.deb' -size "+${DEB_SIZE_CAP}" | while read -r deb; do
    echo "::warning::skipping $(basename "${deb}") ($(du -h "${deb}" | cut -f1)) — exceeds ${DEB_SIZE_CAP} gh-pages cap, not indexed in APT" >&2
done

# Add every remaining collected .deb to the stable distribution.
# reprepro signs the Release file itself when SignWith: is set in the
# distributions config, so we don't need to manually re-sign here.
find "${COLLECTED_DIR}" -name '*.deb' ! -size "+${DEB_SIZE_CAP}" -print0 | \
    xargs -0 -r reprepro -b "${OUT_DIR}" includedeb stable

PACKAGES="${OUT_DIR}/dists/stable/main/binary-amd64/Packages"
if [ ! -s "${PACKAGES}" ]; then
    echo "ERROR: reprepro did not produce ${PACKAGES}" >&2
    exit 1
fi

echo "APT repo built at ${OUT_DIR}"
echo "pool/ tree retained for ship-with-metadata serving on gh-pages"
echo "$(find "${OUT_DIR}/pool" -name '*.deb' 2>/dev/null | wc -l) .deb files in pool/"
