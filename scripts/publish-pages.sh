#!/usr/bin/env bash
# Push the generated APT/YUM metadata to the gh-pages branch.
#
# Layout on gh-pages:
#   /pubkey.gpg                              (the signing key, public)
#   /apt/dists/stable/...                    (APT metadata, no binaries)
#   /rpm/<distro>/x86_64/repodata/...        (YUM metadata, no binaries)
#   /flagos.repo                             (template .repo file for dnf)
#   /index.html                              (small landing page)
#
# Env:
#   GH_REPO         owner/name
#   APT_DIR         default: ../apt-repo
#   YUM_DIR         default: ../yum-repo
#   PAGES_BRANCH    default: gh-pages
#   GPG_PUBLIC_KEY  path to the armored .asc public key

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APT_DIR="${APT_DIR:-${REPO_ROOT}/apt-repo}"
YUM_DIR="${YUM_DIR:-${REPO_ROOT}/yum-repo}"
PAGES_BRANCH="${PAGES_BRANCH:-gh-pages}"
GPG_PUBLIC_KEY="${GPG_PUBLIC_KEY:-${REPO_ROOT}/config/gpg-key.pub}"
STAGING="$(mktemp -d)"

: "${GH_REPO:?GH_REPO required}"

# Stage the new tree
mkdir -p "${STAGING}/apt" "${STAGING}/rpm"
[ -d "${APT_DIR}/dists" ] && cp -a "${APT_DIR}/dists" "${STAGING}/apt/"
[ -d "${YUM_DIR}" ] && cp -a "${YUM_DIR}/." "${STAGING}/rpm/"
[ -f "${GPG_PUBLIC_KEY}" ] && cp "${GPG_PUBLIC_KEY}" "${STAGING}/pubkey.gpg"

# .repo template, expanded with the actual Pages URL
PAGES_BASE="https://${GH_REPO%%/*}.github.io/${GH_REPO##*/}"
sed "s|@PAGES_BASE@|${PAGES_BASE}|g" "${REPO_ROOT}/config/yum-repo.tmpl" > "${STAGING}/flagos.repo"

# Tiny landing page
cat > "${STAGING}/index.html" <<HTML
<!doctype html>
<html><head><meta charset="utf-8"><title>FlagOS Packaging</title></head>
<body>
<h1>FlagOS Packaging</h1>
<p>APT and YUM repositories for the FlagOS software stack.</p>
<ul>
<li><a href="apt/">APT (Debian/Ubuntu)</a></li>
<li><a href="rpm/">YUM (Fedora/RHEL/OpenEuler/...)</a></li>
<li><a href="pubkey.gpg">GPG public key</a></li>
<li><a href="flagos.repo">flagos.repo (for dnf config-manager)</a></li>
</ul>
<p>See <a href="https://github.com/${GH_REPO}/blob/main/docs/install.md">install instructions</a>.</p>
</body></html>
HTML

# Push to gh-pages using a worktree to avoid touching the main branch
cd "${REPO_ROOT}"
git worktree add -B "${PAGES_BRANCH}" /tmp/flagos-pages "origin/${PAGES_BRANCH}" 2>/dev/null \
    || git worktree add --orphan -B "${PAGES_BRANCH}" /tmp/flagos-pages

(
    cd /tmp/flagos-pages
    rm -rf ./*
    cp -a "${STAGING}/." .
    git add -A
    if git diff --cached --quiet; then
        echo "no metadata changes; skipping push"
    else
        git -c user.email=pages-bot@flagos.io -c user.name="FlagOS Pages Bot" \
            commit -m "publish: refresh APT/YUM metadata"
        git push -f origin "${PAGES_BRANCH}"
    fi
)

git worktree remove /tmp/flagos-pages --force
rm -rf "${STAGING}"

echo "metadata pushed to ${PAGES_BRANCH} branch"
