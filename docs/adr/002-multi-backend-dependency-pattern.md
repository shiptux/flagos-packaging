# ADR-002: How upstream consumers depend on the FlagTree backend

## Status

Draft — Plan 1 captured. Plans 2 and 3 TBD before a decision.

## Context

FlagOS's Python operator libraries (FlagGems, FlagAttention, FlagDNN,
FlagBLAS, FlagSparse, FlagTensor, FlagAudio) all call `import triton`
at runtime. The `triton` module on a host is provided by exactly one
FlagTree backend package. There are currently up to **13 candidate
FlagTree backend packages** (nvidia, amd, mthreads, metax, ascend,
iluvatar, hcu, aipu, sunrise, tsingmicro, enflame, xpu, cambricon).

How should an upstream consumer like `python3-flag-attention` declare
its dependency on "some FlagTree backend"?

### Why this is non-trivial

A naive answer is a long alternative list:

```
Depends: python3-flagtree-nvidia | python3-flagtree-mthreads |
         python3-flagtree-metax | python3-flagtree-ascend | ...
```

That has three problems:

- **Brittle on growth.** Every time a new FlagTree backend appears,
  *every consumer's control file* must add it to the list. 7
  consumers × 1 line per new backend = drift surface.
- **Order matters.** apt's resolver biases toward the first
  satisfiable alternative. Order choice silently picks defaults.
