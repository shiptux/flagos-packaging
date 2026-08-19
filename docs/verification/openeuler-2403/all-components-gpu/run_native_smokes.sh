#!/usr/bin/env bash
set -euo pipefail

# Reproduce the source-level libtriton_jit and FlagFFT A100 tests. The source
# trees and fixed-version CMake dependencies must already be staged below ROOT.
ROOT=${FLAGOS_A100_ROOT:-/root/flagos-a100-test}
NVIDIA_PY_ROOT=${FLAGOS_NVIDIA_PY_ROOT:-/usr/local/lib/python3.11/site-packages/nvidia}
TORCH_ROOT=${FLAGOS_TORCH_ROOT:-/usr/local/lib64/python3.11/site-packages/torch}
CUDA_COMPILER=${FLAGOS_CUDA_COMPILER:-/usr/local/cuda/bin/nvcc}
CUDA12_INCLUDE=${FLAGOS_CUDA12_INCLUDE:-/opt/cuda12/include}

PYTHON="$ROOT/venv/bin/python"
CMAKE="$ROOT/venv/bin/cmake"
NINJA="$ROOT/venv/bin/ninja"
DEPS="$ROOT/native/deps"
SOURCES="$ROOT/native/sources"
LOGS="$ROOT/logs"
LIBTRITON_SOURCE="$SOURCES/libtriton_jit"
LIBTRITON_BUILD="$LIBTRITON_SOURCE/build-a100"
FLAGFFT_SOURCE="$SOURCES/FlagFFT"
FLAGFFT_BUILD="$FLAGFFT_SOURCE/build-a100"
FLAGFFT_INSTALL="$ROOT/native/install-flagfft"

cuda_lib_dirs=(
  "$TORCH_ROOT/lib"
  "$NVIDIA_PY_ROOT/cuda_runtime/lib"
  "$NVIDIA_PY_ROOT/cuda_cupti/lib"
  "$NVIDIA_PY_ROOT/cublas/lib"
  "$NVIDIA_PY_ROOT/cufft/lib"
  "$NVIDIA_PY_ROOT/cudnn/lib"
  "$NVIDIA_PY_ROOT/nccl/lib"
  "$NVIDIA_PY_ROOT/nvjitlink/lib"
  "$NVIDIA_PY_ROOT/curand/lib"
  "$NVIDIA_PY_ROOT/cusolver/lib"
  "$NVIDIA_PY_ROOT/cusparse/lib"
)

cuda_rpath_flags=()
for flagos_lib_dir in "${cuda_lib_dirs[@]}"; do
  cuda_rpath_flags+=("-Wl,-rpath-link,$flagos_lib_dir")
done
cuda_rpath_string=${cuda_rpath_flags[*]}
cuda_library_path=$(IFS=:; printf '%s' "${cuda_lib_dirs[*]}")

cuda_preloads=(
  "$NVIDIA_PY_ROOT/cuda_runtime/lib/libcudart.so.12"
  "$NVIDIA_PY_ROOT/cuda_cupti/lib/libcupti.so.12"
  "$NVIDIA_PY_ROOT/nvjitlink/lib/libnvJitLink.so.12"
  "$NVIDIA_PY_ROOT/cublas/lib/libcublasLt.so.12"
  "$NVIDIA_PY_ROOT/cublas/lib/libcublas.so.12"
  "$NVIDIA_PY_ROOT/cufft/lib/libcufft.so.11"
  "$NVIDIA_PY_ROOT/curand/lib/libcurand.so.10"
  "$NVIDIA_PY_ROOT/cusparse/lib/libcusparse.so.12"
  "$NVIDIA_PY_ROOT/cudnn/lib/libcudnn.so.9"
  "$NVIDIA_PY_ROOT/nccl/lib/libnccl.so.2"
)
cuda_preload=$(IFS=:; printf '%s' "${cuda_preloads[*]}")

python_dirs=(
  "$ROOT/venv/lib/python3.11/site-packages"
  "$ROOT/venv/lib64/python3.11/site-packages"
  "/usr/local/lib64/python3.11/site-packages"
  "/usr/local/lib/python3.11/site-packages"
)
python_path=$(IFS=:; printf '%s' "${python_dirs[*]}")

