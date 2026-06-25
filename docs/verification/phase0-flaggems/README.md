# Phase 0 verification — FlagGems C++ build against prebuilt libtriton_jit

Reproducible harness backing the claim:

> FlagGems' C++ operators can be **built against a prebuilt
> libtriton_jit `-dev` package** instead of CMake-FetchContent-ing the
> libtriton_jit source at build time.

## What it proves

In the env matching the upstream `flaggems-nvidia-12.8` container
(**ubuntu22.04 + cuda12.8 + python3.12 + torch2.10+cu128**), two
independent paths:

- **Path A — cmake-install**: `libtriton_jit` built and
  `cmake --install`-ed to `/usr`; FlagGems configured with
  `-DFLAGGEMS_USE_EXTERNAL_TRITON_JIT=ON` resolves it via
  `find_package(TritonJIT CONFIG)` and builds `liboperators.so` +
  `c_operators.*.so`.
- **Path B — real .deb**: `libtriton_jit` built as a `.deb`,
  `dpkg -i`-installed, then FlagGems built against the installed
  package. This is the actual `apt install` path.

Both must pass to reach the final stage, which prints
`VERIFY: ALL PASSED`.

## Scope / caveats

- Verifies **build + link + install + consume**, headless. nvcc
  compiles CUDA without a GPU; this harness needs **no card**.
- Does **not** run kernels (correctness needs a GPU) — that is the
  separate per-backend functional test, unchanged by this work.
- The deb stage forces `TRITON_JIT_USE_EXTERNAL_JSON=OFF` (fetch json)
  because ubuntu 22.04 ships nlohmann-json 3.10.5 < the required
  3.11.3, and caps `DEB_BUILD_OPTIONS=parallel=4` (full-core parallel
  on torch-heavy C++ OOMs ~16–27 GB machines).

## Run

```sh
# upstream defaults (libtriton_jit + FlagGems master)
./run.sh

# point at a specific libtriton_jit branch (e.g. the packaging PR)
LIBTRITON_REF=pr/packaging ./run.sh

# use local checkouts instead of cloning
LIBTRITON_SRC=~/git/github/libtriton_jit LIBTRITON_REF=pr/packaging \
FLAGGEMS_SRC=~/git/github/FlagGems FLAGGEMS_REF=master \
  ./run.sh
```

Success = `VERIFY: ALL PASSED` in the build output.

## Recorded result

- **Path A (cmake-install): PASSED 2026-06-15.**
- **Path B (.deb): harness added 2026-06-25.** The deb build previously
  OOM-ed at full-core parallelism; that is fixed here with
  `parallel=4`. Confirm a green run with `./run.sh` before citing it as
  passed.

The narrative conclusion + findings live in
[`../../plan-tracking.md`](../../plan-tracking.md) under
"FlagGems C++ operator extension — split design → Verification status".

Related finding (RPM, *not* covered here): the libtriton_jit RPM
`%build` links operator **test** exes against `libtorch_cuda` needing
cuDNN/cuSPARSELt absent in the rocky9 image — a pre-existing RPM-image
issue, tracked separately. The deb path here passes because pip torch
brings cuDNN into the build env.
