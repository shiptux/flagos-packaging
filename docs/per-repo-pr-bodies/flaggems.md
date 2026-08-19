### PR Category

CI/CD

### Type of Change

New Feature

### Description

Adds Debian (`.deb`) and RPM packaging configuration so FlagGems can
be distributed via standard `apt install` / `dnf install` alongside
the rest of the FlagOS stack.

**Phase 1 only — Python distribution, no C++ split.** Mirrors
upstream's `pip install flag_gems` default behavior
(`FLAGGEMS_BUILD_C_EXTENSIONS=OFF`); the C++ operator runtime
(`liboperators.so`) stays bundled inside the Python wheel. Phase 2
(split into `libflaggems` + `libflaggems-dev` + `python3-flag-gems`
sub-packages) requires a separate `cmake --install` step + loader
patch and is deferred to a follow-up PR.

**Produced binaries:**

- `python3-flag-gems_5.0.2-1_amd64.deb` (≈604 KB, 1501 files)
- `python3-flag-gems-5.0.2-1.fc43.noarch.rpm` (≈2.9 MB)

14 vendor backend directories (`_aipu`, `_amd`, `_ascend`,
`_cambricon`, `_enflame`, `_hygon`, `_iluvatar`, `_kunlunxin`,
`_metax`, `_mthreads`, `_nvidia`, `_sunrise`, `_tsingmicro`, `_arm`)
ship as Python source under `flag_gems/runtime/backend/`; active
backend selected at runtime via `GEMS_VENDOR` env var or PyTorch
auto-detect.

**What changed (all under `packaging/`, no source code changes):**

- `debian/{control,rules,changelog,copyright,source/format}` — Debian
  packaging via `dh-python` + scikit-build-core build backend.
- `rpm/specs/flag-gems.spec` — RPM spec, fc43-compatible, uses
  `pyproject-rpm-macros`. `%check` smoke test does
  `importlib.util.find_spec('flag_gems')` against
  `%{python3_sitearch}` (scikit-build-core marks wheels arch-tagged
  even with C++ ext OFF, so install lands in sitearch not sitelib).
- `{debian,rpm}/helpers/` — containerized build entry points.
- `debian/helpers/local-deps/.gitignore` — local libtriton-jit
  `.deb` drop point for build, never committed.

### Issue

No related issue tracked. This is the packaging companion to the
FlagOS unified distribution effort (see flagos-packaging repo).

### Progress

- [ ] Change is properly reviewed (1 reviewer required, 2 recommended).
- [x] Change is responded to an issue. (N/A — packaging-only)
- [ ] Change is fully covered by a UT.
  (Build-time smoke test = `find_spec` validates install layout;
  the full pytest suite needs GPU + cupy and stays out of
  packaging CI scope per upstream FlagGems' own test workflow.)

### Performance

No runtime performance impact — packaging-only PR. No code changes
under `src/`.
