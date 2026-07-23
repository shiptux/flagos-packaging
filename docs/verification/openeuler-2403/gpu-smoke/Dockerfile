# GPU smoke test for FlagOS openEuler 24.03 packages.
#
# Build & run on any host with an NVIDIA driver + nvidia-container-toolkit
# (works inside restricted environments where adding a Dockerfile is the
# only customization allowed):
#
#   docker build -t flagos-oe-gpu-smoke .
#   docker run --rm --gpus all flagos-oe-gpu-smoke
#
# Expected output ends with:  GPU SMOKE PASS <device name>
#
# The image installs python3-flagtree-nvidia (cp311, .oe2403) from the
# FlagOS repo and torch from PyPI (bundles the CUDA runtime, so the host
# only needs the driver). The AOT stage needs no GPU; the run stage does.

FROM openeuler/openeuler:24.03-lts

RUN curl -fsSL https://shiptux.github.io/flagos-packaging/flagos-openeuler2403.repo \
        -o /etc/yum.repos.d/flagos.repo \
    && dnf makecache -y \
    && dnf install -y python3-flagtree-nvidia python3-flag-attention python3-pip \
    && dnf clean all

# torch pip wheel bundles CUDA libs (~3 GB). Override the index for
# mirror/proxy setups: --build-arg PIP_INDEX_URL=...
ARG PIP_INDEX_URL=https://pypi.org/simple
ARG TORCH_SPEC=torch
RUN python3 -m pip install --no-cache-dir --index-url "${PIP_INDEX_URL}" "${TORCH_SPEC}"

COPY aot_smoke.py gpu_smoke.py /smoke/

# AOT compile chain first (no GPU needed), then real kernel execution.
CMD ["bash", "-c", "python3 /smoke/aot_smoke.py && python3 /smoke/gpu_smoke.py"]
