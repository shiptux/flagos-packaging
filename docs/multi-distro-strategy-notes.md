# Multi-distro packaging — how the ecosystem handles it

Background notes captured during sandbox design discussion. Reference,
not policy: documents what others do so we can choose informed when
we eventually need to scale beyond the current single-distro target.

## The problem

Python packages with C extensions (e.g. `triton/_C/libtriton.so`,
`flag_gems` operators) are tied to a specific Python ABI at build
time. A wheel built against Python 3.10 cannot be installed on
Python 3.11+, regardless of how the rest of the distro looks.

Multiply by N distro versions × M Python ABIs × K vendor backends
and the build matrix grows fast. The ecosystem has settled on four
patterns; none of them is "one wheel for all distros".

## Four patterns the ecosystem uses

### 1. manylinux wheels on PyPI

The dominant pattern for ML / scientific libraries. Upstream's CI
builds a wheel per Python ABI per architecture, targeting the
`manylinux_*_*` standard that constrains glibc version and required
system libraries. `pip install` picks the right one at install time.

```
upstream CI produces:
  numpy-1.26.0-cp310-cp310-manylinux_2_17_x86_64.whl
  numpy-1.26.0-cp311-cp311-manylinux_2_17_x86_64.whl
  numpy-1.26.0-cp312-cp312-manylinux_2_17_x86_64.whl
  numpy-1.26.0-cp313-cp313-manylinux_2_17_x86_64.whl
```

Examples: `numpy`, `torch`, `tensorflow`, `cryptography`, `lxml`,
`nvidia-cuda-runtime-cu12`.

Solves Python ABI; sidesteps distro packaging entirely. Doesn't help
`apt install` / `dnf install` flows.

### 2. Each distro repacks from source

How `python3-numpy` ends up in Debian's main archive and `python3-numpy`
ends up in Fedora's. Each distro's maintainer team rebuilds the source
against their distro's Python, libc, BLAS, …

```
Debian maintainer:  sbuild numpy on Debian/Bookworm container
                    → python3-numpy_1.24.2-1_amd64.deb (against py3.11)
Fedora maintainer:  mock build numpy on Fedora-43 container
                    → python3-numpy-2.1.3-1.fc43.x86_64.rpm (against py3.14)
```

Outcome: same upstream, N distro-specific binaries, maintained
distro-side not upstream-side.

Manpower: distro Python teams, volunteers. Not the project's CI.

### 3. Vendor-maintained multi-distro repos

What PostgreSQL, NodeSource, Docker CE, MongoDB, NVIDIA CUDA all do.
The project itself maintains a packaging repository with per-distro
subdirs and per-distro builds.

```
apt.postgresql.org/pub/repos/apt/dists/
  bookworm-pgdg/    ← Debian 12 (py3.11)
  trixie-pgdg/      ← Debian 13 (py3.13)
  jammy-pgdg/       ← Ubuntu 22.04 (py3.10)
  noble-pgdg/       ← Ubuntu 24.04 (py3.12)
  …

developer.download.nvidia.com/compute/cuda/repos/
  ubuntu2204/x86_64/    ubuntu2404/x86_64/
  debian12/x86_64/      debian13/x86_64/
  rhel8/x86_64/         rhel9/x86_64/
  fedora41/x86_64/      fedora43/x86_64/
  …
```

Each subdir gets its own build, tagged with the distro codename.
Users add the vendor repo file matching their distro; `apt install` /
`dnf install` works natively from there.

Manpower: project's own packaging team. Build matrix is project's
problem, not distro maintainers'.

### 4. noarch + bundled .so (rare)

Some projects (Conda's own packages, some commercial vendors) ship
self-contained tarballs that don't trust the distro Python.
Effectively their own runtime. Conflicts with distro packaging
policies; rare for apt/dnf.

## Matrix sizing comparison

```
PostgreSQL          1 project × ~8 distros × ~4 codenames each = ~32 build slots
NVIDIA CUDA         1 project × ~10 distros × ~3 codenames × 2 archs = ~60 build slots
FlagOS hypothetical 12 components × 3-4 distros × 2-3 Python ABIs × 5-13 backends = 360+ slots
FlagOS sandbox now  12 components × 1 distro × 1 Python ABI × 1 backend = 12 slots
```

The full FlagOS matrix is industrial-scale. PostgreSQL/NVIDIA-scale
team and CI. Sandbox stays at 12 slots intentionally.

## Implications for FlagOS

If/when FlagOS goes from sandbox to actual vendor distribution, the
realistic shape is Tier-1 / Tier-2:

```
Tier-1 (vendor-officially-supported, full coverage):
  Ubuntu 22.04 LTS + 24.04 LTS
  OpenEuler 24.03 LTS
  Fedora latest stable (rolling)

Tier-2 (best-effort, source-only, community packaging):
  Debian latest stable
  RHEL/Rocky/Alma latest

Out of scope:
  arch / nixos / gentoo / openSUSE Tumbleweed
  any distro the vendors don't officially support
```

That's the NVIDIA / Docker model. Pick a small Tier-1, declare the
rest unsupported but not blocked.

## "Single-chain sandbox" is not a policy

The current state — only Ubuntu 22.04 cp310 — is a build-matrix
shortcut, not a design decision. Expanding to cp312 (Ubuntu 24.04)
or cp313 (Debian trixie) means adding a build job, no source
changes. Adding cp314 (Fedora 43) on the RPM side is the same shape.

When this expansion happens depends on:

- Whether there's a real user on a non-cp310 distro asking
- How much CI / runner budget is available
- Whether the vendor (FlagOS team) commits to a Tier-1 distro set

None of those are technical packaging questions; they're product /
ops decisions. This document is the technical-reference background
those decisions can lean on.

## Concrete answer to the recurring question

> "Can one set of packages work on all major distros?"

Not for the C-extension parts. Either:

- Build one wheel per Python ABI (manylinux PyPI route), or
- Build one .deb / .rpm per distro codename (vendor repo route).

Both are real and well-trodden. Neither has a free-lunch shortcut.

For the noarch Python parts (FlagAttention, FlagDNN/BLAS/Sparse/
Tensor/Audio/Quantum, FlagScale, FlagGems Phase 1) and the pure-C++
parts (FlagCX, libtriton-jit): one build serves all distros within
the same family (Debian-family / RHEL-family). These have no ABI
lock.

Only `python3-flagtree-nvidia` (and other FlagTree backends once
packaged) is genuinely Python-ABI-locked. That's the one component
that benefits from a multi-Python build matrix.
