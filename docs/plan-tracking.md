# Handling plan drift

This project ships in weekly increments. Drift between plan and reality
is normal — the question is how to respond when it happens. This note
records the working model.

## Three principles

### 1. Decompose milestones into shippable increments

A milestone like "users can `apt install` everything" is too coarse —
if any one component falls behind, the whole milestone slips. Break
it down so each increment is independently shippable:

- W1.0 publish pipeline scaffolded *(local validation passes)*
- W1.1 publish pipeline live with FlagCX only
- W1.2 + FlagScale
- W1.3 + FlagTree-nvidia
- W1.4 + FlagGems
- ...

Each increment ships a real artifact users can install. Slipping any
one increment doesn't block the others.

### 2. Honest weekly status — planned vs actual, with reasons

Every Sunday, write a short note:

```
Week ending YYYY-MM-DD
======================
Planned this week:
  - <item>           [DONE | SLIP | DROP]   [reason in 1 sentence]
  - <item>           [DONE | SLIP | DROP]   [reason]

Unexpected wins:
  - <item not in plan>

Plan for next week:
  - ...
```

Reasons matter more than counts: "slipped because MUSA toolkit isn't
on the H20 runner" is actionable; "behind schedule" is not.

### 3. Time-box exploration; defer with intent

Some work has unknown duration (a vendor SDK that may or may not
build under our pipeline; a kernel that may need debugger access).
Give those a hard limit before starting:

- "Try FlagTree-mthreads packaging — 2 working days."
- If it lands, great.
- If it doesn't, write down what blocked it, defer to a future week
  with a precondition ("when MUSA toolkit installer is available
  outside Harbor"), and move on.

The cost of deferring with intent is low; the cost of dragging
on indefinitely on uncertain work is high (it crowds out the high-
confidence items).

## When to renegotiate the bigger plan

Renegotiate (move dates, drop scope) when:

- A core technical assumption proved wrong (e.g., distro LLVM
  unusable for FlagTree)
- A required dependency is unavailable (vendor SDK, signing key)
- Downstream stakeholders need a different shape of artifact

Don't renegotiate over normal week-to-week variance — that's what the
weekly status note absorbs. The bigger plan should change rarely; the
weekly note changes always.

## Current snapshot (2026-04-26)

```
Week ending 2026-05-03
======================
Planned this week (W1):
  - flagos-packaging P1 bootstrap     DONE       (e71980c-style stub
                                                  ready locally; not
                                                  pushed yet)
  - flagos-packaging P2 scripts       DONE       (6 scripts + workflow)
  - flagos-packaging P3 local valid.  DONE       (apt install works
                                                  end-to-end against
                                                  signed local repo)
  - FlagTree spike review             DONE       (36 min build, 84 MB
                                                  .deb verified)
  - FlagScale PR submission           SLIP       (packaging committed
                                                  to pr/packaging today;
                                                  push-to-fork pending)
  - FlagCX #393 buildx removal        DONE       (commit 345a7aa)
  - MT SDK runner availability        SLIP       (need SSH to H20)

Unexpected wins:
  - FlagTree-nvidia DEB packaging        +2 packages
  - libtriton-jit catalogued in matrix   +2 packages
  - Local validation pipeline writeup

Cumulative: 12/40 packages reachable via the local pipeline.

Plan for week W2 (2026-04-27 → 2026-05-03):
  W2.1  Push flagos-packaging to a remote, run publish.yml live
        on FlagCX-only artifacts (smallest blast radius)
  W2.2  + FlagScale and FlagTree to the live pipeline
  W2.3  FlagTree RPM build (mirror nvidia DEB)
  W2.4  FlagGems packaging (Python path; reuse FlagScale template)
  W2.5  MT SDK availability check on H20 (time-boxed: 1 day)
        If reachable: start FlagTree-mthreads packaging
        If not: defer with precondition

  Stretch: FlagAttention packaging (Python path)
```

## Risks worth watching

- 7 FlagTree backends each need a vendor SDK in the build container.
  Each one is high uncertainty. Don't promise more than 1 backend per
  week.
- GitHub Pages serves metadata, but `.gz` content-type / cache
  headers occasionally surprise APT. First live publish.yml run will
  reveal any issue.
- Build minutes on a public repo are unlimited, but fan-out per
  push.yml run is on the order of (components × 2 formats) downloads.
  For 16 components × 2 = 32 jobs, well within free-tier concurrency.
