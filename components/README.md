# components/

Each YAML file declares one upstream component that ships packages.
The publish workflow loads every `*.yml` here, fans out via `matrix:`
to pull artifacts in parallel, then signs and indexes them.

## Schema

```yaml
name: <slug used in URLs and logs>      # required, [a-z0-9-]+
upstream: <github org/repo>             # required, e.g. "flagos-ai/FlagCX"
display_name: <human-readable>          # optional
workflows:
  deb:                                  # optional; omit to skip DEB
    name: <workflow filename>           # required, e.g. "build-deb.yml"
    artifact_pattern: <glob>            # required, e.g. "flagcx-*-packages"
  rpm:                                  # optional; omit to skip RPM
    name: <workflow filename>
    artifact_pattern: <glob>
notes: |                                # optional, free-form
  Anything reviewers should know about this component
```

## Adding a new component

1. Confirm the upstream repo has `build-deb.yml` and/or `build-rpm.yml`
   that uploads artifacts named per the manifest's `artifact_pattern`.
2. Create `<slug>.yml` here with the schema above.
3. Open a PR against this repo. The publish workflow picks up the new
   component automatically; no other code changes are needed.
