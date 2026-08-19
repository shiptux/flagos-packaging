## Summary

Adds Debian + RPM packaging for FlagFFT (NVIDIA backend) so it can be
installed via `apt` / `dnf` alongside the rest of the FlagOS stack.
Packaging only, no source changes.

- `packaging/debian/` — debhelper + cmake; builds `libflagfft-nvidia`
  (runtime `.so`) and `libflagfft-nvidia-dev` (headers).
- `packaging/rpm/` — matching `.spec` for the same two packages.
- `build-helpers/` — one-command containerized builds.
- NVIDIA only for now (upstream CMake requires
  `FLAGFFT_LIBTRITON_JIT_BACKEND=CUDA`); the bundled libtriton_jit is
  linked statically.

## Validation

```bash
# deb — ubuntu:24.04 + nvidia/cuda:12.6.0-devel
bash packaging/debian/build-helpers/build-flagfft.sh

# rpm — rockylinux:9 + nvidia/cuda:12.6.0-devel
bash packaging/rpm/build-flagfft-rpm.sh
```

Both produce the `libflagfft-nvidia*` packages cleanly.
