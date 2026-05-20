# Compatibility status — current state, not policy

Where each FlagOS package can be installed today, given the actual
binaries we have on `shiptux.github.io/flagos-packaging`. This is
state, not policy: any "✗" or "⚠" listed below is a thing that can
be unblocked by adding a build matrix dimension, not a deliberate
restriction.

Reference for the design background: `multi-distro-strategy-notes.md`
and `single-chain-policy.md`.

## Snapshot (2026-05-20)

| Component | Ubuntu 22.04 | Ubuntu 24.04 | Debian trixie | Fedora 43 | Notes |
|-----------|:---:|:---:|:---:|:---:|---|
| libflagcx-nvidia + dev | ⚠ | ⚠ | ⚠ | ⚠ | Needs NVIDIA CUDA repo (libcuda.so.1, libnccl2). Install works once repo is added. |
| libflagcx-metax + dev | ⚠ | ⚠ | ⚠ | ⚠ | Needs MetaX maca_sdk vendor repo. |
| libflagcx-ascend + dev | ⚠ | ⚠ | ⚠ | ⚠ | Needs Huawei CANN vendor repo. |
| libtriton-jit + dev | ⚠ | ⚠ | ⚠ | ⚠ | Needs CUDA + libtorch_cuda from NVIDIA repo. |
| python3-flagscale | ✓ | ✓ | ✓ | ✓ | Pure-Python noarch. No vendor deps. |
| python3-flag-gems | ✓ | ✓ | ✓ | ✓ | Phase 1 (no C++ ext). Deps in main on most distros. |
| python3-flag-attention | ✓ | ✓ | ✓ | ✓ | Recommends triton only. |
| python3-flag-dnn | ⚠ | ⚠ | ✓ | ⚠ | Depends auto-includes python3-torch. trixie has it in main. |
| python3-flag-blas | ⚠ | ⚠ | ✓ | ⚠ | Same as dnn. |
| python3-flag-audio | ⚠ | ⚠ | ✓ | ⚠ | Same. |
| python3-flagtensor | ⚠ | ⚠ | ✓ | ⚠ | Same. |
| python3-flagquantum | ⚠ | ⚠ | ✓ | ⚠ | Depends auto-includes torch and numpy. |
| python3-flagsparse | ✓ | ✓ | ✓ | ✓ | No external deps. |
| **python3-flagtree-nvidia** | ✓ | ✗ | ✗ | ✗ | cp310 wheel — Python ABI locked. Only Ubuntu 22.04 has matching Python. |

Legend:

- `✓` — installs cleanly from `apt install` / `dnf install`
- `⚠` — installs after the named vendor repo is configured (NVIDIA
  CUDA, MetaX, etc.) — apt/dnf refuses without it but doesn't fail
  invisibly
- `✗` — Python ABI lock means apt refuses outright; needs a
  separately-built wheel for that distro's Python version

## What the marks mean for users

```
✓   apt install <package>          # works immediately
⚠   apt install <vendor-repo>      # add the relevant vendor repo first,
    apt install <package>          # then ours installs

✗   wait for a future build, or use the upstream pip wheel directly
```

## How to lift each constraint

| Constraint | What's needed | Cost |
|------------|---------------|------|
| vendor SDK packages (CUDA, MetaX, Ascend) not in distro main | document the vendor-repo URL in `install.md`; users add once | 0 — documentation |
| python3-torch in `${python3:Depends}` auto-detected from pyproject — fails outside trixie | override `dh_python3 --no-guessing-deps` in our control files OR distros catch up | 1 hour per package, OR wait |
| cp310 lock on `python3-flagtree-nvidia` | add Ubuntu 24.04 / debian:trixie / fedora:43 wheel-builder stages so cp312 / cp313 / cp314 variants exist | ~36 min per Python ABI added, one-time per release |
| trixie / fedora 43 missing from "✓" on non-cp310 packages | mostly already work — table marks them based on torch dep, not on FlagTree-specific issues | shared with python3-torch fix |

## Why this is state, not policy

When the sandbox was bootstrapped, single-distro single-Python
single-backend was the target — see `single-chain-policy.md`. That
got us to a working `apt install` flow in days instead of weeks.
Each "✗" or "⚠" in the table above is a build-matrix dimension we
chose not to expand yet, not a value judgment about the distro.

When a real user shows up needing a new combo:

1. Add the matrix dimension (extra base image in our docker build, or
   a vendor repo doc snippet)
2. Cells flip to "✓"

No policy debate, no design change. Just incrementally fill the
table.
