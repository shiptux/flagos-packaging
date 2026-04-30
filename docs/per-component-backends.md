# Per-Component Backend Matrix

How FlagTree and FlagGems each handle multi-backend support, and what
that means for our packaging matrix.

The two components look superficially similar (both AI accelerator
libraries supporting many vendors) but they package very differently
because their backend selection happens at different times.

## TL;DR

| Component | Backends | Selection time | Wheels needed | DEB/RPM packages |
|-----------|----------|------------------|----------------|---------------------|
| FlagTree | 12 | **Build time** (`FLAGTREE_BACKEND=...`) | One per backend × Triton version | One per backend × distro Python ABI |
| FlagGems | 14 | **Run time** (`GEMS_VENDOR=...`) | One total | One total |

FlagTree fans out into ~13 independent wheel builds. FlagGems compresses
all 14 backends into a single wheel that picks the right code path at
import time.

## FlagTree — backend matrix

Each backend is built against a *different* Triton version, which
pulls a *different* upstream LLVM tarball. The bundled artifacts make
each wheel independent.

| Backend | Triton | LLVM hash | Arch | PyPI version tag | Vendor SDK source |
|---------|--------|------------|------|---------------------|------------------------|
| nvidia / amd (default) | 3.6 | `f6ded0be` | x64 | `0.5.0` (no suffix) | NVIDIA repo / AMD repo |
| ascend | 3.2 | `86b69c31` | **aarch64** | `0.5.0+ascend3.2` | Huawei CANN |
| mthreads | 3.1 | `10dc3a8e` | x64 + aarch64 | `0.5.1+mthreads3.1` | Moore Threads MUSA |
| metax | 3.0 | (vendor) | x64 | `0.5.1+metax3.0` | MetaX `maca_sdk` |
| iluvatar | 3.1 | `10dc3a8e` | x64 | `0.5.1+iluvatar3.1` | Iluvatar SDK |
| hcu (Hygon) | 3.0 | (vendor) | x64 | `0.5.0+hcu3.0` | Hygon DTK |
| aipu | 3.3 | `a66376b0` | x64 + aarch64 | `0.5.0+aipu3.3` | AIPU SDK |
| sunrise (Horizon) | 3.4 | `8957e64a` | x64 | `0.5.0+sunrise` | — |
| tsingmicro | 3.3 | `a66376b0` | x64 | `0.5.0+tsingmicro3.3` | — |
| enflame | 3.5 | `7d5de303` | x64 | `0.5.0+enflame3.5` | TopsRider |
| xpu (Kunlunxin) | TBD | TBD | x64 | `0.5.1+xpu3.0` (TODO) | XPU SDK |

**Compilation count per release**

Realistic minimum for *one* release tag:

- nvidia / amd share Triton 3.6 → 1 wheel covers both x64
- ascend → 1 wheel (aarch64-only)
- mthreads → 2 wheels (x64, aarch64)
- iluvatar → 1 wheel (x64)
- metax → 1 wheel (x64)
- hcu → 1 wheel (x64)
- aipu → 2 wheels (x64, aarch64)
- sunrise → 1 wheel (x64)
- tsingmicro → 1 wheel (x64)
- enflame → 1 wheel (x64)
- xpu → 1 wheel (x64) when wired up

**Total: ~13 wheel builds per release.**

If we also need to cover multiple Python ABIs (cp310 for Ubuntu 22.04 /
OpenEuler 24.03 / fedora:36; cp312 for Ubuntu 24.04 / fedora:41+; etc.),
multiply by N. A 13 × 3 ABI matrix is **39 wheel builds per release**.

Each wheel build is roughly 36 minutes wall-time on a 4-core builder
with the LLVM tarball already in cache.

| Strategy | Total wall time |
|----------|------------------|
| Sequential single builder | 13 × 36 min = ~8 hours |
| Sequential with 3 ABIs | 39 × 36 min = ~24 hours |
| Parallel (GitHub Actions matrix, 13 jobs) | ~36 min |
| Parallel with 3 ABIs (39 jobs) | ~36 min |

GitHub Actions free tier for public repos has no minute cap, but
storage and rate limits may bite at the 39-build scale. Each .deb is
~84 MB, .rpm ~87 MB → 39 × ~170 MB ≈ 6.5 GB per release across the
matrix. Within Releases asset capacity but not negligible.

**Realistic phased rollout for FlagTree**

Don't aim for the full 13-backend matrix on the first publish. Stage:

1. **W2** (nvidia + amd default, x64) — 1 build, the wins we already validated
2. **W3** (mthreads x64) — needs MUSA toolkit on H20
3. **W4–W6** (metax, ascend aarch64, iluvatar) — each needs vendor docker image
4. **Later** (hcu, aipu, sunrise, tsingmicro, enflame, xpu) — as vendor configs become reachable

