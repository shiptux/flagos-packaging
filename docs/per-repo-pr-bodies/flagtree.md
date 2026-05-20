## Summary

Adds Debian (`.deb`) and RPM packaging configuration under
`packaging/debian/` and `packaging/rpm/` so this component can be
distributed alongside the rest of the FlagOS stack via standard
`apt install` / `dnf install` flows.

Produced binary: **python3-flagtree-nvidia** (≈84 MB .deb, ≈87 MB .rpm).

## What changed

- `packaging/debian/{control,rules,changelog,copyright,source/format}` — Debian source-format-3.0-native packaging.
- `packaging/rpm/specs/flagtree-nvidia\.spec` — RPM spec using `pyproject-rpm-macros`.
- `packaging/{debian,rpm}/helpers/` — single-command containerized build:
  `bash packaging/debian/build-helpers/build-<slug>.sh` produces the
  .deb without host build-deps; same shape for RPM.

No source code changes outside `packaging/`.

## How it was tested

Local container build produces the noarch .deb and .rpm above.
End-to-end install in clean `ubuntu:24.04` and `debian:trixie`
containers from a local signed APT repo passes `apt install` +
`importlib.util.find_spec(<module>)` smoke check.

The `dh_auto_test` override uses `importlib.util.find_spec`
rather than `import`, so the build-time smoke test validates
install layout (right path, importable from the dist-packages dir)
without triggering runtime imports of torch / triton / etc. — those
are user-install-time concerns, not packaging concerns.

The packaging Dockerfile is two-stage: `wheel-builder` (Ubuntu
22.04 + CMake + Ninja + pip downloads LLVM at build time) produces
the wheel (~36 minutes wall on a 4-core builder); `deb-assembler`
(Ubuntu 22.04 + debhelper) wraps the wheel into the .deb (~30
seconds). `rpm-assembler` uses fedora:36 for ABI match.

## Distribution

This artifact is consumed by a central FlagOS publish repo
(sandbox at https://github.com/shiptux/flagos-packaging; the
production endpoint remains the FlagOS Nexus mirror at
`resource.flagos.net`). Companion design notes in the sandbox
repo cover multi-distro strategy
(`docs/multi-distro-strategy-notes.md`) and a per-distro
compatibility matrix (`docs/compatibility-status.md`).

## Known limitations

- **cp310 ABI lock**: the wheel is built against Python 3.10 (Ubuntu 22.04 builder), so the produced .deb declares `Depends: python3 (>= 3.10), python3 (<< 3.11)` via dh_python3. **The package will NOT install on Python 3.11+ distros** (Debian trixie / Ubuntu 24.04 / fedora:43). Lifting this requires per-Python-version wheel builds; tracked separately as a multi-Python-ABI matrix expansion.
- **Bundled artifacts**: the wheel embeds LLVM (commit `10dc3a8e` from oaitriton.blob.core.windows.net), pybind11 2.11.1, NVIDIA `ptxas`, and NVIDIA `cuobjdump` (the latter two pulled from `anaconda.org/nvidia` at build time). The NVIDIA tools are proprietary (CUDA EULA), which means the assembled package falls outside Debian-main and Fedora-main eligibility. `debian/copyright` lists all four bundled components and their licenses.
- **RPM target = fedora:36** specifically because cp310 wheels only install on Python 3.10. Fedora 36 is EOL; this is a placeholder until the multi-Python build matrix lands.
- Only the `nvidia` backend is wired up. FlagTree's other 11 backends (amd, ascend, mthreads, metax, iluvatar, hcu, aipu, sunrise, tsingmicro, enflame, xpu) each need their own per-backend wheel build with the relevant vendor SDK in the build container — separate PRs / iterations.

## Out of scope (separate plans)

- Multi-Python-ABI build matrix (cp312 / cp313 / cp314) — captured
  as a known issue, not blocking this PR.
- C++ extension split (relevant for FlagGems / FlagTree only) —
  Phase 2 work, separate PR if/when needed.
