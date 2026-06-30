# Handling plan drift

This project ships in weekly increments. Drift between plan and reality
is normal — the question is how to respond when it happens. This note
records the working model.

## Three principles

### 1. Decompose milestones into shippable increments

A milestone like "users can `apt install` everything" is too coarse —
if any one component falls behind, the whole milestone slips. Break
it down so each increment is independently shippable:

- W1.0 publish pipeline scaffolded *(local validation passes)*
- W1.1 publish pipeline live with FlagCX only
- W1.2 + FlagScale
- W1.3 + FlagTree-nvidia
- W1.4 + FlagGems
- ...

Each increment ships a real artifact users can install. Slipping any
one increment doesn't block the others.

### 2. Honest weekly status — planned vs actual, with reasons

Every Sunday, write a short note:

```
Week ending YYYY-MM-DD
======================
Planned this week:
  - <item>           [DONE | SLIP | DROP]   [reason in 1 sentence]
  - <item>           [DONE | SLIP | DROP]   [reason]

Unexpected wins:
  - <item not in plan>

Plan for next week:
  - ...
```

Reasons matter more than counts: "slipped because MUSA toolkit isn't
on the H20 runner" is actionable; "behind schedule" is not.

### 3. Time-box exploration; defer with intent

Some work has unknown duration (a vendor SDK that may or may not
build under our pipeline; a kernel that may need debugger access).
Give those a hard limit before starting:

