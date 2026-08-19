<!--
PR title hint per upstream PR_TEMPLATE.md (must use [component] prefix):
[BUILD] Add Debian + RPM packaging for the nvidia backend
-->

## What this PR does

Adds Debian (`.deb`) and RPM packaging configuration under
`packaging/debian/` and `packaging/rpm/` for the **nvidia backend
only**, so FlagTree can be distributed as a `python3-flagtree-nvidia`
package via standard `apt install` / `dnf install` alongside the
rest of the FlagOS stack.

**Produced binary:**

- `python3-flagtree-nvidia_0.5.0-1_amd64.deb` (≈84 MB)
- `python3-flagtree-nvidia-0.5.0-1.fc36.x86_64.rpm` (≈87 MB)

## What changed

All under `packaging/`, no changes to the FlagTree source or build
system itself:

- `packaging/debian/{control,rules,changelog,copyright,source/format}` —
  Debian packaging using a two-stage Docker build (stage 1 produces
  the wheel via `pip wheel . --no-build-isolation` against
  `ubuntu:22.04` + LLVM downloaded from the standard upstream
  Triton location; stage 2 wraps the wheel into a `.deb` via
  `dpkg-buildpackage`).
- `packaging/rpm/specs/flagtree.spec` + Dockerfile + helper — same
  two-stage shape, stage 2 on `fedora:36` (see ABI limitation
  below).
- `packaging/spike/Dockerfile-nvidia` — reference build script for
  the wheel-build step, kept for clarity.

`debian/copyright` enumerates the four bundled upstream artifacts
(LLVM commit `10dc3a8e`, pybind11 2.11.1, NVIDIA `ptxas`, NVIDIA
`cuobjdump`) with their respective licenses for compliance.

## How it was tested

Local container build produces both artifacts above. Clean
`ubuntu:22.04` container `apt install python3-flagtree-nvidia` lands
the wheel into `/usr/lib/python3/dist-packages/triton/` (FlagTree
installs into the `triton` namespace per upstream design);
`dh_auto_test` runs an `importlib.util.find_spec('triton')` smoke
check during build.

## Known limitations (explicit, please review)

- **cp310 ABI lock.** The wheel is built against Python 3.10 (the
  ubuntu:22.04 builder's default). `dh_python3` declares
  `Depends: python3 (>= 3.10), python3 (<< 3.11)`. **The package
  will not install on Python 3.11+ distros** (Debian trixie /
  Ubuntu 24.04 / Fedora 41+). Lifting this needs per-Python-version
  builds (cp312, cp313, cp314); tracked separately as a
  multi-Python-ABI matrix expansion.

- **Bundled artifacts include NVIDIA's `ptxas` and `cuobjdump`**
  (CUDA EULA), which places the assembled package outside
  Debian-main / Fedora-main eligibility. Distribution model is
  vendor-hosted (sandbox at https://github.com/shiptux/flagos-packaging
  ; production via FlagOS Nexus). Same posture as
  `python3-pytorch-cu*` etc.

- **RPM target = fedora:36 specifically** because cp310 wheels only
  install on Python 3.10. Fedora 36 is EOL; this is a placeholder
  until the multi-Python build matrix lands.

- **Only the nvidia backend is wired up.** FlagTree's other 11
  backends (amd, ascend, mthreads, metax, iluvatar, hcu, aipu,
  sunrise, tsingmicro, enflame, xpu) each need their own per-backend
  wheel build with the relevant vendor SDK in the build container —
  separate PRs / iterations.

## Distribution

Consumed by the central FlagOS publish repo (sandbox:
https://github.com/shiptux/flagos-packaging; production: FlagOS
Nexus). Companion design notes in the sandbox repo cover
multi-distro strategy and the ABI compatibility matrix.
