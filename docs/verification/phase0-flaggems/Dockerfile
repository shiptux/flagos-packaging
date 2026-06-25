# Phase 0 verification harness — FlagGems C++ operators build against a
# prebuilt libtriton_jit, in the env matching the flaggems-nvidia-12.8
# container (ubuntu22.04 + cuda12.8 + python3.12 + torch2.10+cu128).
#
# Two independent verification paths:
#   A) cmake-install  — libtriton installed via `cmake --install` (the
#                       original Phase 0; proves the consume mechanism)
#   B) deb            — libtriton built as a .deb, `dpkg -i`-installed,
#                       then FlagGems built against the installed package
#                       (proves the real apt-install path)
#
# Build context must contain ./libtriton_jit and ./FlagGems source trees
# (run.sh stages them). Both paths emit "VERIFY: ... OK" markers and the
# final stage prints "VERIFY: ALL PASSED".
#
# Note: nvcc compiles CUDA without a GPU, so build+link+consume is
# verified headless. Running kernels (correctness) needs a card and is
# out of scope here.

# ============================================================
#  Common env (matches flaggems-nvidia-12.8)
# ============================================================
FROM nvidia/cuda:12.8.0-devel-ubuntu22.04 AS env
ARG DEBIAN_FRONTEND=noninteractive
ARG PYV=3.12
ARG TORCH_INDEX=https://resource.flagos.net/repository/flagos-pypi-nvidia/simple
ARG BUILD_PARALLEL=4

RUN apt-get update && apt-get install -y --no-install-recommends \
        software-properties-common curl ca-certificates git \
        build-essential ninja-build patchelf \
        debhelper devscripts dpkg-dev fakeroot \
    && add-apt-repository -y ppa:deadsnakes/ppa && apt-get update \
    && apt-get install -y --no-install-recommends \
        python${PYV} python${PYV}-dev python${PYV}-venv \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYV} 1 \
    && update-alternatives --install /usr/bin/python  python  /usr/bin/python${PYV} 1 \
    && curl -sS https://bootstrap.pypa.io/get-pip.py | python3 \
    && rm -rf /var/lib/apt/lists/*
RUN python3 -m pip install --no-cache-dir "cmake>=3.25,<4.0" "ninja==1.13.0" "pybind11==3.0.3"
RUN python3 -m pip install --no-cache-dir --index-url ${TORCH_INDEX} \
        "torch==2.10.0+cu128" "triton==3.6.0"
RUN echo "VERIFY: env $(python3 --version), torch $(python3 -c 'import torch;print(torch.__version__)'), cmake $(cmake --version|head -1)"

# ============================================================
#  Path A — cmake-install
# ============================================================
FROM env AS verify-cmake-install
COPY libtriton_jit /src/libtriton_jit
RUN cmake -S /src/libtriton_jit -B /tmp/ltj -GNinja \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr \
        -DBACKEND=CUDA -DTRITON_JIT_INSTALL=ON \
        -DTRITON_JIT_USE_EXTERNAL_JSON=OFF \
        -DTRITON_JIT_USE_EXTERNAL_FMTLIB=OFF \
        -DTRITON_JIT_USE_EXTERNAL_PYBIND11=ON \
        -DTRITON_JIT_BUILD_EXAMPLES=OFF \
        -Dpybind11_DIR="$(python3 -m pybind11 --cmakedir)" \
        -DCMAKE_PREFIX_PATH="$(python3 -c 'import torch;print(torch.utils.cmake_prefix_path)')" \
    && cmake --build /tmp/ltj --parallel ${BUILD_PARALLEL} \
    && cmake --install /tmp/ltj \
    && test -f /usr/lib/*/cmake/TritonJIT/TritonJITConfig.cmake \
    && echo "VERIFY[A]: libtriton_jit cmake-installed + TritonJIT config present"
COPY FlagGems /src/FlagGems
RUN cmake -S /src/FlagGems -B /tmp/fg -GNinja \
        -DCMAKE_BUILD_TYPE=Release -DFLAGGEMS_BACKEND=CUDA \
        -DFLAGGEMS_USE_EXTERNAL_TRITON_JIT=ON \
        -DFLAGGEMS_BUILD_C_EXTENSIONS=ON \
        -DFLAGGEMS_USE_EXTERNAL_PYBIND11=ON \
        -DCMAKE_PREFIX_PATH="$(python3 -c 'import torch;print(torch.utils.cmake_prefix_path)')" \
        -Dpybind11_DIR="$(python3 -m pybind11 --cmakedir)" \
    && cmake --build /tmp/fg --parallel ${BUILD_PARALLEL} \
    && find /tmp/fg -name 'c_operators*.so' | grep -q . \
    && echo "VERIFY[A]: FlagGems c_operators built against cmake-installed TritonJIT  -> OK"

# ============================================================
#  Path B — real .deb
# ============================================================
FROM env AS verify-deb
ARG BUILD_PARALLEL=4
COPY libtriton_jit /src/libtriton_jit
WORKDIR /src/libtriton_jit
# debian/ at source root; force json fetch (22.04 system json too old)
# regardless of what the source ref's rules currently sets.
RUN cp -r packaging/debian debian \
    && sed -i 's/-DTRITON_JIT_USE_EXTERNAL_JSON=ON/-DTRITON_JIT_USE_EXTERNAL_JSON=OFF/' debian/rules \
    && DEB_BUILD_OPTIONS="parallel=${BUILD_PARALLEL}" dpkg-buildpackage -us -uc -b -d \
    && mkdir -p /debs && find /src -maxdepth 1 -name '*.deb' -exec cp {} /debs/ \; \
    && ls /debs && echo "VERIFY[B]: libtriton_jit .deb built"
# install the freshly built deb(s); --force-depends: torch/cuda come from pip, not apt
RUN dpkg -i --force-depends /debs/*.deb \
    && find /usr -path '*cmake/TritonJIT/*Config.cmake' | grep -q . \
    && echo "VERIFY[B]: .deb installed + TritonJIT config present"
COPY FlagGems /src/FlagGems
RUN cmake -S /src/FlagGems -B /tmp/fg -GNinja \
        -DCMAKE_BUILD_TYPE=Release -DFLAGGEMS_BACKEND=CUDA \
        -DFLAGGEMS_USE_EXTERNAL_TRITON_JIT=ON \
        -DFLAGGEMS_BUILD_C_EXTENSIONS=ON \
        -DFLAGGEMS_USE_EXTERNAL_PYBIND11=ON \
        -DCMAKE_PREFIX_PATH="$(python3 -c 'import torch;print(torch.utils.cmake_prefix_path)')" \
        -Dpybind11_DIR="$(python3 -m pybind11 --cmakedir)" \
    && cmake --build /tmp/fg --parallel ${BUILD_PARALLEL} \
    && find /tmp/fg -name 'c_operators*.so' | grep -q . \
    && echo "VERIFY[B]: FlagGems c_operators built against installed .deb  -> OK"

# ============================================================
#  Final — both paths must have passed to reach here
# ============================================================
FROM env AS verify
COPY --from=verify-cmake-install /tmp/fg/src/flag_gems/csrc/ /verify/A/
COPY --from=verify-deb          /tmp/fg/src/flag_gems/csrc/ /verify/B/
RUN echo "VERIFY: path A (cmake-install) artifacts:" && ls /verify/A/*.so \
    && echo "VERIFY: path B (.deb) artifacts:" && ls /verify/B/*.so \
    && echo "VERIFY: ALL PASSED"
