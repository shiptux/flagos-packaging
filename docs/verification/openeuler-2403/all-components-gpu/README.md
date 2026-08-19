# A100 all-components GPU verification

Date: 2026-08-06

This directory records the source-level GPU checks for the FlagOS components
that were still untested after the 2026-07-31 FlagTree and FlagCX A100 runs.
The target was the BAAI openEuler CUDA workspace supplied for this test.

## Result

All remaining components passed a result-checked NVIDIA GPU path:

| Component | GPU path checked | Result |
|-----------|------------------|--------|
| FlagAttention | flash attention vs PyTorch SDPA | PASS; max diff `4.88e-4` |
| FlagAudio | Triton gain kernel vs mathematical reference | PASS; max diff `0` |
| FlagBLAS | SAXPY vs PyTorch expression | PASS; max diff `4.77e-7` |
| FlagDNN | ReLU vs PyTorch | PASS; exact |
| FlagGems | add vs PyTorch | PASS; exact |
| FlagQuantum | H + CX + `measure_allZ` on CUDA state | PASS |
| FlagScale | GPU-tensor spiky-loss control path | PASS |
| FlagSparse | gather vs `index_select` | PASS; exact |
| FlagTensor | Triton add vs PyTorch | PASS; exact |
| libtriton_jit | C++ Triton add suite and benchmark | PASS; 5/5 |
| FlagFFT | plan tests plus C API output vs cuFFT | PASS; 8/8 + 23/23 |

Together with the earlier FlagTree vector-add and FlagCX allreduce checks, the
current inventory has zero components without an NVIDIA functional test:

- `components/*.yml`: 12 components, 12 tested.
- FlagAudio: also tested, but it is not currently catalogued in `components/`.
- Total upstream component inventory used here: 13 tested, 0 untested.

This is not equivalent to package-level acceptance. The eleven components in
this run were tested from packaging-branch source trees, not by installing the
published `.oe2403` RPMs. The result proves representative component behavior
on an A100; it does not prove every API, distributed topology, dtype, or RPM
dependency declaration.

## Environment

| Item | Value |
|------|-------|
| OS | openEuler 24.03 LTS |
| GPU | NVIDIA A100-SXM4-40GB |
| Driver | 535.161.08; CUDA driver capability 12.2 |
| Python | 3.11.6 |
| PyTorch | 2.5.1+cu124 |
| Triton | FlagTree 3.6.0 |
| Compiler | GCC 12.3.1 |
| CMake | 4.4.2 |
| CUDA compiler prefix | `/usr/local/cuda`, CUDA 13.0.48 |
| CUDA runtime used by tests | PyTorch wheel CUDA 12 libraries |

The CUDA split matters: CUDA 13 runtime cannot execute on driver 535, while
the available CUDA 12 prefix has headers and `ptxas` but no `nvcc`.

## Python harness

`run_python_smokes.py` executes each component in a separate subprocess with a
600-second timeout and a numerical or state assertion. Its expected staging
layout is `$FLAGOS_A100_ROOT/sources/<upstream-name>`; the default root is
`/root/flagos-a100-test`.

```sh
source /root/flagos-a100-test/venv/bin/activate
python /root/flagos-a100-test/harness/run_python_smokes.py
```

Observed summary:

```text
PYTHON_SMOKES 9/9 PASS
```

The `torchaudio.py` stub only satisfies FlagAudio's unconditional import on
this host. It does not implement the tested operation; the real FlagAudio gain
kernel executes on CUDA and is compared with its mathematical reference.

## Native harness

Source revisions:

- libtriton_jit `pr/packaging`: `10ce86174ab94ea844d1fa6bb192a15d0634432d`
- FlagFFT `pr/packaging`: `98447fe599de435f1851d34662a3c6094fb7058e`
- FlagFFT bundled libtriton_jit: `5f7614bcf9ae7ffb0492b70cf4ff4aaafc4af40b`

`run_native_smokes.sh` reproduces the exact CMake configuration, builds, and
tests after the source trees and offline dependency sources have been staged.
It does not download or install anything.

The recorded offline source set was nlohmann/json 3.11.3, fmt 10.2.1, and
GoogleTest 1.16.0 under `$FLAGOS_A100_ROOT/native/deps/`.

```sh
./run_native_smokes.sh
```

The native build needed environment adaptation, but no component source patch
was applied:

1. CMake/PyTorch insists on enabling the CUDA language, so configuration uses
   the available CUDA 13 `nvcc`. No project CUDA translation unit is compiled.
2. All component C++ translation units see CUDA 12 headers. CMake cache entries
   for cudart, nvrtc, and cuFFT point to the CUDA 12 PyTorch wheel libraries.
3. NVTX3 headers are supplied from the installed NVIDIA Python package.
4. PyTorch's embedded RPATH points at a nonexistent `lib64/.../nvidia` tree.
   The harness supplies `-rpath-link` and preloads the actual CUDA 12 files.
5. FlagFFT tests use `_GLIBCXX_USE_CXX11_ABI=0`, matching the installed Torch
   and bundled libtriton_jit. Without it, only the test executables fail to
   link because FlagFFT does not propagate that private dependency ABI.
6. The host lacks `sqlite-devel`. The test used a staged SQLite 3.46 header and
   linked openEuler's SQLite 3.42 runtime; FlagFFT only exercises stable SQLite
   APIs here. A real RPM build must use openEuler's matching `sqlite-devel`.

libtriton_jit output:

```text
PASSED: test_add_basic(dm, tf)
PASSED: test_add_2d(dm, tf)
PASSED: test_add_broadcast(dm, tf)
PASSED: test_add_shapes(dm, tf)
Mean latency: 843.135 us
Bandwidth:    238.783 GB/s
PASSED: test_add_benchmark(dm, tf)
All tests passed!
```

FlagFFT output:

```text
[==========] 8 tests from 1 test suite ran. (2 ms total)
[  PASSED  ] 8 tests.
[==========] 23 tests from 1 test suite ran. (427932 ms total)
[  PASSED  ] 23 tests.
```

The C API matrix covers C2C, R2C, C2R, Z2Z, D2Z, and Z2D; leaf,
four-step, Bluestein, and nested four-step plans; in-place execution; custom
streams; invalid calls; and transforms up to `2^23`. Every functional output
is compared element-by-element with cuFFT under the test's dtype-specific
tolerance.

Remote logs from the recorded run are under
`/root/flagos-a100-test/logs/`; Python machine-readable results are in
`/root/flagos-a100-test/results/python-smokes.json`.