- "Try FlagTree-mthreads packaging — 2 working days."
- If it lands, great.
- If it doesn't, write down what blocked it, defer to a future week
  with a precondition ("when MUSA toolkit installer is available
  outside Harbor"), and move on.

The cost of deferring with intent is low; the cost of dragging
on indefinitely on uncertain work is high (it crowds out the high-
confidence items).

## When to renegotiate the bigger plan

Renegotiate (move dates, drop scope) when:

- A core technical assumption proved wrong (e.g., distro LLVM
  unusable for FlagTree)
- A required dependency is unavailable (vendor SDK, signing key)
- Downstream stakeholders need a different shape of artifact

Don't renegotiate over normal week-to-week variance — that's what the
weekly status note absorbs. The bigger plan should change rarely; the
weekly note changes always.

## Current snapshot (2026-04-26)

```
Week ending 2026-05-03
======================
Planned this week (W1):
  - flagos-packaging P1 bootstrap     DONE       (e71980c-style stub
                                                  ready locally; not
                                                  pushed yet)
  - flagos-packaging P2 scripts       DONE       (6 scripts + workflow)
  - flagos-packaging P3 local valid.  DONE       (apt install works
                                                  end-to-end against
                                                  signed local repo)
  - FlagTree spike review             DONE       (36 min build, 84 MB
                                                  .deb verified)
  - FlagScale PR submission           SLIP       (packaging committed
                                                  to pr/packaging today;
                                                  push-to-fork pending)
  - FlagCX #393 buildx removal        DONE       (commit 345a7aa)
  - MT SDK runner availability        SLIP       (need SSH to H20)

Unexpected wins:
  - FlagTree-nvidia DEB packaging        +2 packages
  - libtriton-jit catalogued in matrix   +2 packages
  - Local validation pipeline writeup

Cumulative: 12/40 packages reachable via the local pipeline.

Plan for week W2 (2026-04-27 → 2026-05-03):
  W2.1  Push flagos-packaging to a remote, run publish.yml live
        on FlagCX-only artifacts (smallest blast radius)
  W2.2  + FlagScale and FlagTree to the live pipeline
  W2.3  FlagTree RPM build (mirror nvidia DEB)
  W2.4  FlagGems packaging (Python path; reuse FlagScale template)
  W2.5  MT SDK availability check on H20 (time-boxed: 1 day)
        If reachable: start FlagTree-mthreads packaging
        If not: defer with precondition

  Stretch: FlagAttention packaging (Python path)
```

## Update 2026-04-26 evening — pulling more into W1

Local validation removed the highest-uncertainty item from W1, so we
can pull additional work forward into the same week without blockers:

```
Added to W1 (no external dependency):
  - FlagTree-nvidia RPM build           +1 package
  - libtriton-jit added to components/  pure config
  - YUM-side local validation           proves RPM half of pipeline
  - FlagCX RPM local rebuild            +6 packages (3 backends × 2)
  - Repo polish: LICENSE, *_cn.md,
    add-component.md
  - Dockerfile narrow-COPY optimization (FlagTree)

After this batch, expected cumulative: ~19/40 packages reachable via
the local pipeline.
```

## Known issues to revisit

### Multi-Python-ABI matrix needed for FlagTree RPMs

The wheel-builder stage in FlagTree's Dockerfile.rpm produces a wheel
tagged `cp310-cp310-linux_x86_64`. That wheel installs cleanly on
hosts with Python 3.10 (Ubuntu 22.04, OpenEuler 24.03, fedora:36) but
is rejected outright by `pip install` on Python 3.11+ hosts —
including fedora:43 (Python 3.14).

For now we target Python 3.10 only and the RPM builds on `fedora:36`
to match. To cover the full distro matrix (fedora 43, OpenCloudOS 9,
OpenAnolis 8, OpenEuler 24.03, etc.) we need either:

- A build matrix that produces one wheel per Python ABI, or
- A noarch wrapper RPM that depends on the right `python3.X-flagtree`
  binary RPM.

Action: track as W2 work. Don't expand the published RPM set until
this is solved, otherwise users on fedora 43 install our RPM and it
silently fails to import.

### FlagTree bundles more than LLVM

The wheel bundles four upstream artifacts: LLVM (~hundreds MB),
pybind11, NVIDIA `ptxas`, and NVIDIA `cuobjdump`. The two NVIDIA tools
are proprietary (CUDA EULA), placing the assembled package outside
Debian DFSG-free and Fedora-main eligibility. `debian/copyright` and
the RPM `%license` block currently under-document these embeds.

Action items, rough priority:
1. (now) Enumerate every bundled component's license in
   `debian/copyright` and the spec — closes a real legal gap.
2. (this quarter) Investigate factoring NVIDIA tools out — either a
   separate `flagtree-nvidia-tools` package, or runtime discovery of
   system-installed CUDA toolkit.
3. (track upstream) When Triton supports building against system
   LLVM, drop the bundled LLVM. Currently blocked on upstream Triton.

## Backlog — explicitly deferred

These are real gaps that we chose not to address now. Capture so they
don't get re-discovered cold.

### FlagTree libtriton split into a standalone C++ library — deferred

**State:** FlagTree's `CMakeLists.txt` has zero `install()` rules.
The 119 MB `libtriton.cpython-310-x86_64-linux-gnu.so` is a CPython
extension (pybind11 wrapping `main.cc` / `ir.cc` / `passes.cc`), not
a C++-consumable shared library. dh-python correctly handles it as a
Python C-extension, so `python3-flagtree-nvidia` is policy-compliant
**as a Python package** — but the .so is not linkable from C++ (no
public C API, no SONAME, no headers exposed).

**To make libtriton consumable as a C++ library would require
upstream restructure:**

1. Split `libtriton` into a pure C++ runtime + a thin pybind11
   frontend (the wrapper would re-export Python bindings on top of a
   stable C API).
2. Design + document a public C API.
3. Add `install(TARGETS triton EXPORT TritonTargets RUNTIME …
   LIBRARY … ARCHIVE …)` plus `install(DIRECTORY include/triton/
   DESTINATION include)` to expose headers.
4. Stop bundling LLVM (use system) — currently blocks on upstream
   Triton support for system-LLVM build.

**Why deferred:** non-trivial upstream refactor, no immediate consumer
asking for the C API. Revisit if a real C/C++ downstream user shows
up.

**Lower-hanging adjacent option (also deferred):** package the four
MLIR developer tools in `bin/` (`triton-opt`, `triton-reduce`,
`triton-lsp`, `triton-llvm-opt`) as `flagtree-tools.deb`. Just needs
an upstream `install(TARGETS … RUNTIME DESTINATION bin)` line in
`bin/CMakeLists.txt`. Not blocking; not requested.

### FlagPerf packaging — deferred

`flagos-ai/FlagPerf` has no `pyproject.toml` / `setup.py` / CLI entry
point — it's a clone-and-configure benchmark harness, not an
installable package. Packaging it as deb would require upstream to
add a proper Python package layout. **Not in current scope.**

### Round 2 workflow additions — pending Round 1 review

The three repos with zero `.github/workflows/` directory currently
(FlagSparse, FlagAudio, FlagFFT) didn't get `build-deb.yml` /
`build-rpm.yml` added in the initial round, since they have no CI
precedent to model against. Wait for at least one of the eight
Round-1 PRs to land or get review feedback before opening a fresh CI
workflow against a repo that has none.

## FlagGems C++ operator extension — split design (consumer identified)

Originally `components/flaggems.yml` deferred "Phase 2"
(libflaggems + python3-flag-gems C-extension). A real consumer now
exists: the `flaggems-nvidia-12.8` container builds FlagGems' C++
operators against `libtriton_jit`, currently via CMake FetchContent
of `GIT_TAG master` (non-reproducible, recompiled every build,
build-time GitHub dependency). Installing prebuilt deb/rpm replaces
that with `apt install`.

**Why the split is needed (compile-time backend, not runtime):**
`libtriton_jit`'s `BACKEND` is a compile-time CMake cache var:
`target_compile_definitions(triton_jit PUBLIC BACKEND_${BACKEND})`.
The `PUBLIC` propagates the `BACKEND_CUDA` macro to consumers, so
FlagGems' C++ operators compiled against the CUDA build are
themselves a CUDA-only binary. One binary = one backend, at both
layers. (The `multi-backend` branch is a code-tree refactor — one
source tree, still one backend per compile — not a runtime-multi
binary.)

**Scope (clarified 2026-06-16): build against libtriton-dev, do NOT
ship FlagGems binary packages.** The goal is a clean libtriton-jit
`-dev` package in the repo that FlagGems' container **builds against
from source** — replacing today's CMake FetchContent of
`GIT_TAG master` with `apt install libtriton-jit-dev`. We are NOT
producing prebuilt FlagGems operator debs (`libflaggems-nvidia`,
`python3-flag-gems-nvidia`); those are dropped.

```
libtriton_jit build-deb.yml ──► libtriton-jit(-dev) deb   [produce]
        │  #28 caller → build-infra reusable upload
        ▼
flagos-apt-hosted (Nexus)                                 [publish]
        │  apt install libtriton-jit-dev
        ▼
FlagGems container: -DFLAGGEMS_USE_EXTERNAL_TRITON_JIT=ON [build from source]
```

So the only published artifact is libtriton-jit(-dev); everything
downstream (FlagGems C++ operators) is compiled in the container.
The "three-layer FlagGems binary packaging" idea is explicitly out
of scope under this goal — kept here only as a note in case a future
need to ship prebuilt FlagGems operators appears.

**Positioning: libtriton-jit-dev is a build-time-only dependency;
end users do not install it.** Who touches it, and when:

- `libtriton-jit-dev` (headers + cmake config): used **only at build
  time**, by whatever builds a libtriton_jit consumer — i.e. the
  FlagGems container's builder stage (`apt install libtriton-jit-dev`
  → build the C++ ext). No end user ever installs it.