common_cuda_args=(
  "-DCMAKE_CUDA_COMPILER=$CUDA_COMPILER"
  "-DCMAKE_CUDA_ARCHITECTURES=80"
  "-DCUDA_CUDART=$NVIDIA_PY_ROOT/cuda_runtime/lib/libcudart.so.12"
  "-DCUDA_CUDART_LIBRARY=$NVIDIA_PY_ROOT/cuda_runtime/lib/libcudart.so.12"
  "-DCUDA_cudart_LIBRARY=$NVIDIA_PY_ROOT/cuda_runtime/lib/libcudart.so.12"
  "-DCUDA_NVRTC_LIB=$NVIDIA_PY_ROOT/cuda_nvrtc/lib/libnvrtc.so.12"
  "-DCUDA_nvrtc_LIBRARY=$NVIDIA_PY_ROOT/cuda_nvrtc/lib/libnvrtc.so.12"
  "-DPython_EXECUTABLE=$PYTHON"
  "-DPython_ROOT=$ROOT/venv"
  "-DCMAKE_PREFIX_PATH=$TORCH_ROOT/share/cmake"
  "-DCMAKE_EXE_LINKER_FLAGS=$cuda_rpath_string"
  "-DCMAKE_SHARED_LINKER_FLAGS=$cuda_rpath_string"
  "-DCMAKE_BUILD_TYPE=Release"
)

offline_args=(
  "-DFETCHCONTENT_SOURCE_DIR_JSON=$DEPS/json"
  "-DFETCHCONTENT_SOURCE_DIR_FMT=$DEPS/fmt"
  "-DFETCHCONTENT_SOURCE_DIR_GOOGLETEST=$DEPS/googletest"
  "-DFMT_INSTALL=OFF"
)

required_paths=(
  "$PYTHON"
  "$CMAKE"
  "$NINJA"
  "$CUDA_COMPILER"
  "$CUDA12_INCLUDE/cuda.h"
  "$DEPS/json/CMakeLists.txt"
  "$DEPS/fmt/CMakeLists.txt"
  "$DEPS/googletest/CMakeLists.txt"
  "$DEPS/sqlite/include/sqlite3.h"
  "/usr/lib64/libsqlite3.so.0"
  "$LIBTRITON_SOURCE/CMakeLists.txt"
  "$FLAGFFT_SOURCE/CMakeLists.txt"
)
for flagos_path in "${required_paths[@]}"; do
  if [[ ! -e "$flagos_path" ]]; then
    printf 'missing required path: %s\n' "$flagos_path" >&2
    exit 2
  fi
done

mkdir -p "$LOGS" "$ROOT/cache/flagfft-triton"
for flagos_triton_source in "$LIBTRITON_SOURCE" "$FLAGFFT_SOURCE/deps/libtriton_jit"; do
  mkdir -p "$flagos_triton_source/third_party/NVTX/c/include"
  ln -sfn "$NVIDIA_PY_ROOT/nvtx/include/nvtx3" \
    "$flagos_triton_source/third_party/NVTX/c/include/nvtx3"
done

"$CMAKE" -S "$LIBTRITON_SOURCE" -B "$LIBTRITON_BUILD" -G Ninja \
  "-DCMAKE_MAKE_PROGRAM=$NINJA" \
  -DBACKEND=CUDA \
  -DTRITON_JIT_BUILD_OPERATORS=ON \
  -DTRITON_JIT_INSTALL=OFF \
  "-DCMAKE_CXX_FLAGS=-I$CUDA12_INCLUDE" \
  "${common_cuda_args[@]}" \
  "${offline_args[@]}" \
  2>&1 | tee "$LOGS/native-libtriton-configure.log"
"$CMAKE" --build "$LIBTRITON_BUILD" --target test_add --parallel 4 \
  2>&1 | tee "$LOGS/native-libtriton-build.log"

