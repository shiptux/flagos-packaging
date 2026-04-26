# Adding a new component to flagos-packaging

This is the maintainer's guide for hooking a new upstream FlagOS
component into the central publish pipeline. End users don't read this.

## Pre-flight checks on the upstream repo

The upstream repo must already:

1. **Have its own `packaging/` directory** with `debian/` and/or `rpm/`
   subtrees (control, rules, spec, etc.). The packaging configs live
   *with the source* — flagos-packaging is publishing-only, never
   packaging-config.
2. **Have a build workflow** (`build-deb.yml` / `build-rpm.yml`) that
   triggers on push and uploads artifacts via `actions/upload-artifact`
   under predictable names.
3. **Use a stable artifact name pattern** so the publish workflow's
   matrix can match it. We recommend `<component>-<backend>-packages`
   for DEBs and `<component>-<backend>-rpm-packages` for RPMs.

If any of these are missing, fix them in the upstream repo first.

## Steps in this repo

1. **Add `components/<slug>.yml`**:

   ```yaml
   name: <slug>
   upstream: <github-org>/<repo>
   display_name: <human-readable name>
   workflows:
     deb:
       name: build-deb.yml
       artifact_pattern: "<slug>-*-packages"
     rpm:
       name: build-rpm.yml
       artifact_pattern: "<slug>-*-rpm-packages"
   notes: |
     Anything reviewers should know about this component
   ```

   Omit the `deb:` or `rpm:` block if the component doesn't ship that
   format yet.

2. **Run the local validation** to confirm the new packages flow
   through the pipeline cleanly:

   ```sh
   bash tests/local-validate.sh
   ```

   Look for the new package names in the `apt-cache search` output
   inside the test container.

3. **Open a PR** against this repo. The publish workflow picks up the
   new YAML automatically via `scripts/collect-artifacts.sh
   --emit-matrix`; no other code changes are needed.

4. **First publish run** after merge: trigger `publish.yml` manually
   with `gh workflow run publish.yml`. Check that the artifacts land
   in the expected GitHub Release and that `https://<org>.github.io/
   flagos-packaging/apt/dists/stable/main/binary-amd64/Packages.gz`
   contains entries for the new packages.

## Removing a component

Delete `components/<slug>.yml`. The next `publish.yml` run will skip
it. The packages remain available in any prior GitHub Release until
those releases are deleted manually — there's no auto-purge.

## When to add packaging-side code (rare)

If a new component needs a non-standard signing or indexing step (e.g.
a different RPM digest, a separate distribution suite), modify
`scripts/build-{apt,yum}-repo.sh`. Try hard to keep components
declarative-only first; per-component code paths are a maintenance
tax.