Most non-default backends require a vendor-private docker image
(MUSA, CANN, MetaX, Iluvatar) that isn't on the public registries. Each
backend onboarding is a vendor-coordination task, not just a build job.

## FlagGems — backend matrix

FlagGems takes the opposite approach: **one wheel for all 14 backends**.

```python
# src/flag_gems/runtime/backend/device.py
device_from_env = os.environ.get("GEMS_VENDOR")
```

The Python tree under `src/flag_gems/runtime/backend/` ships every
vendor's specialized code (`_aipu/ _amd/ _arm/ _ascend/ _cambricon/
_enflame/ _hygon/ _iluvatar/ _kunlunxin/ _metax/ _mthreads/ _nvidia/
_sunrise/ _tsingmicro/`); the runtime picks one path based on
`GEMS_VENDOR` (or auto-detection from the installed PyTorch).

C++ extension (`liboperators.so`) is also single — same library handles
all backends. Only the Python wrappers fan out.

**Real dependency: a matching FlagTree backend at runtime**

FlagGems imports `triton`, which our `python3-flagtree-<backend>`
package provides. The right wheel must be installed for the chosen
vendor. Express this in `debian/control`:

```
Package: python3-flag-gems
Recommends: python3-flagtree-nvidia |
            python3-flagtree-amd |
            python3-flagtree-mthreads |
            python3-flagtree-metax |
            python3-flagtree-ascend
```

Or more strictly, `Depends:` if any of those is required for any
import to succeed (most likely yes — `import triton` is in the import
chain). The `|` is apt/dnf's "any one of these" alternative syntax.

**Compilation count per release: 1.**

Single wheel, single .deb, single .rpm, regardless of how many backends
the user might run.

But: the build container *itself* needs a working PyTorch + Triton +
some vendor SDK to compile the C++ extension. We can pick any one
(say, nvidia + system CUDA), build once, and ship.

## Why the asymmetry exists

It's a deliberate upstream design choice:

- **FlagTree is a compiler.** Different vendors require fundamentally
  different LLVM target backends, codegen passes, and runtime
  libraries — these can't share a binary. Build-time selection is
  unavoidable.

- **FlagGems is an operator library.** It writes Triton kernels at
  the kernel-language level; the compiler handles vendor specifics.
  The vendor differentiation is a runtime dispatch decision (which
  kernel implementation to register with PyTorch's ATen).

So FlagGems benefits from the work FlagTree already did: by compiling
once against any one Triton/FlagTree, FlagGems' kernels run on every
backend FlagTree supports.

## Implications for `flagos-packaging`

1. **FlagTree dominates the publish matrix.** ~13 wheel builds per
   release tag. Worth caching aggressively (LLVM tarballs, NVIDIA
   tarballs, ccache) and doing fan-out via GitHub Actions matrix.
2. **FlagGems is cheap to ship.** Treat it as a normal Python
   noarch-ish package (architecture is amd64 only because of the C++
   extension, but no fan-out).
3. **Cross-component declaration matters.** `python3-flag-gems`
   needs to express its dependency on *some* FlagTree backend without
   forcing a specific one. The `|` alternative syntax works for both
   apt and dnf.
4. **Architecture variants concentrated in FlagTree.** ascend is
   aarch64-only; aipu and mthreads need both. The publish.yml matrix
   needs `arch: [amd64, arm64]` as a dimension for these.
5. **Python ABI matrix is real.** A cp310 wheel won't install on a
   Python 3.14 host. We pick one or two ABIs per release; full
   coverage is a future expansion.

## Cumulative package count (revised)

The original "40 packages" estimate assumed roughly 16 components × 2
formats × 1.25 average backend variants. With FlagTree's 13-backend
fanout the realistic count is closer to:

| Component | Backend variants | Formats | Total |
|-----------|--------------------|---------|-------|
| FlagCX | 3 (nvidia/metax/ascend) × {lib, -dev} | DEB+RPM | 12 |
| FlagScale | 1 noarch | DEB+RPM | 2 |
| FlagTree | 13 (full backend matrix) | DEB+RPM | 26 |
| FlagGems | 1 (Phase 1) → 3 (Phase 2 split) | DEB+RPM | 6 |
| libtriton-jit | 1 + dev | DEB+RPM | 4 |
| FlagAttention | 1 | DEB+RPM | 2 |
| FlagDNN, FlagTensor, FlagBLAS, FlagSparse, FlagAudio | 1 each | DEB+RPM | 10 |

**Realistic full-matrix total: ~62 packages.**

The "40" target is achievable for the *common* subset (nvidia + a
couple of vendor backends + all Python components). Full coverage
including every FlagTree backend approaches 60–70.