- `libtriton-jit` (runtime `.so`): a runtime dependency only of the
  dynamically-linked C extension — present inside the FlagGems
  container image (baked at build), not separately user-installed.
  (FlagFFT bundles libtriton_jit *statically*, so it needs neither
  the dev nor the runtime package at user-runtime.)
- End-user paths never involve libtriton_jit: `python3-flag-gems`
  (pure-Python noarch) uses the Python implementation; container
  users get the `.so` baked into the image.

**Implication for the publish matrix:** libtriton-jit-dev belongs on
the **internal Nexus** (it feeds container builds), not on the
public end-user repo (Pages/Releases) — nobody runs
`apt install libtriton-jit-dev` as an end user. Classify it as
"internal build input", not "end-user-installable package". This
also removes the public-repo apt-signing / `[trusted=yes]` concern
for it — the internal Nexus build-time consumption is the only path
that matters.

**Critical prerequisite — a matching libtriton build variant.** The
existing libtriton build-deb is ubuntu24.04/cuda12.6; the
`flaggems-nvidia-12.8` container is ubuntu22.04/cuda12.8/torch2.10.
A deb built for 24.04 will not install/link cleanly on 22.04, so
`build-deb.yml` must add a ubuntu22.04+cuda12.8+torch2.10 variant
(with the json-fetch and RPATH fixes below). This is the gating item
for step ③.

**What upstream already provides (no upstream change needed for most):**

- `lib/CMakeLists.txt` already has full install rules for the
  operators target (headers + `install(EXPORT FlagGemsTargets
  NAMESPACE FlagGems:: ...)`) — unlike FlagTree's libtriton, this is
  designed to be an installable system library.
- `src/flag_gems/config.py` imports the C extension as an optional
  `try: from flag_gems import c_operators / except ImportError`,
  gated by `USE_C_EXTENSION=1` — runtime split is already supported;
  the pure-Python package works standalone and lights up when the
  extension package is present.

**The one thing to verify / possibly upstream:** `csrc/cstub.cpp`
(the pybind glue, module `c_operators`) is currently built inside
the main scikit-build-core wheel. The split needs it to build
against a *system-installed* `FlagGems::operators` + the
libtriton-jit-dev cmake config. If upstream lacks that build path, a
small PR adds an option mirroring the existing
`FLAGGEMS_USE_EXTERNAL_TRITON_JIT` switch (upstream has accepted that
style before).

