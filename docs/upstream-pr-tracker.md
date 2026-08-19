# Upstream PR tracker

Status of the 13 sandbox-packaging branches across upstream FlagOS
repos. Snapshot regenerated each week; numbers are cumulative since
the packaging effort began.

Last refresh: 2026-06-06.

## Submission queue

| # | Repo | Branch | PR | State | Next action |
|---|------|--------|----|-------|-------------|
| 1 | flagos-ai/FlagSparse    | pr/packaging            | [#12](https://github.com/flagos-ai/FlagSparse/pull/12)     | MERGED          | — |
| 2 | flagos-ai/FlagAttention | pr/packaging            | [#31](https://github.com/flagos-ai/FlagAttention/pull/31)  | MERGED          | — |
| 3 | flagos-ai/flagtree      | pr/packaging            | [#607](https://github.com/flagos-ai/FlagTree/pull/607)     | MERGED          | — |
| 4 | flagos-ai/FlagDNN       | pr/packaging            | [#1](https://github.com/flagos-ai/FlagDNN/pull/1)          | OPEN, no review | request review |
| 5 | flagos-ai/FlagBLAS      | pr/packaging            | [#1](https://github.com/flagos-ai/FlagBLAS/pull/1)         | OPEN, no review | request review (`test-nvidia/test` failure pre-existing, unrelated to packaging) |
| 6 | flagos-ai/FlagGems      | pr/packaging            | [#3418](https://github.com/flagos-ai/FlagGems/pull/3418)   | OPEN, no review | request review (body uses upstream PR template) |
| 7 | flagos-ai/FlagAudio     | pr/packaging            | [#2](https://github.com/flagos-ai/FlagAudio/pull/2)        | OPEN, no review | ask maintainer to approve first-time-contributor CI |
| 8 | flagos-ai/FlagTensor    | pr/packaging            | [#4](https://github.com/flagos-ai/FlagTensor/pull/4)       | OPEN, no review | ask maintainer to approve first-time-contributor CI |
| 9 | flagos-ai/FlagQuantum   | pr/packaging            | [#4](https://github.com/flagos-ai/FlagQuantum/pull/4)      | OPEN, no review | ask maintainer to approve first-time-contributor CI |
| 10 | flagos-ai/FlagScale    | pr/packaging            | [#1205](https://github.com/flagos-ai/FlagScale/pull/1205)  | OPEN, no review | body adapted to upstream PR template; `format` / `run_tests` failures are pre-existing |
| 11 | flagos-ai/FlagCX       | pr/rpm-packaging-clean  | [#476](https://github.com/flagos-ai/FlagCX/pull/476)       | **MERGED** 2026-06-22 | squash-merged (branch commits not in main's ancestry, content is); RPM packaging is on main |
| 12 | flagos-ai/libtriton_jit | pr/packaging           | [#24](https://github.com/flagos-ai/libtriton_jit/pull/24)  | OPEN, CLA only  | base `multi-backend`; now targets ubuntu22.04/cu128. Nexus upload caller is [#28](https://github.com/flagos-ai/libtriton_jit/pull/28) |
| 13 | flagos-ai/FlagFFT      | pr/packaging            | [#12](https://github.com/flagos-ai/FlagFFT/pull/12)        | OPEN, no review  | single-backend (NVIDIA) only; bundles libtriton_jit submodule statically; packaging configs only — build-deb/rpm CI workflow is a follow-up |
| 14 | flagos-ai/FlagSparse    | pr/openeuler-rpm        | [#29](https://github.com/flagos-ai/FlagSparse/pull/29)     | **MERGED** 2026-07-15 | openEuler 24.03 RPM matrix in main — upstream now produces oe2403 artifacts; follow-up `--prefix /usr` in [#36](https://github.com/flagos-ai/FlagSparse/pull/36) |
| 15 | flagos-ai/FlagAttention | pr/openeuler-rpm        | [#35](https://github.com/flagos-ai/FlagAttention/pull/35)  | OPEN, review in progress | openEuler 24.03 RPM matrix; F7/F8 fixes; huangyiqun's `--prefix /usr` feedback addressed in 2b3651f, all checks green again — awaiting re-review |
| 16 | flagos-ai/flagtree      | pr/packaging-openeuler  | [#794](https://github.com/flagos-ai/FlagTree/pull/794)     | OPEN, **APPROVED** (zhzhcookie) | RESTORES #607 packaging (lost in main history rewrite) + openEuler 24.03 cp311; all 18 checks green; **next: ask maintainer to merge** |
| 17 | flagos-ai/FlagCX       | pr/openeuler-rpm        | [#549](https://github.com/flagos-ai/FlagCX/pull/549)       | OPEN, no review | openEuler 24.03 NVIDIA RPM matrix (same template as FlagSparse#29); built+verified on A100 with NCCL 2.31 (unpinned, tracks current releases); incl. spec changelog-order + comment-macro fixes |

## CI snapshot — build-deb / build-rpm

For OPEN PRs only. Source: `gh pr checks` against each PR, 2026-06-06.

| Repo | PR | build-deb | build-rpm | Other notable checks |
|------|----|-----------|-----------|----------------------|
| FlagDNN     | #1    | pass            | pass            | — |
| FlagBLAS    | #1    | pass            | pass            | `test-nvidia/test` fail (unrelated, pre-existing) |
| FlagGems    | #3418 | pass            | pass            | `code-style` pass; backend-* skipped; `preprocess` / `python-op` / `triage` pass |
| FlagAudio   | #2    | not triggered   | not triggered   | first-time-contributor — no workflow runs at all |
| FlagTensor  | #4    | not triggered   | not triggered   | same |
| FlagQuantum | #4    | not triggered   | not triggered   | same |
| FlagScale   | #1205 | not surfaced    | not surfaced    | `format` fail; `run_tests / *` mostly skipped or fail (pre-existing) |
| FlagCX      | #476  | n/a (RPM PR)    | nvidia / metax fail, ascend pass | `perf-test` fail (pre-existing); unittest-* / torch-api-test all pass |
| libtriton_jit | #24 | not triggered  | not triggered   | only `license/cla` pass; needs maintainer to dispatch |

## Earlier FlagCX PRs (predate the current packaging round)

| PR | Title | Branch | Opened | Last activity | State |
|----|-------|--------|--------|---------------|-------|
| [#393](https://github.com/flagos-ai/FlagCX/pull/393) | [CICD] add Ascend NPU backend support for Debian packages | pr/ascend-deb | 2026-02-26 | 2026-05-07 | OPEN, ~3 months idle |
| [#394](https://github.com/flagos-ai/FlagCX/pull/394) | [CICD] add RPM packaging support for RHEL/Rocky/OpenEuler | pr/rpm-packaging | 2026-02-26 | 2026-05-07 | OPEN, replaced by #476 — close once #476 lands |

## Per-row legend

- **State**: `not submitted` → `OPEN, no review` → `OPEN, review requested` → `OPEN, changes requested` → `MERGED` or `closed-without-merge`.
- **Next action**: the single thing that moves the row to its next
  state. "request review" = ping a maintainer; "approve first-time
  contributor CI" = a maintainer needs to click the "Approve and run
  workflows" button on the PR before any workflow will trigger.
- **CI snapshot columns**: `pass` / `fail` / `not triggered` /
  `not surfaced`. "Not triggered" means GitHub did not start any
  workflow run for the PR (typically first-time-contributor policy).
  "Not surfaced" means `gh pr checks` didn't return that workflow
  for that PR — usually because the workflow file uses a different
  trigger filter than the others.

## Per-repo PR body templates

Each row above has a corresponding body template at
`per-repo-pr-bodies/<repo>.md`. Copy that markdown into the GitHub
PR body field (or pass via `--body-file` if using `command gh pr create`).

Four upstream repos prescribe a specific PR template structure;
their body files follow it. The other seven repos have no upstream
template, so the body file uses our generic
Summary/Changed/Tested/Distribution/Limitations layout.

| Repo | Upstream PR template? | Required title format |
|------|----------------------|-----------------------|
| flagos-ai/FlagScale  | yes — PR Category / PR Types / PR Description       | none prescribed; we use `[CICD] …` |
| flagos-ai/FlagGems   | yes — Category / Type / Description / Issue / Progress | none prescribed; we use `[CI/CD] …` |
| flagos-ai/flagtree   | title only — `[<component>] brief description`      | **must** start with `[<component>]` (we use `[BUILD]`) |
| flagos-ai/FlagCX     | yes — PR Category / PR Types / PR Description       | none prescribed; we use `[CICD] …` |
| (other 7 repos)      | none                                                | generic `[packaging] …` |

## Suggested submission flow (per row)

```sh
# Fork the upstream onto the user's account.
# Skip if the fork already exists.
command gh repo fork <upstream-org>/<Repo> --clone=false

# In the local clone, add the user's fork as a separate remote
cd /home/shiptux/git/github/<Repo>
git remote add fork git@github.com:shiptux/<Repo>.git
git push fork pr/packaging

# Open the PR (web UI or CLI)
command gh pr create \
    --repo <upstream-org>/<Repo> \
    --base main \
    --head shiptux:pr/packaging \
    --title "[packaging] Add Debian + RPM packaging" \
    --body-file docs/per-repo-pr-bodies/<repo>.md
```

The batch script `~/git/github/submit-flagos-packaging-prs.sh` opens
the remaining unsubmitted rows in one pass; titles per repo come from
its task table (so flagtree's `[BUILD]` prefix is applied
automatically).

Upstream org is `flagos-ai` for all 13 repos. Repo name on the
FlagTree row is lowercase `flagtree` (one casing quirk).

## How to update this tracker

After opening a PR:

1. Replace `—` in **PR** with the actual PR link
2. Change **State** to `OPEN, no review`
3. Update **Next action** with the concrete next step
4. Refresh the **CI snapshot** row for that PR

Weekly maintenance: re-run `gh pr checks` on every OPEN row, refresh
the CI snapshot table, and move stalled PRs (>1 month with no
activity) to a `stalled-pr-notes.md` companion doc if the note grows.