(
  cd "$LIBTRITON_BUILD/operators/pointwise/add"
  env \
    LD_PRELOAD="$cuda_preload" \
    LD_LIBRARY_PATH="$cuda_library_path" \
    PYTHONPATH="$python_path" \
    timeout 600s ./test_add
) 2>&1 | tee "$LOGS/native-libtriton-test-add-a100.log"

"$CMAKE" -S "$FLAGFFT_SOURCE" -B "$FLAGFFT_BUILD" -G Ninja \
  "-DCMAKE_MAKE_PROGRAM=$NINJA" \
  -DFLAGFFT_BUILD_TESTS=ON \
  -DBUILD_TESTING=ON \
  -DFLAGFFT_LIBTRITON_JIT_BACKEND=CUDA \
  "-DCMAKE_CXX_FLAGS=-I$CUDA12_INCLUDE -I$NVIDIA_PY_ROOT/cufft/include" \
  "-DCUDA_CUFFT=$NVIDIA_PY_ROOT/cufft/lib/libcufft.so.11" \
  "-DCUDA_cufft_LIBRARY=$NVIDIA_PY_ROOT/cufft/lib/libcufft.so.11" \
  "-DSQLite3_INCLUDE_DIR=$DEPS/sqlite/include" \
  -DSQLite3_LIBRARY=/usr/lib64/libsqlite3.so.0 \
  "${common_cuda_args[@]}" \
  "${offline_args[@]}" \
  2>&1 | tee "$LOGS/native-flagfft-configure.log"
"$CMAKE" --build "$FLAGFFT_BUILD" \
  --target flagfft_plan_tests flagfft_c_api_tests --parallel 8 \
  2>&1 | tee "$LOGS/native-flagfft-build.log"

"$CMAKE" --install "$FLAGFFT_BUILD" --prefix "$FLAGFFT_INSTALL/usr" \
  2>&1 | tee "$LOGS/native-flagfft-install.log"

installed_flagfft=$(find "$FLAGFFT_INSTALL/usr" -type f -name libflagfft.so -print -quit)
installed_triton=$(find "$FLAGFFT_INSTALL/usr" -type f -name libflagfft_triton_jit.so -print -quit)
installed_jit_source="$FLAGFFT_INSTALL/usr/share/flagfft/python/src/codegen/jit_source.py"
installed_triton_compiler="$FLAGFFT_INSTALL/usr/share/triton_jit/scripts/standalone_compile.py"
for flagos_path in \
  "$installed_flagfft" \
  "$installed_triton" \
  "$installed_jit_source" \
  "$installed_triton_compiler"; do
  if [[ ! -f "$flagos_path" ]]; then
    printf 'missing installed FlagFFT runtime file: %s\n' "$flagos_path" >&2
    exit 3
  fi
done
readelf -d "$installed_flagfft" | grep -q '\[libflagfft_triton_jit.so\]'
if readelf -d "$installed_flagfft" | grep -q '\[libtriton_jit.so\]'; then
  printf 'installed libflagfft still depends on unbundled libtriton_jit.so\n' >&2
  exit 3
fi

native_test_env=(
  "LD_PRELOAD=$cuda_preload:$installed_triton:$installed_flagfft"
  "LD_LIBRARY_PATH=$(dirname "$installed_flagfft"):$cuda_library_path"
  "PYTHONPATH=$python_path"
  "FLAGFFT_PYTHON=$PYTHON"
  "TRITON_CACHE_DIR=$ROOT/cache/flagfft-triton"
)
(
  cd "$FLAGFFT_INSTALL"
  env "${native_test_env[@]}" \
    "$FLAGFFT_BUILD/flagfft_plan_tests" --gtest_color=no
) 2>&1 | tee "$LOGS/native-flagfft-plan-tests.log"
(
  cd "$FLAGFFT_INSTALL"
  env "${native_test_env[@]}" timeout 1800s \
    "$FLAGFFT_BUILD/flagfft_c_api_tests" --gtest_color=no
) 2>&1 | tee "$LOGS/native-flagfft-c-api-full-a100.log"

printf 'NATIVE_SMOKES PASS\n'
