# Public end-to-end verification — 2026-05-20

First successful public install from `shiptux.github.io/flagos-packaging`
on a clean Ubuntu 24.04 container.

## What the verification proves

The sandbox's primary design goal — "an arbitrary user on a clean
distro can `apt install` FlagOS packages from a public URL signed
with our key" — works end-to-end. Sign / metadata / Pages / install
chain is closed.

## Reproduction

```sh
docker run --rm -it -e DEBIAN_FRONTEND=noninteractive ubuntu:24.04 bash

# inside the container:
apt-get update -qq
apt-get install -y -qq curl gpg ca-certificates python3

install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://shiptux.github.io/flagos-packaging/pubkey.gpg | \
    gpg --dearmor -o /etc/apt/keyrings/flagos.gpg

echo "deb [signed-by=/etc/apt/keyrings/flagos.gpg] \
    https://shiptux.github.io/flagos-packaging/apt stable main" \
    > /etc/apt/sources.list.d/flagos.list

apt-get update
apt install -y libtriton-jit python3-flagsparse python3-flag-attention
```

## Verified install (clean ubuntu:24.04)

```
libtriton-jit 0.1.0-1                       ✓ installed
python3-flag-attention 0.3.0-1              ✓ installed
python3-flagsparse 1.0.0-1                  ✓ installed
python3-triton 2.0.0.post1-3ubuntu1         ✓ auto-pulled via Recommends
```

Module load (via `importlib.util.find_spec` — doesn't trigger
runtime-deps like torch / triton-jit-runtime):

```
flagsparse  → /usr/lib/python3/dist-packages/flagsparse/__init__.py
flag_attn   → /usr/lib/python3/dist-packages/flag_attn/__init__.py
```

## Path traveled to get here

The publish pipeline broke on 5 things in succession before the
first clean run. Documenting them so future maintainers don't
repeat:

1. **`// empty` vs `// ""`** in `collect-artifacts.sh` — `mikefarah/yq` doesn't
   accept `empty` as a token. Matrix expansion returned blank,
   download fan-out was skipped, publish ended green-with-nothing.
2. **`fail-fast` matrix** on the download step — one upstream with
   404 workflow cancelled all sibling shards. Added
   `fail-fast: false` and `continue-on-error: true`.
3. **GPG pinentry** in non-TTY CI — `gpg-agent` wouldn't sign for
   debsigs/rpmsign. Fixed by pre-configuring
   `~/.gnupg/gpg-agent.conf` with `allow-loopback-pinentry` AND
   `pinentry-mode loopback` BEFORE the first gpg call spawns the
   agent.
4. **CI key with passphrase** — original `gpg --quick-generate-key`
   prompted for a passphrase, which then needed `GPG_PASSPHRASE`
   secret. Rotated to a passphrase-less sandbox CI key (sandbox
   trust model: key is single-purpose, no value in adding a layer
   that's in the same Secret store anyway). Documented separately
   under "GPG for CI".
5. **Filename: absolute URL** — original design ran a sed rewrite
   converting `Filename: pool/...` to
   `Filename: https://github.com/.../releases/download/...`. APT
   does NOT follow absolute URLs in Filename — it prepends the
   source URL, ending up with broken
   `.../apt/https://github.com/...` 404s. Reverted to standard
   relative pool paths; pool/ ships on Pages alongside dists/. The
   "metadata on Pages, binaries on Releases" architecture (still
   recorded in ADR-001) doesn't actually work for APT and needs to
   be revisited or removed from that ADR.
6. **`.gitignore` filtering pool/ from gh-pages push** — the
   gh-pages worktree inherits .gitignore from main, which excludes
   `*.deb` and `*.rpm`. `git add -A` silently skipped the entire
   pool/ tree. Result: apt-cache search showed all 18 packages but
   apt install 404'd on every fetch because the actual binaries
   weren't on Pages. Fixed with `git add -Af`.
7. **publish-pages.sh `[ -f $key ] && cp`** — file existence test
   was failing in CI for unclear reasons, silently skipping the
   pubkey copy. Replaced with unconditional cp so it fails loudly.

Most of these were our own scripts. The public-facing flow turned
out fine on first apt-update once the pipeline was clean.

## Distros / packages installed in this verification

```
Distro: Ubuntu 24.04 (Noble), default Python 3.12
Packages: 3 of 18 (selected for deps-clean on Ubuntu noble main archive)
```

The other 15 packages either need vendor SDK (libcuda for
libtriton-jit; CUDA/MetaX/Ascend for libflagcx-*) or are
ABI-incompatible (cp310-only `python3-flagtree-nvidia`). Those
limitations are captured in `docs/compatibility-status.md`.

## What this verification does NOT prove

- Runtime correctness of the packaged code on a GPU (we have no
  GPU in this validation environment)
- Multi-distro coverage (only Ubuntu 24.04 tested; trixie / fedora
  not on the public side yet)
- Fault-tolerance under partial CI failure (one upstream missing
  artifacts when publish runs)

Those belong to future verification rounds.

## Status of the sandbox

```
Goal                                                State
─────────────────────────────────────────────────────────────
Public URL hosts signed apt repo                   ✓
Pubkey reachable via the same URL                  ✓
A clean container can apt update without warnings  ✓
A clean container can apt install                  ✓
Modules find_spec correctly                        ✓
Cross-distro install (trixie, fedora)              partial — pending
Vendor-dep packages (libtriton-jit + CUDA)         partial — needs cuda repo
FlagTree-nvidia on non-cp310                      blocked on multi-ABI build
```

The "sandbox proves the design" milestone is hit. Further work is
scope expansion, not unblocking.