**ABI alignment (the real cost):** `libtriton_jit` links libtorch, so
the prebuilt deb must match the consuming container on
(backend × distro/glibc × CUDA × torch). The existing deb is
ubuntu24.04/cuda12.6; the `flaggems-nvidia-12.8` container is
ubuntu22.04/cuda12.8/torch2.10.0+cu128. A matching build variant is
required — see Phase 0 verification below. Single-chain policy:
publish only the nvidia variant matching the official container.

**Verification status:** Phase 0 build/link chain — **PASSED**
(2026-06-15). Local container `nvidia/cuda:12.8.0-devel-ubuntu22.04`
+ python3.12 + torch 2.10.0+cu128 (from flagos-pypi-nvidia), exactly
matching the `flaggems-nvidia-12.8` container:

1. `libtriton_jit` (`-DBACKEND=CUDA -DTRITON_JIT_INSTALL=ON`) built
   and installed to `/usr` — produced
   `/usr/lib/x86_64-linux-gnu/libtriton_jit.so` + full CMake package
   (`TritonJITConfig.cmake`, `TritonJITTargets*.cmake`,
   `FindTorch.cmake`). Confirms the `-dev` package contents.
2. FlagGems configured with `-DFLAGGEMS_USE_EXTERNAL_TRITON_JIT=ON`
   → `find_package(TritonJIT CONFIG REQUIRED)` resolved the installed
   package. Confirms the dev package's CMake config is consumable.
3. `cmake --build` produced `lib/liboperators.so` (linked against the
   installed TritonJIT) and
   `src/flag_gems/csrc/c_operators.cpython-312-x86_64-linux-gnu.so` —
   the exact module name `flag_gems.config` imports. Confirms the
   prebuilt-library → downstream-build story end to end.

So the deb-consumption path works; the original FetchContent of
`GIT_TAG master` can be replaced by `apt install libtriton-jit-dev`.

**Phase 0 findings to carry into Phase 1:**

- **Ubuntu 22.04 json version**: distro `nlohmann-json3-dev` is
  3.10.5 < the required 3.11.3, so the 22.04 deb variant must
  FetchContent json (or vendor a newer one) — cannot use the system
  package as the 24.04 build does.
- **RPATH leak**: the installed `libtriton_jit.so` baked the
  build-time venv torch path
  (`/venv/lib/python3.12/site-packages/torch/lib`) into its RPATH.
  In the target container torch is importable so loading works, but
  the deb should `patchelf --remove-rpath` (or set a portable
  `$ORIGIN`-relative one) rather than ship a build-host path.
- **Not yet covered (needs a GPU runner)**: the runtime cpp-op test
  (`USE_C_EXTENSION=1` actually executing operators). Phase 0
  validated build+link+install+consume only — nvcc compiles CUDA
  without a GPU, but running kernels does not.

## libtriton_jit runtime-dlopen alternative — collapses the per-backend fan-out

> **DECISION (2026-06-25): dlopen approach DEFERRED.** After the
> maintainer conversation, dlopen is **not** the near-term plan.
> Maintainer's reasoning: don't hack at the linker/loader layer — it
> is misconfiguration-prone and hard to debug (wrong-plugin / wrong-lib
> mis-binding is painful to diagnose). Agreed direction: **use the
> simple per-backend-package approach now** (compile-time backends,
> one package per backend: `libtriton-jit-nvidia`, etc.). At this
> stage **usability + stability come first** — get it running and
> reliable. dlopen stays on the table as a *later optimization* once
> the basic path is solid. Everything below is kept as the explored
> analysis / future-optimization record, NOT the active plan.

Context for a maintainer conversation (2026-06-22). The compile-time
backend design forces per-backend artifacts at every layer. A
runtime-dlopen plugin architecture would let both libtriton_jit and
FlagGems ship as a single package each.

**Compile-time evidence (multi-backend branch, citable):**

- `CMakeLists.txt:6,10` — `set(BACKEND "CUDA" CACHE STRING ...)` +
  `FATAL_ERROR` on invalid: one backend chosen at configure time.
- `CMakeLists.txt:32-43`, `src/CMakeLists.txt:38` —
  `add_compile_definitions(BACKEND_CUDA)` and
  `target_compile_definitions(triton_jit PUBLIC BACKEND_${BACKEND})`:
  the choice becomes a preprocessor macro, `PUBLIC` = propagates to
  consumers (FlagGems).
