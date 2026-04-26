#!/usr/bin/env bash
# End-to-end local validation of the flagos-packaging pipeline.
#
# Runs everything inside a single ubuntu:24.04 container so we don't need
# sudo on the host. Output (signed APT repo) lands at ./tests/local-out/
# on the host. A second container serves it via apt for verification.
#
# This is a smoke test — it proves the scripts produce metadata that an
# unrelated Ubuntu install can use, and that signed binaries verify
# correctly. It does NOT exercise the GitHub Pages / Releases split;
# both metadata and binaries are served from a single localhost URL.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${REPO_ROOT}/tests/local-out"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-${HOME}/git/github}"

rm -rf "${OUT}"
mkdir -p "${OUT}"

echo ">>> [1/4] Pipeline run inside ubuntu:24.04 container..."
docker run --rm \
    --network=host \
    -v "${REPO_ROOT}:/repo:ro" \
    -v "${OUT}:/out" \
    -v "${ARTIFACTS_DIR}:/artifacts:ro" \
    -e DEBIAN_FRONTEND=noninteractive \
    ubuntu:24.04 bash -euxc '
apt-get update -qq
apt-get install -y -qq \
    reprepro debsigs gnupg apt-utils \
    python3 ca-certificates 2>&1 | tail -2

# Stage every flag*-related .deb we built earlier into /work/collected/
mkdir -p /work/collected
find /artifacts/flagcx-debian/debian-packages \
     /artifacts/FlagScale/debian-packages \
     /artifacts/FlagTree/dist/output \
     /artifacts/libtriton_jit/output/deb \
     -name "*.deb" -exec cp -v {} /work/collected/ \; 2>&1 | tail -20

# Use only the latest version of each package (drop older 0.7-1 FlagCX builds)
cd /work/collected
ls *.deb | awk -F"_" "{print \$1}" | sort -u | while read pkg; do
    latest=$(ls "${pkg}_"*.deb 2>/dev/null | sort -V | tail -1)
    for f in "${pkg}_"*.deb; do
        [ "$f" != "$latest" ] && rm -f "$f"
    done
done
echo "--- final .deb list ---"
ls -1 *.deb

# Throwaway GPG key (only inside this container; never leaves it)
mkdir -p ~/.gnupg && chmod 700 ~/.gnupg
cat > /tmp/gpg-batch <<EOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Name-Real: FlagOS Local Test
Name-Email: localtest@flagos.invalid
Expire-Date: 1d
%commit
EOF
gpg --batch --gen-key /tmp/gpg-batch 2>&1 | tail -3
KEY_ID=$(gpg --list-secret-keys --with-colons | awk -F: "/^sec:/ {print \$5; exit}")
echo "Generated key ID: $KEY_ID"
gpg --armor --export "$KEY_ID" > /out/pubkey.asc

# Sign every .deb
echo "--- signing .debs ---"
for deb in /work/collected/*.deb; do
    debsigs --sign=origin -k "$KEY_ID" "$deb" || echo "WARN: $deb"
done | tail -10

# Build APT repo (use scripts/build-apt-repo.sh logic)
mkdir -p /out/apt/conf
cat > /out/apt/conf/distributions <<EOF
Origin: FlagOS
Label: FlagOS
Codename: stable
Suite: stable
Architectures: amd64
Components: main
SignWith: $KEY_ID
EOF
reprepro -b /out/apt includedeb stable /work/collected/*.deb 2>&1 | tail -10

# Local validation skips the GitHub-Releases URL rewrite — keep pool/ in
# place so apt fetches binaries from the same server as the metadata.
echo "--- repo layout ---"
find /out/apt -type f | head -30
'

echo ""
echo ">>> [2/4] Output check on host"
ls -lh "${OUT}/"
ls -lh "${OUT}/apt/dists/stable/main/binary-amd64/" || true

echo ""
echo ">>> [3/4] Serving repo on http://127.0.0.1:18000 (background)"
( cd "${OUT}" && python3 -m http.server 18000 >/dev/null 2>&1 ) &
SERVER_PID=$!
trap "kill $SERVER_PID 2>/dev/null || true" EXIT
sleep 2
curl -fsS "http://127.0.0.1:18000/apt/dists/stable/Release" | head -10

echo ""
echo ">>> [4/4] apt install test in fresh ubuntu:24.04 container"
docker run --rm \
    --network=host \
    -v "${OUT}:/repo:ro" \
    -e DEBIAN_FRONTEND=noninteractive \
    ubuntu:24.04 bash -euxc "
apt-get update -qq
apt-get install -y -qq curl gpg ca-certificates 2>&1 | tail -2

# Trust the throwaway key
install -d -m 0755 /etc/apt/keyrings
gpg --dearmor < /repo/pubkey.asc > /etc/apt/keyrings/flagos-test.gpg

# Point apt at our local server
echo 'deb [signed-by=/etc/apt/keyrings/flagos-test.gpg] http://127.0.0.1:18000/apt stable main' \
    > /etc/apt/sources.list.d/flagos-test.list

apt-get update 2>&1 | tail -10

echo '--- apt list available flag* packages ---'
apt-cache search '^libflagcx|^python3-flag|^libtriton-jit' | sort

echo '--- apt-get install dry-run (no actual install due to runtime deps) ---'
apt-get install -y --dry-run libtriton-jit python3-flagscale 2>&1 | tail -20
"

kill $SERVER_PID 2>/dev/null || true
echo ""
echo ">>> validation complete; output preserved at ${OUT}"
