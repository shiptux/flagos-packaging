#!/usr/bin/env bash
# Build a signed YUM repository from the .rpm files under ./collected/.
#
# Output layout per distro (./yum-repo/<distro>/x86_64/):
#   repodata/repomd.xml
#   repodata/repomd.xml.asc
#   repodata/<hash>-primary.xml.gz, etc.
#
# `createrepo_c --baseurl` writes each <package> entry's <location> tag
# with an absolute URL pointing at the Release asset, mirroring what
# build-apt-repo.sh does for APT.
#
# Env:
#   GPG_KEY_ID    fingerprint of the signing key
#   RELEASE_TAG   GitHub Release tag (e.g. "v2026.04.26")
#   GH_REPO       owner/name of this repo
#   COLLECTED_DIR default: ../collected
#   OUT_DIR       default: ../yum-repo
#   DISTROS       space-separated distro slugs (default: "fedora43 el8 el9 opencloudos9 openanolis8 openeuler2403")

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COLLECTED_DIR="${COLLECTED_DIR:-${REPO_ROOT}/collected}"
OUT_DIR="${OUT_DIR:-${REPO_ROOT}/yum-repo}"
DISTROS="${DISTROS:-fedora43 el8 el9 opencloudos9 openanolis8 openeuler2403}"

: "${GPG_KEY_ID:?GPG_KEY_ID required}"
: "${RELEASE_TAG:?RELEASE_TAG required}"
: "${GH_REPO:?GH_REPO required}"

RELEASE_BASE="https://github.com/${GH_REPO}/releases/download/${RELEASE_TAG}"

rm -rf "${OUT_DIR}"

# For now, every distro gets the same RPM set. When per-distro variants
# emerge (e.g. fedora-vs-el module dependencies), add a routing layer
# in collect-artifacts that splits .rpms by target distro.
for distro in ${DISTROS}; do
    arch_dir="${OUT_DIR}/${distro}/x86_64"
    mkdir -p "${arch_dir}"
    find "${COLLECTED_DIR}" -name '*.rpm' -exec cp {} "${arch_dir}/" \;

    if ! ls "${arch_dir}"/*.rpm >/dev/null 2>&1; then
        echo "WARN: no .rpm files for ${distro}; skipping" >&2
        continue
    fi

    createrepo_c --baseurl "${RELEASE_BASE}" "${arch_dir}"

    # Sign the repomd.xml so dnf/yum can verify the metadata signature
    gpg --batch --yes --default-key "${GPG_KEY_ID}" --armor --detach-sign \
        --output "${arch_dir}/repodata/repomd.xml.asc" \
        "${arch_dir}/repodata/repomd.xml"

    # Drop the .rpms — binaries ship via Releases, not Pages
    rm -f "${arch_dir}"/*.rpm
done

echo "YUM repos built under ${OUT_DIR}/<distro>/x86_64/"
echo "<location> URLs point at ${RELEASE_BASE}/<file>"
