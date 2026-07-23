# openEuler 24.03 LTS — install/run survey (container phase)

First-pass investigation backing the goal: **FlagOS packages
installable and testable on openEuler 24.03 LTS within the month**
(container survey now, physical-hardware functional test to follow).

Date: 2026-07-05. Environment: `openeuler/openeuler:24.03-lts`
container (Python 3.11.6, glibc 2.38, dnf 4.16.2, rpm dist tag
`.oe2403` on official packages).

## TL;DR

Nothing from the current repo installs on openEuler 24.03 as-is —
but every blocker is understood, and the fix path is proven: a
noarch package rebuilt natively inside the openEuler container
(adapted spec, ~15 lines changed) installs and imports cleanly.

## Findings

### F1 — `flagos.repo` baseurl never resolves (`$releasever_short`)

`config/yum-repo.tmpl` uses `$releasever_short`, which no dnf
defines (openEuler's substitutions are only `arch`, `basearch`,
`releasever=24.03LTS`). The URL is fetched literally and 404s:

```
Status code: 404 for .../rpm/$releasever_short/x86_64/repodata/repomd.xml
```

Workaround verified to work:

```sh
echo openeuler2403 > /etc/dnf/vars/releasever_short
dnf makecache -y --repo flagos    # → "Metadata cache created."
```

Fix options: publish per-distro `.repo` files with the baseurl
hardcoded (`flagos-openeuler2403.repo`), or document the
`/etc/dnf/vars` step in `install.md`. Per-distro `.repo` files are
the NVIDIA-style pattern and need no user-side variable.

### F2 — documented `dnf config-manager` command is dnf5-only

`install.md` says `dnf config-manager addrepo --from-repofile=...`.
That is dnf5 syntax (Fedora 41+). openEuler 24.03 has dnf4, and the
base image doesn't even ship `dnf-plugins-core`, so both the dnf5
and dnf4 (`--add-repo`) forms fail out of the box. Simplest
universal instruction:

```sh
curl -fsSL <pages>/flagos.repo -o /etc/yum.repos.d/flagos.repo
```

Also: the first `dnf makecache` must run with `-y` (or the user
must confirm) to import the GPG key; signature itself verifies fine.

### F3 — every noarch python RPM is Fedora-43-built → `python(abi) = 3.14`

The `rpm/openeuler2403/` directory on gh-pages serves the same
`.fc43` binaries as `rpm/fedora43/`. Their auto-generated requires
hard-fail against openEuler's Python 3.11:

```
nothing provides python(abi) = 3.14 needed by python3-flagscale-1.0.0-1.fc43.noarch
```

Same class of problem for the arch packages:

- `libtriton-jit` (`.el9`) additionally requires `libpython3.9.so.1.0`
  — EL9's Python, absent on openEuler.
- `python3-flagtree-nvidia` (`.fc36`) requires `python(abi) = 3.10`
  → needs a **cp311** wheel/build for openEuler 24.03.
- `libflagcx-*` fails only on vendor libs (CUDA/CANN) — glibc-wise
  it would install (needs 2.34, openEuler has 2.38). Vendor-repo
  problem, same as every other distro (`⚠` class).