- `src/triton_jit_function_impl.cpp:120-148` — backend class
  instantiated under `#ifdef BACKEND_<X>`: only one backend's code is
  compiled in; the rest is preprocessed out.
- `backend_config.h`, `jit_utils.h` — more `#if defined(BACKEND_*)`.
- No `getenv`/registry/factory backend selection anywhere → the
  binary physically contains exactly one backend.
- Each backend links a *different, mutually-exclusive* vendor SDK
  (`src/CMakeLists.txt`: CUDA::cuda_driver / Ascend::ascendcl /
  MUSA::musa_runtime / MLU::mlu_runtime / GCU::efrt).

**The dlopen plugin alternative:**

- Make the core `libtriton_jit.so` backend-agnostic (drop the
  `BACKEND_` macros; runtime device detection).
- Build each backend as a separate plugin `.so` (each linked against
  its own vendor SDK).
- Core `dlopen`s the right plugin at runtime by device.

**What it buys:**

- libtriton can ship as **one package** (bundle all plugins; dlopen
  is lazy, so a plugin whose vendor SDK is absent simply isn't opened
  and never blocks install or the available backend).
- Because the core no longer carries `BACKEND_*`, **FlagGems' C++
  operators become backend-agnostic too → one FlagGems package**.
  This realigns the FlagGems C++ layer with FlagGems' existing
  runtime-multi-backend Python design (`GEMS_VENDOR` selects at
  runtime; one wheel already ships all 14 backends). The compile-time
  libtriton is the sole thing forcing the C++ layer to break that
  model.
- **So FlagGems needs no packaging split** — its deb stays the single
  pure-Python `python3-flag-gems` noarch; the C++ ext is built in the
  container (not shipped), and dlopen makes even that build
  backend-agnostic. The earlier "three-layer split" idea is dead.

**Behavior validated (2026-06-22, stub experiment):** a single `.deb`
bundling two backend plugins (each linked to a different vendor lib,
no vendor `Depends`) installs cleanly on a clean ubuntu:22.04 with
only one vendor lib present; the available backend dlopens and runs;
the absent backend's plugin sits in the package and fails only if
opened — it does not block install or the available backend. This
confirms the packaging/loading property; it does NOT cover the
upstream core refactor.

**Industry precedent (same "neutral loader + runtime vendor select"
pattern):** OpenCL ICD loader (`libOpenCL.so` + `/etc/OpenCL/vendors/*.icd`),
Vulkan loader (`libvulkan.so` + `icd.d/*.json`), GLVND
(`libGLX`/`libGL`), unixODBC driver manager, glibc NSS / PAM modules.

**Cost / status:** upstream core architecture change — code refactor
is "days" (the `BackendPolicy` C++20 concept already specifies the
interface, so template-policy → virtual interface is a direct
transcription; ~14 `#ifdef` sites; type-erase the vendor handles).
The build pipeline becomes N per-vendor builds + 1 assembly step
(not one build). Decision is upstream's; recorded here so the
trade-off (invest in core refactor → collapse fan-out at both
libtriton and FlagGems) is not re-derived cold.

### dlopen applicability across the stack

Which components the dlopen-single-package idea applies to, so it
isn't re-evaluated component-by-component:

| Component | Backend selection | dlopen → single package? | Note |
|-----------|-------------------|---------------------------|------|
| libtriton_jit | compile-time (`BACKEND` macro + template policy) | yes | needs template-policy → virtual-interface refactor |
| FlagGems C++ ext | inherits libtriton's `PUBLIC BACKEND_*` macro | yes (follows libtriton) | also realigns with FlagGems' runtime `GEMS_VENDOR` design |
| **FlagCX** | **compile-time (`USE_<VENDOR>` Make flags + `DEVICE_HOME`)** | **yes — independent, best-positioned** | already has a clean adaptor layer (`flagcx/adaptor/{ccl,device,net}`, `plugin_common.cc`, `adaptor_plugin/`) — the seam a dlopen plugin model needs is already there, so the refactor is cheaper than libtriton's |
| FlagTree | different Triton *version* + LLVM hash per backend | no | intrinsic fan-out: backends are different software (Triton 3.0–3.6, different LLVM), not one codebase with a swappable vendor lib; bundling = 13× ~100 MB LLVMs + Python-ABI fan-out remains |

**Dependency-graph facts behind the table (verified 2026-06-22):**

