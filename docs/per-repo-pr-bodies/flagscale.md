### PR Category

CICD

### PR Types

New Features

### PR Description

Adds Debian (`.deb`) and RPM packaging configuration under
`packaging/debian/` and `packaging/rpm/` so FlagScale can be
distributed as a noarch package alongside the rest of the FlagOS
stack via standard `apt install` / `dnf install` flows.

**Produced binaries (built locally on Ubuntu 22.04 / Fedora 43):**

- `python3-flagscale_1.0.0-1_all.deb` (≈587 KB, noarch)
- `python3-flagscale-1.0.0-1.fc43.noarch.rpm` (≈2.0 MB)

Ships the `flagscale` CLI under `/usr/bin/flagscale`. Heavy ML deps
(PyTorch, Megatron, vLLM) are intentionally NOT declared as hard
Depends — they're sized / sourced by the user (e.g. `pip install
"flagscale[cuda-train]"` or via NVIDIA's NGC container).

**What changed (all under `packaging/`, no source code changes):**

- `debian/{control,rules,changelog,copyright,source/format}` — Debian
  source-format-3.0-native packaging using `dh-python` +
  `pyproject-rpm-macros`.
- `rpm/specs/flagscale.spec` — RPM spec mirroring the DEB layout,
  using `%pyproject_wheel` / `%pyproject_install` /
  `%pyproject_save_files` for modern Fedora compatibility.
- `{debian,rpm}/build-helpers/` — single-command containerized
  build: `bash packaging/debian/build-helpers/build-flagscale.sh`
  produces the .deb without host build-deps; same shape for RPM.

**How it was tested:**

- Local container build produces both artifacts above.
- Clean `ubuntu:24.04` + `debian:trixie` containers `apt install
  python3-flagscale` succeed; `importlib.util.find_spec('flagscale')`
  resolves under `/usr/lib/python3/dist-packages/flagscale/`.
- Public end-to-end install from
  `https://shiptux.github.io/flagos-packaging/apt` validated on
  2026-05-20 (see flagos-packaging docs).

**Distribution:**

This artifact is consumed by a central FlagOS publish repo
(sandbox at https://github.com/shiptux/flagos-packaging; the
production endpoint remains the FlagOS Nexus mirror at
`resource.flagos.net`).

**Known limitations:**

- Pure-Python noarch package; no per-Python-ABI build needed.
- Heavy ML deps left as user-supplied. Documented in
  flagos-packaging's `docs/compatibility-status.md`.
