# Single-Chain Policy (W2 / current scope)

## What "single chain" means

```
arch:    x86_64
OS-DEB:  Ubuntu 22.04
OS-RPM:  fedora:36
backend: nvidia (default)
Python:  cp310
```

This is the *only* combination the publish pipeline targets right now.

## Why the convergence

The full matrix (FlagTree's 12 backends × 2 architectures × N Python
ABIs × 2 formats) approaches **60+ packages per release** — not a
shape we can responsibly ship without team alignment on:

- which backends are in scope for the official `flagos-packaging`
  repo vs. which are vendor-coordinated
- whether upstream FlagTree should evolve toward runtime-selected
  backends (FlagGems-style) so the matrix collapses
- which architecture (x86_64 vs. aarch64) and which Python ABIs are
  must-haves vs. nice-to-haves
- vendor configuration: who owns mthreads/metax/ascend/iluvatar/etc.
  in the publish chain

Until those decisions land we keep the matrix small and prove the
pipeline shape end-to-end on one combination.

See `docs/per-component-backends.md` for the full matrix details and
`docs/plan-tracking.md` for ongoing status.

## What's IN scope for W2

| Component | Variant | Format | Status |
|-----------|---------|--------|--------|
| FlagCX | nvidia | DEB + RPM | Have DEB, RPM source on `pr/rpm-packaging` branch |
| libtriton-jit | (single) | DEB + RPM | Built |
| python3-flagscale | (noarch) | DEB + RPM | DEB built; RPM stale, needs rebuild |
| python3-flagtree-nvidia | nvidia | DEB + RPM | **Built end-to-end (validated 2026-04-26/27)** |
| python3-flag-gems | Phase 1 (bundled) | DEB + RPM | **Building (W2 in progress)** |

## What's OUT of scope for W2

- FlagCX metax / ascend backends
- FlagTree non-default backends (mthreads, metax, ascend, iluvatar,
  hcu, aipu, sunrise, tsingmicro, enflame, xpu)
- aarch64 architecture (ascend mandates this; deferred)
- Python ABI fan-out (cp312 / cp313 / cp314)
- FlagGems Phase 2 (C++ split into libflaggems + libflaggems-dev)
- FlagAttention, FlagDNN, FlagTensor, FlagBLAS, FlagSparse, FlagAudio
  (other 6 Python components — defer to W3+)

## When to expand

The single-chain policy lifts when **any one** of these is true:

1. **Team decision on coverage scope** lands — we know exactly which
   backends and architectures are in vs. out.
2. **Vendor coordination** for non-default backends starts —
   mthreads/metax/etc. each need their own build container with
   vendor SDK; getting one of those wired up is its own milestone.
3. **Upstream FlagTree** introduces runtime-selectable backends so
   one wheel covers many backends (FlagGems-style). This collapses
   the matrix and the constraint disappears.

## Pre-conditions for this convergence to work

The `components/*.yml` `artifact_pattern` fields are pinned to
`-nvidia-` patterns. The dawidd6/action-download-artifact step in
`publish.yml` only matches what each upstream's `build-deb.yml` /
`build-rpm.yml` actually produces under that name. Upstream
component CIs may produce more (e.g. FlagCX builds all three
backends in one workflow), but our matrix downloads only what we ask
for, so additional backends produced upstream don't accidentally
land in our published feed.
