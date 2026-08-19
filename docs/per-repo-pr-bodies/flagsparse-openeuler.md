# PR body — flagos-ai/FlagSparse (openEuler 24.03 RPM support)

Branch: `pr/openeuler-rpm` (base: `main`). Follow-up to merged
packaging PR [#12](https://github.com/flagos-ai/FlagSparse/pull/12).
Title: `[CICD] Add openEuler 24.03 RPM build support`

---

## Summary

Extends the RPM packaging so the same spec builds on **openEuler
24.03 LTS** in addition to Fedora 43. openEuler ships Python 3.11
and does not ship `pyproject-rpm-macros`, so the Fedora-built
`.fc43` noarch RPM (`python(abi) = 3.14`) cannot install there —
each RPM distro family needs a native rebuild.

## What changed (packaging + CI only, no source changes)

- `packaging/rpm/specs/flagsparse.spec` — parse-time capability
  check: when `%pyproject_wheel` is defined (Fedora/EL9+) the
  existing macro path is used **unchanged**; otherwise a pip-based
  `wheel`/`install` fallback with an explicit `%files` list.
- `packaging/rpm/dockerfiles/Dockerfile.rpm` — installs
  `pyproject-rpm-macros` opportunistically; reconstructs the empty
  `%dist` tag on openEuler images (`.oe2403`) so Release fields
  match official openEuler packages.
- `packaging/rpm/build-flagsparse-rpm.sh` — `BASE_IMAGE` /
  `BASE_IMAGE_VERSION` / `OUTPUT_DIR` env overrides. The original
  single-arg Fedora flow (`./build-flagsparse-rpm.sh 43`) is
  preserved.
- `.github/workflows/build-rpm.yml` — build matrix
  `fedora43` + `openeuler2403` (`fail-fast: false`). The Fedora
  artifact keeps its exact name (`flagsparse-amd64-rpm-packages`);
  openEuler uploads as `flagsparse-amd64-oe2403-rpm-packages`.

## Tested

Both targets built locally via the modified script:

| Target | Artifact | python(abi) | Result |
|--------|----------|-------------|--------|
| fedora43 (regression) | `python3-flagsparse-1.0.0-1.fc43.noarch.rpm` | 3.14 | build unchanged vs main |
| openeuler2403 | `python3-flagsparse-1.0.0-1.oe2403.noarch.rpm` | 3.11 | installs + imports on `openeuler/openeuler:24.03-lts` (`/usr/lib/python3.11/site-packages/flagsparse/`) |

## Limitations

- openEuler artifact is not yet consumed downstream; the
  flagos-packaging collector/publisher will start routing `.oe2403`
  RPMs into the `rpm/openeuler2403/` repo dir in a follow-up.
- EL8-family distros would take the same pip fallback path but are
  not added to the matrix yet.
