# flagos-packaging

Central publishing repo for the FlagOS software stack — pulls per-component
build artifacts from upstream repos, signs them with a single GPG key,
generates APT and YUM repository metadata, and serves the result via
GitHub Pages + Releases so users can install with `apt install` or
`dnf install`.

## Architecture

```
upstream repos (FlagCX, FlagScale, FlagTree, ...)
  └─ packaging/{debian,rpm}/ + build-*.yml
        └─ artifacts (.deb, .rpm)
              ↓
flagos-packaging (this repo)
  1. Pull upstream artifacts via dawidd6/action-download-artifact
  2. GPG sign (debsigs / rpmsign)
  3. Build APT index (reprepro) — Filename rewritten to point at Releases
  4. Build YUM index (createrepo_c --baseurl)
  5. Push gh-pages branch (metadata, ~few MB)
  6. Upload binaries to GitHub Releases (per-tag, no size cap)
              ↓
end users
  └─ apt install libflagcx-nvidia python3-flagtree-nvidia ...
```

Why two GitHub-native targets? Pages hosts the metadata (Packages.gz,
Release, repodata) and serves it on a stable HTTPS URL; Releases hosts
the binaries (each up to 2 GB, total unlimited) on per-tag URLs that
the metadata's `Filename` field references. APT and DNF handle the
metadata-here / binaries-there split natively.

## Repo layout

```
flagos-packaging/
├── components/         # YAML manifests, one per upstream component
├── config/             # GPG public key, reprepro distributions, YUM .repo template
├── scripts/            # collect / sign / index / publish shell scripts
├── docs/               # user install guides (中英) + maintainer docs
├── tests/              # end-to-end install validation
├── .github/workflows/  # publish.yml, refresh-metadata.yml, test-install.yml
└── README.md, README_cn.md, LICENSE, .gitignore
```

## Status

W1 work-in-progress. See `docs/release-process.md` for the publishing
flow once it's wired up.

## License

Apache 2.0 (planned). LICENSE file pending.