- FlagTree IS a Triton fork — it builds the `triton` module
  (`setup.py` installs `triton/backends/<backend>`) and publishes as
  the `flagtree` package (`flagtree-0.5.0+<backend><tritonver>`).
- The libtriton_jit / FlagGems chain runs on the **`triton` package**
  (e.g. `triton==3.6.0`, confirmed **upstream OpenAI Triton** by wheel
  METADATA: Home-page `triton-lang/triton`, author `phil@openai.com`),
  mirrored into `flagos-pypi-nvidia` — a *separate* package from
  `flagtree`. So FlagTree is neither built from libtriton_jit nor the
  triton the chain imports → the libtriton dlopen refactor has zero
  impact on FlagTree.
- FlagCX is a collective-comms library (NCCL-class); it does not
  depend on libtriton_jit/triton (only incidental references). Its
  per-backend fan-out is its own, and dlopen applies to it
  independently.

Note on the precedents: OpenCL ICD loader, Vulkan loader, and GLVND
are all genuinely dlopen-based — a vendor-neutral loader `dlopen`s a
vendor driver `.so` at runtime. They differ only in the *discovery*
mechanism (OpenCL: `/etc/OpenCL/vendors/*.icd` text files; Vulkan:
`icd.d/*.json` manifests with `library_path`; GLVND: vendor mapping).
Our model bundles all plugins in one package and selects by device
detection — but a registry-file discovery (like the ICD model) is an
option worth considering for extensibility.

## dlopen PoC proposal (for the upstream conversation)

Consolidated proposal: prove the dlopen architecture works on real
libtriton_jit before committing to a full production refactor. Target
is PoC quality — framework working + 2 meaningful backends, not a
finished multi-backend product.

### Backend selection for the PoC

All 6 backends on `multi-backend` have real implementations
(cuda/gcu/ix/mlu/musa/npu). Pick by SDK accessibility + how well each
exercises the architecture:

| Backend | API / handle types | Arch | SDK source | Role in PoC |
|---------|--------------------|------|------------|-------------|
| CUDA | `cuda.h` / CUstream | x86_64 | public + flagos-pypi-nvidia | baseline backend #1 |
| **IX (Iluvatar)** | `cuda.h` / CUstream (**CUDA-compatible**) | x86_64 | flagos-pypi-iluvatar | **fastest 2nd plugin** — code ≈ CUDA, just links Iluvatar's CUDA-compatible lib. Validates loader + single-package + build-against-a-different-SDK, but does NOT stress type-erasure (same CUstream type) |
| **MUSA (Moore Threads)** | own `musa.h` / MU* (**different types**) | x86_64 | flagos-pypi-mthreads | **best generalization proof** — different StreamType/KernelHandle, so it actually exercises the type-erasure that is the core architectural risk |
| GCU (Enflame) | own (smallest impl) | x86_64 | flagos-pypi-enflame | optional |
| MLU (Cambricon) | own | x86_64 | no internal mirror | skip first round (SDK harder) |
| NPU (Ascend) | ACL (most divergent) | **aarch64** | flagos-pypi-ascend | skip first round (cross-arch + most divergent) |

Recommended: **CUDA + IX** to get the framework/packaging/loader
green fastest, then add **MUSA** as the real type-erasure /
heterogeneity proof. Skip NPU (aarch64) and MLU (no mirror) initially.

### Three-tier test plan (card requirements)

| Tier | Proves | Needs a GPU card? |
|------|--------|-------------------|
| Packaging/loading mechanics | single package installs anywhere, lazy load, absent backend doesn't block | no — **already done** (stub experiment 2026-06-22) |
| 1. CUDA end-to-end | agnostic core + CUDA plugin + a kernel actually runs | yes — 1× NVIDIA (h20/jiuding runner) |
| 2. Multi-backend architectural proof | abstraction decouples for a real 2nd backend: both build + link + load + single-package | **no** — 2nd vendor SDK only (userspace libs resolve dlopen without the card; device init only fails when running a kernel) |
| 3. 2nd-backend functional | 2nd backend's kernel runs correctly on its card | yes — 2nd vendor card (**hard to obtain**); deferred. Low risk + largely dlopen-independent (codegen unchanged by the load mechanism) |

Key point: the hard *architectural* question (does it generalize to a
real 2nd backend) is answerable at Tier 2 with **SDK only, no 2nd
card** — and the 2nd vendor SDK is obtainable. The 2nd card (Tier 3)
gates only the functional kernel run, which is the same per-backend
gate that exists today and is independent of dlopen.

### Effort estimate (PoC quality, someone familiar with the code)