- **Reads badly.** `Depends: A | B | C | D | E | F | ...` clutters
  the package metadata and makes the actual semantic ("any flagtree
  backend") opaque.

### The host-side reality

On any single host:

- `/usr/lib/python3/dist-packages/triton/` exists exactly once. Python's
  `sys.path` resolution + module namespace doesn't permit two `triton/`
  trees co-installed.
- Each of the 13 backend packages installs into that exact path with
  different content (different Triton version, different LLVM build,
  different vendor backend module).
- Therefore: at most one `python3-flagtree-<backend>` can be installed
  at a time.

The 13 FlagTree backend packages already declare each other in
`Conflicts:` to enforce this at dpkg level.

### What other Debian ecosystems do

`libblas.so.3` is the canonical example. Multiple real packages
(`libblas3` reference, `libopenblas0-pthread`, `libatlas3-base`,
`libmkl-rt`, …) each `Provides: libblas.so.3-libc-dev`. Downstream
consumers like `liblapack3` write `Depends: libblas.so.3-libc-dev`
and apt picks any one provider. `update-alternatives` then manages
which `.so` file `/usr/lib/x86_64-linux-gnu/libblas.so.3` symlinks
to at runtime; multiple implementations are co-installable.

The four parts of the libblas3 pattern, separately:

| # | Mechanism | dpkg/system feature |
|---|-----------|----------------------|
| ① | Virtual package name (no real package owns it) | Naming convention |
| ② | Many real packages declare `Provides:` the virtual | `Provides:` field |
| ③ | At most one is *active* at runtime via symlinks | `update-alternatives` |
| ④ | Consumers `Depends:` on the virtual | `Depends:` resolves virtuals |

## Plan 1 — Adopt ①②④, accept Conflicts in place of ③

**Concept.** Use the libblas3 idiom for the dependency graph (①②④).
Don't try to make multiple backends co-installable (③); rely on the
existing `Conflicts:` between backend packages to enforce singularity.

### Concrete changes

```diff
--- FlagTree packaging/debian/control
 Package: python3-flagtree-nvidia
+Provides: python3-flagtree-backend
 Conflicts: python3-flagtree-mthreads, python3-flagtree-metax, ...
```

Same one-line addition in `packaging/rpm/specs/flagtree.spec`:

```diff
 Provides: python3-flagtree
+Provides: python3-flagtree-backend
 Conflicts: python3-flagtree-mthreads, ...
```

Repeat on every backend variant (one line each, when each backend
gets its own packaging round).

**Consumer side** — 7 components that actually `import triton` (each
verified by source grep, ranging from 14 imports for FlagAttention up
to 2,478 for FlagGems):

```diff
--- packaging/debian/control of every consumer
 Package: python3-flag-attention
-Recommends: python3-flagtree-nvidia | python3-triton
+Depends: python3-flagtree-backend
```

That single line replaces the open-ended alternative list and remains
valid no matter how many FlagTree backends emerge.

**Components NOT changed** — FlagQuantum, FlagScale. Source grep shows
0 `import triton` lines. They have their own runtime deps (torch,
numpy) but don't go through Triton.

### Install-time resolution walk-through

```
apt install python3-flag-attention python3-flag-gems

  Depends on:
    python3-flag-attention  →  python3-flagtree-backend (virtual)
    python3-flag-gems       →  python3-flagtree-backend (virtual)

  Who provides python3-flagtree-backend?
    13 candidates (python3-flagtree-{nvidia,mthreads,metax,...})

  apt picks one (default by priority / first-in-archive / interactive)
    → installs e.g. python3-flagtree-nvidia
    → /usr/lib/python3/dist-packages/triton/ now exists

  Installs consumer packages:
    → /usr/lib/python3/dist-packages/flag_attn/
    → /usr/lib/python3/dist-packages/flag_gems/
    → both import triton, both resolve to the same /usr/lib/.../triton/
```

### Switching backend at any later time

```
apt remove python3-flagtree-nvidia
apt install python3-flagtree-mthreads

  Consumer packages stay in place.
  Their import triton now resolves to mthreads-built triton/.
  No reinstall of flag_attn / flag_gems / etc. needed.
```

This is the closest we get to `update-alternatives` semantics: same
sys.path, content swapped. Not as smooth as alternatives' runtime
symlink flip, but functionally equivalent for users.

### What Plan 1 DOES give us

- Consumer-side dependency line stays at one entry regardless of
  backend count (the libblas3 win)
- Adding a new backend is purely additive: new package gets
  `Provides: python3-flagtree-backend`, no consumer touched
- Standard Debian idiom, no novel mechanism, no surprises for
  experienced Debian maintainers
- apt / dnf both honor `Provides:` correctly
- Zero implementation cost: it's just adding 1 line per backend
  package + rewriting 7 consumer `Depends:` lines
- Works *today* without any upstream FlagTree code change

### What Plan 1 does NOT give us

- **Co-installable backends.** Only one FlagTree backend is on the
  host at any time. Switching is `apt remove + apt install`, not a
  one-command alternatives switch.
- **Runtime backend selection.** The active backend is decided at
  package-install time, not at Python-process-start time. A user
  wanting to A/B two backends needs two hosts (or two containers).
- **Co-existence with upstream `python3-triton`.** The
  `Conflicts: python3-triton` already on each backend package
  enforces "FlagTree backend OR upstream triton, not both". This
  carries over unchanged.
- **Help with the wheel-build matrix.** Plan 1 is purely a
  packaging-metadata change. The cost of building 13 separate wheels
  for FlagTree's 13 backends is unaffected. Plan 2 or 3 might
  address build-side reduction.

### Implementation effort estimate

| Change | Files | Lines |
|--------|-------|-------|
| FlagTree control: add `Provides:` | 1 | 1 |
| FlagTree spec: add `Provides:` | 1 | 1 |
| 7 consumers (DEB control + RPM spec): switch to `Depends: python3-flagtree-backend` | 14 | ~14 |
| Local rebuild + verify | — | each ~5–30 s |
| **Total** | **16** | **~16** |

Effectively a one-sitting change for the nvidia-only single-chain
scope (FlagTree has 1 backend packaged today). The other 12
FlagTree backends inherit the pattern when they get their own
packaging.

## Plan 2 — TBD

(Reserved for an alternative approach to discuss next.)

## Plan 3 — TBD

(Reserved for a further alternative.)

## Decision

Not made yet. Plan 1 is captured here so we can compare it against
Plan 2 / Plan 3 once those are written, then choose.

## Why we're writing this down before implementing

The pattern question recurs every time a new consumer package gets
scaffolded ("how do I depend on FlagTree?"). Writing all candidate
plans down once means future review can compare them side-by-side
instead of re-deriving the trade-offs each time.

Also: Plan 1 looks cheap and obviously-right at first glance, but
the `update-alternatives` gap (③) hides a real semantic difference
from libblas3 — multiple backends are *not* co-installable for us.
A reader who knows the BLAS analogy might over-claim feature parity.
This ADR makes the boundary explicit so reviewers don't get fooled.
