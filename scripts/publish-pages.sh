#!/usr/bin/env bash
# Push the generated APT/YUM metadata to the gh-pages branch.
#
# Layout on gh-pages:
#   /pubkey.gpg                              (the signing key, public)
#   /apt/dists/stable/...                    (APT metadata, no binaries)
#   /rpm/<distro>/x86_64/repodata/...        (YUM metadata, no binaries)
#   /flagos-<distro>.repo                    (per-distro .repo files for dnf)
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
[ -d "${APT_DIR}/dists" ] && cp -a "${APT_DIR}/dists" "${STAGING}/apt/"; [ -d "${APT_DIR}/pool" ] && cp -a "${APT_DIR}/pool" "${STAGING}/apt/"
[ -d "${YUM_DIR}" ] && cp -a "${YUM_DIR}/." "${STAGING}/rpm/"
cp "${GPG_PUBLIC_KEY}" "${STAGING}/pubkey.gpg"  # required for apt-key

# Per-distro .repo files, one per rpm/<distro>/ directory, with the
# baseurl hardcoded. (A single $releasever-style .repo can't work:
# no dnf defines a variable that maps to our distro slugs, and e.g.
# openEuler's $releasever is "24.03LTS".)
PAGES_BASE="https://${GH_REPO%%/*}.github.io/${GH_REPO##*/}"
YUM_DISTROS=""
for d in "${STAGING}"/rpm/*/; do
    [ -d "${d}" ] || continue
    distro="$(basename "${d}")"
    YUM_DISTROS="${YUM_DISTROS} ${distro}"
    sed -e "s|@PAGES_BASE@|${PAGES_BASE}|g" -e "s|@DISTRO@|${distro}|g" \
        "${REPO_ROOT}/config/yum-repo.tmpl" > "${STAGING}/flagos-${distro}.repo"
done

# Landing page with copy-pasteable quickstart blocks
cat > "${STAGING}/index.html" <<HTML
<!doctype html>
<html><head><meta charset="utf-8"><title>FlagOS Packaging</title>
<style>
body { font-family: system-ui, -apple-system, sans-serif; max-width: 760px; margin: 2em auto; padding: 0 1em; line-height: 1.5; color: #222; }
h1 { margin-top: 0; }
h2 { margin-top: 1.6em; border-bottom: 1px solid #eee; padding-bottom: .2em; }
pre { background: #f6f8fa; padding: .8em 1em; border-radius: 6px; overflow-x: auto; }
code { font-family: ui-monospace, "SF Mono", Menlo, Consolas, monospace; font-size: 0.95em; }
ul.files { padding-left: 1.2em; }
ul.files li { margin: .2em 0; }
a { color: #0969da; }
.note { background: #fff8c5; border-left: 4px solid #d4a72c; padding: .6em .9em; border-radius: 4px; }
</style>
</head>
<body>
<h1>FlagOS Packaging</h1>
<p>APT and YUM repositories for the FlagOS software stack.</p>

<p class="note">This endpoint is a <b>sandbox</b> at
<code>${PAGES_BASE}</code>. The production endpoint is planned at
<code>https://flagos-ai.github.io/flagos-packaging</code>; both
serve the same package set during the migration period.</p>

<h2>Ubuntu / Debian</h2>
<pre><code>sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL ${PAGES_BASE}/pubkey.gpg | \\
  sudo gpg --dearmor -o /etc/apt/keyrings/flagos.gpg

echo "deb [signed-by=/etc/apt/keyrings/flagos.gpg] \\
  ${PAGES_BASE}/apt stable main" | \\
  sudo tee /etc/apt/sources.list.d/flagos.list

sudo apt update
sudo apt install libflagcx-nvidia python3-flagscale python3-flagtree-nvidia</code></pre>

<h2>Fedora / Rocky / OpenEuler / OpenCloudOS / OpenAnolis</h2>
<p>Pick the .repo file matching your distro
(available:<code>${YUM_DISTROS}</code>):</p>
<pre><code>sudo curl -fsSL ${PAGES_BASE}/flagos-&lt;distro&gt;.repo \\
  -o /etc/yum.repos.d/flagos.repo

sudo dnf makecache -y   # imports the FlagOS signing key
sudo dnf install libflagcx-nvidia python3-flagscale python3-flagtree-nvidia</code></pre>
<p>e.g. <code>flagos-openeuler2403.repo</code> for openEuler 24.03,
<code>flagos-fedora43.repo</code> for Fedora 43. The curl form works on
both dnf4 and dnf5 and needs no <code>dnf-plugins-core</code>.</p>

<h2>Available files</h2>
<ul class="files">
<li><a href="apt/">apt/</a> — APT repository (Debian/Ubuntu)</li>
<li><a href="rpm/">rpm/</a> — YUM repository (Fedora/RHEL/OpenEuler/...)</li>
<li><a href="pubkey.gpg">pubkey.gpg</a> — GPG signing public key</li>
<li><code>flagos-&lt;distro&gt;.repo</code> — per-distro dnf repo files (see above)</li>
</ul>

<p>Full guide: <a href="https://github.com/${GH_REPO}/blob/main/docs/install.md">install.md</a>
(<a href="https://github.com/${GH_REPO}/blob/main/docs/install_cn.md">中文</a>).
Compatibility matrix: <a href="https://github.com/${GH_REPO}/blob/main/docs/compatibility-status.md">docs/compatibility-status.md</a>.</p>
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
    git add -Af
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