| Stage | Work | Time |
|-------|------|------|
| Core agnostic | template policy + 14 `#ifdef` sites → virtual `IBackend`; type-erase handles (CUstream etc. → void*/variant). `BackendPolicy` concept already defines the interface | ~2–3 d |
| CUDA plugin + loader | extract CUDA backend as a plugin `.so` + device-detect/dlopen loader | ~1–2 d |
| **= dlopen framework working (1 backend)** | | **~3–5 d** |
| + IX plugin | CUDA-compatible, near copy | +~1 d |
| + MUSA plugin | different types, exercises type-erasure | +~1–2 d |
| **= framework + 2 meaningful backends** | | **~1–1.5 weeks focused** |

### Dependencies & gating

- Have: libtriton_jit source (fork), CUDA 12.8 + torch 2.10 + triton
  3.6 build env (flagos index), 1× NVIDIA GPU (h20).
- Obtainable: 2nd vendor SDK (IX / MUSA) in a build container.
- Hard / deferred: 2nd vendor *card* (gates Tier 3 only).
- This is an upstream core change; PoC can run on a fork, production
  landing is upstream's decision.

### Backend discovery mechanism (archived — part of the deferred dlopen design)

If dlopen is ever revisited, the loader needs to pick which plugin to
load. Because the plugins are first-party and co-packaged in a
directory we control, **no vendor cooperation / registry files are
needed** (unlike OpenCL/Vulkan, whose `.icd`/`.json` registries exist
only because vendor drivers ship independently in unknown locations):

- **torch device type (most natural for libtriton_jit):** it always
  runs in a torch context (kernels for torch tensors, stream from the
  torch device). The tensor already knows its device
  (`tensor.device.type` = cuda / musa / npu ...), so select the
  plugin from that. Also resolves the multi-SDK-present ambiguity by
  construction (you load for the device the data is on).
- **directory scan + try-load + device probe (fallback / non-torch):**
  enumerate our plugin dir (e.g. `/usr/lib/triton-jit/backends/*.so`),
  `dlopen` each — those whose vendor userspace lib is absent fail and
  are skipped (lazy load filters); a `backend_available()` probe
  disambiguates if more than one loads. "Location" gives the candidate
  set; selection is by load-success + device probe.
- **registry files (ICD-style):** not needed for our first-party
  co-packaged case; only relevant if we ever support third-party
  external plugins.
- Keep an env override (e.g. `TRITON_JIT_BACKEND=cuda`) for
  testing / forcing a backend — near-zero cost.

Note this whole mechanism is moot under the 2026-06-25 decision (no
loader-layer hacking now); archived for if/when dlopen is revisited.

## Risks worth watching

- 7 FlagTree backends each need a vendor SDK in the build container.
  Each one is high uncertainty. Don't promise more than 1 backend per
  week.
- GitHub Pages serves metadata, but `.gz` content-type / cache
  headers occasionally surprise APT. First live publish.yml run will
  reveal any issue.
- Build minutes on a public repo are unlimited, but fan-out per
  push.yml run is on the order of (components × 2 formats) downloads.
  For 16 components × 2 = 32 jobs, well within free-tier concurrency.

## Known issue: libtriton_jit RPM %build links operator test exe (pre-existing)

Diagnosed 2026-06-25 from libtriton_jit #24 build-rpm run 28109659709
(rocky9 / cuda12.6). **Not caused by the packaging PR** — the rename /
22.04-deb-variant / trigger changes don't touch the RPM `%build`,
image, or source. Surfaced because the multi-backend trigger made
build-rpm run on #24 for the first time.

Root cause: `%build` compiles the operator **test** executables (e.g.
`operators/pointwise/add/test_add`) because
`TRITON_JIT_BUILD_OPERATORS`/ctests default ON for a top-level build.
`test_add` links `libtorch_cuda.so`, which needs `libcudnn.so.9` and
`libcusparseLt.so.0` — not present in the rocky9/cuda12.6 RPM build
image → `ld: undefined reference ... @libcudnn.so.9` → link fails.
(`rpmbuild --nocheck` only skips *running* tests; the test exes are
still built in `%build`.)

Fix options (owner: separate RPM workflow, per 2026-06-25): (1) disable
operator-test build in the spec `%build`
(`-DTRITON_JIT_BUILD_OPERATORS=OFF` or the ctests flag) — preferred,
packaging doesn't need test binaries; or (2) install cuDNN +
cuSPARSELt in the RPM build image. Worth checking the deb build for the
same operator-test-link exposure.

## AMD / ROCm direction — assessment (2026-06-30)

