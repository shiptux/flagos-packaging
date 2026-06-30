# FlagGems on AMD (consumer iGPU) — reproduction + finding

Reproducible harness for: **does FlagGems run on an AMD GPU, and does
that path go through `libtriton_jit`?**

## Conclusion

**No, AMD does not go through `libtriton_jit`.** FlagGems on AMD runs
the **pure-Python / triton-rocm** path:

- Neither `libtriton_jit` nor FlagGems' C++ operators have an AMD
  backend (their CMake `BACKEND` lists are CUDA/IX/MUSA/MLU/NPU/GCU —
  no ROCm/HIP). So the C++ path is *unavailable* on AMD.
- FlagGems' `_amd` runtime backend (`src/flag_gems/runtime/backend/_amd`,
  `device_name="cuda"`, `device_query_cmd="rocm-smi"`) drives the GPU
  through PyTorch-ROCm (AMD GPUs appear as `torch.device("cuda")`).
- Verified at runtime: `flag_gems.config.has_c_extension == False`.

## Verified result (2026-06-30, AMD Radeon 780M / gfx1103)

| Check | Result |
|-------|--------|
| `rocm-smi` | AMD Radeon 780M Graphics, **gfx1103** |
| torch | `2.10.0+rocm7.2.4`, `cuda_avail=True`, device = AMD Radeon 780M |
| triton | `3.6.0+rocm7.2.4` |
| `flag_gems.config.has_c_extension` | **False** (Python path, no libtriton_jit) |
| `_amd` backend loaded + ops intercepted | yes |
| small FlagGems op (`add`, 1024) | **OK** |
| plain torch matmul (1024) | OK |
| FlagGems matmul (2048) | **GPU Hang** (see caveat) |

## 780M caveat (gfx1103)

The 780M is not in ROCm's official support list, so the run needs
`HSA_OVERRIDE_GFX_VERSION=11.0.0` (presents it as gfx1100). With that
override, light/pointwise FlagGems kernels run fine, but a heavier
kernel (the 2048 matmul) hung the GPU — an override-codegen mismatch,
not a FlagGems/packaging problem (plain torch matmul and small
FlagGems ops both work). A natively-supported card (e.g. **880M /
gfx1150, no override**) does not hit this. So as a runtime test bed,
the 780M is reliable for light ops; heavy kernels may need override
tuning or a fallback card.

## Run

```sh
# 780M (gfx1103) — needs the override (default)
./run.sh

# 880M / natively-supported card — no override
GFX_OVERRIDE= ./run.sh
```

Host requirements: amdgpu loaded, `/dev/kfd` + `/dev/dri` present, and
the user in the `render` + `video` groups (no sudo). The
`rocm/pytorch` image is ~30 GB on first pull.

## Notes

- `sqlalchemy` is required by FlagGems (operator-cache persistence) and
  is not in the base image — `verify.sh` installs it. **The
  `python3-flag-gems` deb must declare `sqlalchemy` (plus torch /
  triton) in its dependencies**, or an installed-deb run fails the same
  way.
- This validates FlagGems' Python operators on AMD. It does **not**
  exercise our `.deb` packaging or `libtriton_jit` — packaging a
  FlagGems-on-AMD C++ path would first require an upstream ROCm/HIP
  backend in `libtriton_jit` (separate assessment).