Conclusion: openEuler needs its **own build dimension** — copying
Fedora metadata into an `openeuler2403/` directory is not enough,
even for noarch packages (site-packages path + python(abi) both
bake in the build container's Python).

### F4 — openEuler 24.03 has no `pyproject-rpm-macros`

The upstream-merged specs (`%pyproject_wheel` / `%pyproject_install`
/ `%pyproject_save_files`) do not build on openEuler: the macro
package doesn't exist there (checked: only `pyproject-api/-hooks/
-metadata` python libs exist). Additionally the `%{python3}` macro
is undefined (use `%{__python3}`), and `%{?dist}` expands empty in
a plain container (official `.oe2403` tags are injected by
EulerMaker/OBS, so CI must pass `--define "dist .oe2403"`).

Per-spec adaptation is mechanical (~15 lines): pip-based
build/install + explicit `%files`. See `flagsparse-oe.spec` next to
this file, proven by:

```
built:    python3-flagsparse-1.0.0-1.noarch.rpm   (on openEuler 24.03)
requires: python(abi) = 3.11
files:    /usr/lib/python3.11/site-packages/flagsparse/...
import:   OK
```

### F5 — dependency availability in openEuler 24.03 main repos

| Dep | openEuler 24.03 | Note |
|-----|-----------------|------|
| python3-numpy | 1.24.3 | flag-gems pins `numpy = 1.26.4` → conflict (see F6) |
| python3-pyyaml | 6.0.1 | ok |
| python3-sqlalchemy | 1.4.48 | flag-gems pins `2.0.48` → conflict |
| python3-filelock | 3.13.1 | ok |
| python3-packaging | 23.2 | flag-gems pins `26` → conflict |
| python3-typer | **absent** | flagscale needs it |
| python3-hydra-core | **absent** | flagscale needs it |
| pytorch / python3-pytorch | **2.1.2 — present!** | named `python3-pytorch`, not `python3-torch` |

`python3-pytorch` being in the official repo is a real advantage
over Fedora/Debian-stable — but our packages' torch dependency is
spelled `python3-torch`, so the requires need a per-distro name (or
a rich `(python3-torch or python3-pytorch)` dependency).

### F6 — exact-version pins in auto-generated requires

`python3-flag-gems` requires `python3.14dist(numpy) = 1.26.4`,
`= 2.0.48` sqlalchemy, `= 26` packaging — exact pins inherited from
a locked requirements file at build time. Even after an openEuler
rebuild these would regenerate as `python3.11dist(...) = <pin>` and
fail against the distro's older versions. The specs need loosened
(`>=`) runtime requires, or `--no-guessing`-style overrides — same
class of fix as the known dh_python3 torch issue on the deb side.

## What "runnable within the month" requires

Ordered; 1–3 unblock `dnf install`, 4–5 make packages usable.

1. **Repo plumbing** (this repo): per-distro `.repo` files (F1) +
   install.md dnf4 instructions (F2). ~half a day.
2. **openEuler build dimension** (upstream repos'
   `build-rpm.yml`): add an `openeuler/openeuler:24.03-lts` build
   container. Blocked on F4 spec adaptation:
   either a conditional in each spec
   (`%if 0%{?openEuler}` pip path) or a shared adapted-spec overlay.
   Start with the merged repos: FlagSparse (proven), FlagAttention,
   FlagTree (cp311).
3. **Sign + publish** rebuilt `.oe2403` RPMs into
   `rpm/openeuler2403/` (replacing the copied Fedora metadata).
4. **Dependency strategy** (F5/F6): map torch → `python3-pytorch`;
   loosen exact pins; decide typer/hydra-core route for flagscale
   (pip-install docs note, or package them too, or EUR).
5. **Hardware functional test** (physical machine, this month's
   exit criterion): after 1–3, on an NVIDIA box with CUDA repo
   configured — install `libflagcx-nvidia`, `python3-flag-gems`,
   `python3-flagtree-nvidia` (cp311) and run the FlagGems op smoke
   tests. Container phase can't cover kernel execution.

## EUR note (step-1.5 toward official inclusion)

The adapted specs from item 2 are exactly what EUR
(openEuler User Repository, COPR-like) consumes — submitting them
there gives official-infra builds + a `dnf`-native user experience,
and pre-validates the specs for an eventual sig-AI /
src-openeuler introduction. Blockers for that longer path, visible
already: upstream repos lack release tags (Source0 must be a real
tarball URL), and typer/hydra-core would need introduction too.

## Update 2026-07-12 — dual-distro template (FlagSparse) verified

The item-2 approach is implemented and proven on FlagSparse, branch
`pr/openeuler-rpm` (spec capability-check + Dockerfile dist shim +
`BASE_IMAGE` env in the build script + fedora43/openeuler2403 CI
matrix; PR body: `../per-repo-pr-bodies/flagsparse-openeuler.md`):

| Target | Artifact | python(abi) | Result |
|--------|----------|-------------|--------|
| fedora43 | `...-1.fc43.noarch.rpm` | 3.14 | regression clean, path unchanged |
| openeuler2403 | `...-1.oe2403.noarch.rpm` | 3.11 | installs + imports on 24.03 container |

F1/F2 are fixed in this repo (per-distro `flagos-<distro>.repo`
generation in `publish-pages.sh` + curl-based install docs). Next:
replicate the template on FlagAttention / FlagTree (cp311), then add
the `.oe2403` routing layer in `build-yum-repo.sh` /
`collect-artifacts.sh` once upstream artifacts exist.

## Update 2026-07-13 — template replicated; new findings F7–F10

FlagAttention: [PR #35](https://github.com/flagos-ai/FlagAttention/pull/35),
both matrix jobs green. FlagTree: packaging recovered + adapted
(see F9), PR pending local dual-build verification.

- **F7 — openEuler rpm expands macros inside spec comments.** A bare
  `%install` in a preamble comment terminates the preamble ("Version
  field must be present" errors). Escape `%` as `%%` in comments.
  Fedora's rpm tolerates it (warning only).
- **F8 — setuptools-scm version gap.** openEuler 24.03 ships 7.1.0;
  projects declaring `setuptools-scm>=8.0` fail metadata generation.
  Upgrading via pip needs `--prefix /usr`: python drops `/usr/local`
  from `sys.path` inside rpmbuild (`RPM_BUILD_ROOT` detection
  inherited from Fedora's site patch), so a default pip install is
  invisible to `%build`.
- **F9 — FlagTree main history was rewritten.** Merged packaging PR
  #607 (merge commit `e56773e1`) is no longer an ancestor of main —
  all packaging files vanished. Recovered from the merge commit and
  re-ported: setup.py/pyproject.toml moved to the repo root, and the
  new `tileir` default backend requires GCC >= 13 (openEuler has
  12.3) + a cuda-tile submodule. Added a `FLAGTREE_DEFAULT_BACKENDS`
  env knob (tools.py) and pinned packaging builds to `nvidia,amd` —
  the historical package contents.
- **F10 — separate dnf RUN layers are catastrophically slow in CI.**
  `dnf clean all` + a second RUN re-downloads all openEuler repo
  metadata; a *failing* one-package install took 43 min on a GitHub
  runner (vs 7.5 min for the whole toolchain layer). Fold
  opportunistic installs into the main dnf layer.

## Update 2026-07-20 — .oe2403 artifact routing implemented

`build-yum-repo.sh` now routes by dist tag: `openeuler<NN>` distro
dirs receive ONLY `.oe<NN>`-tagged rpms; all other dirs keep the
previous full non-`.oe` set. Verified end-to-end in an openEuler
24.03 container with real artifacts (flagsparse + flag-attention +
flagtree, fc43 + oe2403 each): openeuler2403 repodata lists exactly
the six .oe2403 rpms, fedora43/el9 exactly the six .fc43 ones.

Collect side: `components/*.yml` rpm `artifact_pattern` values are
now real regexes (the old `-*-` glob-style strings never matched
`amd64` under `name_is_regexp: true` — latent bug) and admit the
`-oe2403-` artifact variants. `components/flagsparse.yml` added —
it was missing entirely (collected manually during bootstrap).
The deb-side patterns have the same glob-vs-regex latency and still
need the equivalent fix (out of scope here).

Consequence for users: the openEuler repo serves only packages
proven to install on openEuler (currently the FlagSparse set; grows
as upstream openEuler PRs merge) instead of the uninstallable
Fedora-built copies.

## Update 2026-07-23 — live end-to-end PASS

Publish run [29976833365](https://github.com/shiptux/flagos-packaging/actions/runs/29976833365)
(release `v2026.07.23`) with the routing + per-distro `.repo` fixes.
Fresh `openeuler/openeuler:24.03-lts` container, exact documented
user flow:

```sh
curl -fsSL .../flagos-openeuler2403.repo -o /etc/yum.repos.d/flagos.repo
dnf makecache -y
dnf install -y python3-flagsparse python3-flag-attention python3-flagtree-nvidia
```

All three install from GitHub Releases (89 MB) and pass import
checks: `import flagsparse` ✓, `find_spec('flag_attn')` ✓,
`import triton` → 3.6.0 ✓. The repo lists exactly the `.oe2403`
set. flag-attention / flagtree binaries currently come from their
open PRs' CI runs (#35 / #794); they stabilize once merged.

Publish-side regression found and fixed along the way: flagtree
0.6.0's **deb** grew to 240 MB (> gh-pages 100 MB cap) and killed
the first publish; `build-apt-repo.sh` now skips oversized debs
with a CI warning (flagtree temporarily absent from APT; a
Releases-based flat repo is the proper fix, tracked as follow-up).

Remaining for the month goal: hardware (GPU) smoke test — kernels
can't run in containers.

## Update 2026-07-26 — AOT compile smoke PASS (no GPU required)

The deepest verification possible without NVIDIA hardware: in a fresh
openEuler 24.03 container with `python3-flagtree-nvidia` (0.6.0,
cp311) installed from the live repo, `triton.compile` AOT-compiled a
vector-add kernel for `GPUTarget("cuda", 80, 32)` with **no GPU and
no driver present**:

```
stages: ['source', 'ttir', 'ttgir', 'llir', 'ptx', 'cubin']
ptx header: ['.version 8.7', '.target sm_80']
AOT SMOKE PASS
```

Note `cubin` in the stages: the wheel's bundled `ptxas` executed too,
so the full chain — frontend → TTIR → TTGIR → LLVM IR → PTX → cubin —
works on openEuler. Remaining untested surface is only the
driver-interaction layer (allocation, launch), which requires a real
device. Script: `gpu-smoke/aot_smoke.py`.

For that last layer, `gpu-smoke/` contains a self-contained
Dockerfile for locked-down NVIDIA environments (host driver +
nvidia-container-toolkit are the only requirements):

```sh
docker build -t flagos-oe-gpu-smoke docs/verification/openeuler-2403/gpu-smoke/
docker run --rm --gpus all flagos-oe-gpu-smoke
# expected tail: GPU SMOKE PASS <device name>
```

It runs the AOT stage, then a real on-device vector-add (result
checked), then a best-effort `flag_attn.flash_attention` call.

## Repro

```sh
docker run -d --name flagos-oe2403 openeuler/openeuler:24.03-lts sleep infinity
docker exec flagos-oe2403 bash -c '
  curl -fsSL https://shiptux.github.io/flagos-packaging/flagos.repo \
    -o /etc/yum.repos.d/flagos.repo
  echo openeuler2403 > /etc/dnf/vars/releasever_short
  dnf makecache -y --repo flagos
  dnf install -y python3-flagscale   # → python(abi) = 3.14 error (F3)
'
# rebuild PoC: see flagsparse-oe.spec (built with rpmbuild -ba inside
# the same container; tarball via git archive --prefix=flagsparse-1.0.0/)
```