Triggered by FlagGems running on consumer AMD iGPUs (a contributor's
880M; we have a 780M). Reproduction + finding are committed under
`docs/verification/flaggems-amd/`.

**Where AMD sits today:** FlagGems on AMD runs the **pure-Python /
triton-rocm** path and does **not** touch `libtriton_jit` — confirmed
on a real 780M (`flag_gems.config.has_c_extension == False`; torch
`2.10+rocm7.2`; FlagGems `_amd` backend; small ops run). Neither
`libtriton_jit` nor FlagGems' C++ have an AMD backend (CMake `BACKEND`
lists are CUDA/IX/MUSA/MLU/NPU/GCU). So today AMD = "works, Python
only"; the C++ fast path is unavailable.

**To add a ROCm/HIP backend to libtriton_jit (if upstream wants it):**

- New `rocm_backend.h` using the HIP API (`hipStream_t`,
  `hipModule*`, `hipModuleLaunchKernel`) + CMake `BACKEND=ROCM` +
  link `libamdhip64`; FlagGems gets a `BackendROCM.cmake`. triton's
  AMD codegen already exists (triton-rocm) — this is only the
  load/launch runtime glue.
- **Effort: ~2-4 days** — HIP mirrors the CUDA driver API
  (`hipStream_t`≈`CUstream`, `hipModuleLaunchKernel`≈`cuLaunchKernel`),
  so `rocm_backend.h` is largely a cu→hip mechanical port of
  `cuda_backend.h` (230 lines), not novel design.

**Local testability (our 780M):** build `libtriton-jit-rocm` deb +
FlagGems C++ against it = headless (the `rocm/pytorch` image ships
ROCm); running kernels works for light ops, but heavy kernels hang
under the gfx1103 `HSA_OVERRIDE_GFX_VERSION=11.0.0` workaround (a
natively-supported card like 880M/gfx1150 avoids this). So the 780M is
a near-complete test bed; a stable card covers heavy kernels.

**Value judgement:** marginal for consumer iGPUs (Python path already
"works"; C++ ext is a perf optimization with little iGPU upside).
Real value is **Hygon DCU** (datacenter, ROCm/HIP — FlagGems already
has a `_hygon` Python backend) and AMD MI-series: **one HIP backend
serves both Hygon and AMD**. Decision is upstream's (issue to raise
with the maintainer); this records the cost/value so it isn't
re-derived.

### AMD local-test surface + LLVM/triton reuse findings (2026-06-30)

Verified on a real Radeon 780M (gfx1103). Repro: `docs/verification/flaggems-amd/`.

**What the local AMD iGPU expands (and doesn't):**

- Runtime-testable locally on AMD = the noarch Python components whose
  *runtime* recognises AMD: **FlagGems, FlagTensor, FlagAttention
  (incl. flash_attention), FlagSparse** — all run on the 780M. The
  `python3-flag-gems` **deb** was dpkg-installed and run on the 780M
  (first FlagOS package validated on real consumer AMD hardware).
- **Not** AMD-ready: **FlagBLAS, FlagDNN** — their own `runtime`
  device-detection has no AMD path (`RuntimeError: No device
  detected`). noarch is necessary but not sufficient; the library
  runtime must know AMD.
- **No help for the nvidia-native tier**: `libtriton-jit-nvidia`,
  `libflagfft-nvidia`, `flagtree-nvidia`, FlagGems C++ ext — these
  need an NVIDIA card; the AMD iGPU can't validate them.
- 780M caveat: gfx1103 needs `HSA_OVERRIDE_GFX_VERSION=11.0.0`; most
  kernels run (flash_attention did), a specific FlagGems matmul-2048
  hung. 880M (gfx1150) is native, no override.

**LLVM / triton reuse (re: making a FlagTree build lighter):**

- FlagTree's LLVM is a **prebuilt download** (`setup.py
  get_llvm_package_info` fetches official LLVM static libs at the
  pinned commit), not a from-source build. `LLVM_SYSPATH` can point at
  an existing LLVM, but distro/release LLVM won't match Triton's
  pinned-commit MLIR API — so "system LLVM" doesn't apply; the heavy
  cost is compiling Triton, not LLVM.
- triton cannot reuse `libtriton_jit` (wrong direction —
  libtriton_jit imports triton). But **stock `triton-rocm` already
  serves the AMD path** — the noarch smoke tests above ran on the
  container's stock triton-rocm, no FlagTree build involved. A
  `flagtree-amd` wheel is a *separate* artifact (FlagTree is a triton
  fork), only needed if the FlagTree fork specifically is wanted on
  AMD.
