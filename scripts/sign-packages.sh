#!/usr/bin/env bash
# Sign all .deb and .rpm files under ./collected/ using the GPG key
# already imported into the current keyring.
#
# Invoked by publish.yml after collect-artifacts. Operator must have
# imported the private key (in CI: from the GPG_PRIVATE_KEY secret;
# locally: gpg --import < your-key.asc).
#
# Env:
#   GPG_KEY_ID     fingerprint or short ID of the signing key
#   GPG_PASSPHRASE optional, only needed for non-interactive signing
#   COLLECTED_DIR  default: ../collected

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COLLECTED_DIR="${COLLECTED_DIR:-${REPO_ROOT}/collected}"

if [ -z "${GPG_KEY_ID:-}" ]; then
    echo "ERROR: GPG_KEY_ID must be set (fingerprint or short ID)" >&2
    exit 1
fi

# Sanity-check the key is in the keyring
if ! gpg --list-secret-keys "${GPG_KEY_ID}" >/dev/null 2>&1; then
    echo "ERROR: secret key ${GPG_KEY_ID} not in keyring" >&2
    exit 1
fi

# Configure rpm to use our key for signing without prompting
mkdir -p "${HOME}"
cat > "${HOME}/.rpmmacros" <<EOF
%_signature gpg
%_gpg_name ${GPG_KEY_ID}
%__gpg_sign_cmd %{__gpg} \\
    gpg --no-verbose --no-armor --batch --pinentry-mode loopback \\
        ${GPG_PASSPHRASE:+--passphrase-fd 0} \\
        --no-secmem-warning \\
        -u "%{_gpg_name}" -sbo %{__signature_filename} \\
        --digest-algo sha256 %{__plaintext_filename}
EOF

deb_count=0
rpm_count=0

# Sign .debs with debsigs (requires debsigs-policies on the install side
# to be honored, but the signature is also pulled by the apt-secure flow
# via the Release.gpg / InRelease that build-apt-repo.sh produces).
while IFS= read -r -d '' deb; do
    if debsigs --sign=origin -k "${GPG_KEY_ID}" "${deb}"; then
        deb_count=$((deb_count + 1))
    else
        echo "WARN: failed to sign ${deb}" >&2
    fi
done < <(find "${COLLECTED_DIR}" -name '*.deb' -print0)

# Sign .rpms with rpmsign
while IFS= read -r -d '' rpm; do
    if [ -n "${GPG_PASSPHRASE:-}" ]; then
        echo "${GPG_PASSPHRASE}" | rpm --addsign "${rpm}" >/dev/null
    else
        rpm --addsign "${rpm}" >/dev/null
    fi
    rpm_count=$((rpm_count + 1))
done < <(find "${COLLECTED_DIR}" -name '*.rpm' -print0)

echo "signed ${deb_count} .deb files and ${rpm_count} .rpm files"
