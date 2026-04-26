#!/usr/bin/env bash
# Build a signed APT repository from the .deb files under ./collected/.
#
# Output layout (./apt-repo/):
#   dists/stable/InRelease
#   dists/stable/Release
#   dists/stable/Release.gpg
#   dists/stable/main/binary-amd64/Packages
#   dists/stable/main/binary-amd64/Packages.gz
#
# Key trick: after reprepro generates Packages.gz, we rewrite each
# `Filename:` field from the in-pool relative path to the absolute URL
# of the corresponding GitHub Release asset. This decouples metadata
# (served from Pages) from binaries (served from Releases) — APT
# follows the URL natively.
#
# Env:
#   GPG_KEY_ID    fingerprint of the signing key
#   RELEASE_TAG   GitHub Release tag where the .debs will be uploaded
#                 (e.g. "v2026.04.26"). Used in the Filename rewrite.
#   GH_REPO       owner/name of this repo (e.g. "flagos-ai/flagos-packaging")
#   COLLECTED_DIR default: ../collected
#   OUT_DIR       default: ../apt-repo

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COLLECTED_DIR="${COLLECTED_DIR:-${REPO_ROOT}/collected}"
OUT_DIR="${OUT_DIR:-${REPO_ROOT}/apt-repo}"
TMPL="${REPO_ROOT}/config/apt-distributions.tmpl"

: "${GPG_KEY_ID:?GPG_KEY_ID required}"
: "${RELEASE_TAG:?RELEASE_TAG required}"
: "${GH_REPO:?GH_REPO required (owner/name)}"

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}/conf"

sed "s|@GPG_KEY_ID@|${GPG_KEY_ID}|g" "${TMPL}" > "${OUT_DIR}/conf/distributions"

# Add every collected .deb to the stable distribution
find "${COLLECTED_DIR}" -name '*.deb' -print0 | \
    xargs -0 -r reprepro -b "${OUT_DIR}" includedeb stable

# Rewrite Filename: pool/... -> Filename: https://github.com/.../releases/download/<tag>/<file>
RELEASE_BASE="https://github.com/${GH_REPO}/releases/download/${RELEASE_TAG}"

PACKAGES_GZ="${OUT_DIR}/dists/stable/main/binary-amd64/Packages.gz"
PACKAGES="${OUT_DIR}/dists/stable/main/binary-amd64/Packages"

if [ ! -s "${PACKAGES}" ]; then
    echo "ERROR: reprepro did not produce ${PACKAGES}" >&2
    exit 1
fi

sed -i -E "s|^Filename: pool/[^[:space:]]*/([^/[:space:]]+\\.deb)$|Filename: ${RELEASE_BASE}/\\1|" \
    "${PACKAGES}"
gzip -kf -9 "${PACKAGES}"

# Re-sign the Release file because the Packages digest changed
cd "${OUT_DIR}/dists/stable"
rm -f Release Release.gpg InRelease
apt-ftparchive release . > Release
gpg --batch --yes --default-key "${GPG_KEY_ID}" --armor --detach-sign -o Release.gpg Release
gpg --batch --yes --default-key "${GPG_KEY_ID}" --clearsign -o InRelease Release

# Drop the pool/ tree — binaries don't ship via Pages, only via Releases
rm -rf "${OUT_DIR}/pool"

echo "APT repo built at ${OUT_DIR}"
echo "Filename URLs point at ${RELEASE_BASE}/<file>"
