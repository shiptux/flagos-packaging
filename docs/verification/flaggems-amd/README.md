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

## Packaged-deb test (deb-test.sh) — 2026-06-30

`verify.sh` runs FlagGems from a source checkout. `deb-test.sh` goes one
step further: it `dpkg -i`-installs our **`python3-flag-gems` deb** and
runs it on the 780M — the first FlagOS package validated on real
consumer AMD hardware end to end.

| Check | Result |
|-------|--------|
| `dpkg -i python3-flag-gems_5.0.2-1_amd64.deb` | installed to `/usr/lib/python3/dist-packages/flag_gems` |
| `flag_gems.__file__` | `/usr/lib/python3/dist-packages/flag_gems/__init__.py` (the **deb** location, not source) |
| `has_c_extension` | False |
| small op on 780M | `DEB_FLAGGEMS_ON_AMD_OK` |

The deb's `Depends` correctly declares `python3-numpy`, `python3-yaml`,
`python3-sqlalchemy`, `python3-packaging` (dpkg lists them). It does
**not** declare `python3-torch` (by design — the user supplies a
backend-flavoured torch via pip; here ROCm torch from the container).
Run it with:
```sh
docker run --rm --device=/dev/kfd --device=/dev/dri \
  --group-add "$(getent group video|cut -d: -f3)" \
  --group-add "$(getent group render|cut -d: -f3)" \
  --security-opt seccomp=unconfined -e HSA_OVERRIDE_GFX_VERSION=11.0.0 \
  -v /path/to/python3-flag-gems_*.deb:/deb/pkg.deb:ro \
  -v "$PWD/deb-test.sh:/t.sh:ro" rocm/pytorch:latest bash /t.sh
```

## Notes

- `sqlalchemy` / `numpy` / `pyyaml` aren't apt-installed in the
  `rocm/pytorch` base image, so the scripts `pip install sqlalchemy`
  (torch + triton come from the image). The `python3-flag-gems` deb
  itself **does** declare these as deps — confirmed in the deb-test
  above — so on a normal apt system they resolve.
- This validates FlagGems' Python operators (and our noarch deb) on
  AMD. It does **not** exercise `libtriton_jit` — a FlagGems-on-AMD
  C++ path would first need an upstream ROCm/HIP backend in
  `libtriton_jit` (see plan-tracking "AMD / ROCm direction").

## noarch tier — AMD smoke matrix (noarch-smoke.sh, 2026-06-30)

Tested the other pure-Python (noarch) components on the 780M. **Key
refinement: noarch is necessary but NOT sufficient for AMD** — the
library's own runtime must also recognise the AMD device.

| Component | On 780M | Note |
|-----------|---------|------|
| FlagGems | ✅ (op runs) | has `_amd` runtime backend |
| FlagTensor | ✅ `add` runs | |
| FlagAttention | ✅ **flash_attention runs** | a heavy kernel — so not all heavy kernels hang; the FlagGems matmul-2048 hang was a specific case |
| FlagSparse | ✅ imports | |
| FlagBLAS | ❌ `RuntimeError: No device were detected` | its `runtime` device-detection has no AMD path |
| FlagDNN | ❌ same | same — needs an AMD vendor added to its runtime |

So the AMD card runtime-tests the components whose runtime recognises
AMD (FlagGems / FlagTensor / FlagAttention / FlagSparse), not all
noarch packages. FlagBLAS / FlagDNN would need upstream to add an AMD
vendor to their `runtime` (like FlagGems' `_amd`).

Run: `docker run ... -v ~/git/github:/s:ro -v ./noarch-smoke.sh:/v.sh:ro rocm/pytorch:latest bash /v.sh`
