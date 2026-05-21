# Upstream PR tracker

Status of the 11 sandbox-packaging branches awaiting submission to
upstream FlagOS repos, plus the 2 existing FlagCX PRs.

Update this file weekly until every row reaches `merged` or
`closed-without-merge`.

## Submission queue (to be opened by user)

Suggested order: simplest to most complex (build review confidence
on early PRs before tackling FlagTree / FlagCX RPM).

| # | Repo | Branch | Last branch commit | PR URL | State | Last review | Blocker |
|---|------|--------|---------------------|--------|-------|-------------|---------|
| 1 | flagos-ai/FlagSparse | pr/packaging | 2026-05-21 | [#12](https://github.com/flagos-ai/FlagSparse/pull/12) | OPEN, no review | — | — |
| 2 | flagos-ai/FlagAttention | pr/packaging | 2026-05-21 | — | not submitted | — | needs fork + user push |
| 3 | flagos-ai/FlagDNN | pr/packaging | 2026-05-21 | — | not submitted | — | needs fork + user push |
| 4 | flagos-ai/FlagBLAS | pr/packaging | 2026-05-21 | — | not submitted | — | needs fork + user push |
| 5 | flagos-ai/FlagAudio | pr/packaging | 2026-05-21 | — | not submitted | — | needs fork + user push |
| 6 | flagos-ai/FlagTensor | pr/packaging | 2026-05-21 | — | not submitted | — | needs fork + user push |
| 7 | flagos-ai/FlagQuantum | pr/packaging | 2026-05-21 | — | not submitted | — | needs fork + user push |
| 8 | flagos-ai/FlagScale | pr/packaging | 2026-04-26 | — | not submitted | — | needs fork + user push |
| 9 | flagos-ai/FlagGems | pr/packaging | 2026-05-21 | — | not submitted | — | needs fork + user push |
| 10 | flagos-ai/flagtree | pr/packaging | 2026-05-13 | — | not submitted | — | needs fork + user push (repo name is lowercase `flagtree`) |
| 11 | flagos-ai/FlagCX | pr/rpm-packaging-clean | 2026-05-21 | — | not submitted | — | rebase done (df2540b, ad5b46c, 79efcce; 3 commits / 5 files); user decides: force-push to update #394, or open new PR replacing #394 |

## Already-open PRs (FlagCX, follow-up only)

| PR | Title | Branch | Opened | Last activity | Reviews | State |
|----|-------|--------|--------|---------------|---------|-------|
| [#393](https://github.com/flagos-ai/FlagCX/pull/393) | [CICD] add Ascend NPU backend support for Debian packages | pr/ascend-deb | 2026-02-26 | 2026-05-07 | 0 | OPEN, ~3 months idle |
| [#394](https://github.com/flagos-ai/FlagCX/pull/394) | [CICD] add RPM packaging support for RHEL/Rocky/OpenEuler | pr/rpm-packaging | 2026-02-26 | 2026-05-07 | 0 | OPEN, ~3 months idle |

## Per-row legend

- **State**: `not submitted` → `OPEN, no review` → `OPEN, review requested` → `OPEN, changes requested` → `merged` or `closed-without-merge`
- **Blocker**: what's blocking the row's next state transition. "needs fork + user push" = user must `gh repo fork` + `git push fork pr/packaging` before opening PR.

## Per-repo PR body templates

Each row above has a corresponding body template at
`per-repo-pr-bodies/<repo>.md`. Copy that markdown into the GitHub
PR body field (or pass via `--body-file` if using `command gh pr create`).

## Suggested submission flow (per row)

```sh
# 10 of 11 repos need a fork on the user's account first.
# Skip if the fork already exists (currently only shiptux/FlagCX does).
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

Upstream org is `flagos-ai` for all 11 repos. Repo name on the
FlagTree row is lowercase `flagtree` (one casing quirk).

## How to update this tracker

After opening a PR:

1. Replace `—` in **PR URL** with the actual PR link
2. Change **State** to `OPEN, no review`
3. Date in **Last review** stays `—` until a reviewer comments
4. Add anything notable to **Blocker** (e.g. "CLA not signed",
   "CI red", "waiting on maintainer @foo")

Weekly maintenance: skim the tracker, update **Last review** dates,
move stalled PRs to a `stalled-pr-notes.md` companion doc if the
note grows.
