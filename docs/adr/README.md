# Architecture decision records

One file per decision, numbered, never renumbered. A decision that changes an earlier one is a new ADR that says
which one it replaces, and the old one's status becomes "replaced by NNNN".

| ADR | Decision | Status |
|---|---|---|
| [0001](0001-monorepo-and-app-kit.md) | One monorepo, and the app kit every studio app is built on | accepted |
| [0002](0002-signing-path.md) | Agents build unsigned in the sandbox; only the store wrapper signs | accepted |
| [0003](0003-ios-asset-and-storyboard-compilers.md) | The iOS archive's icon and storyboards compile in CI (or the wrapper), never with CoreSimulator opened to the sandbox | accepted |
| [0004](0004-private-report-page.md) | Richard's private report page: snapshot at publish, pages bundled in a Worker, Access in front | proposed |
| [0005](0005-crash-reporting-and-the-rollout-watcher.md) | Crash reporting with Sentry (EU), and what the Release watch reads | accepted |
| [0006](0006-site-kit.md) | The site kit: static FR/EN sites built by a small Node builder, on Workers static assets | accepted |

## Template

```markdown
# ADR NNNN: <decision in a few words>

- Status: proposed | accepted | replaced by NNNN
- Date: YYYY-MM-DD
- Deciders: <roles>
- Issue: DAPP-<n>

## Context
What forces the decision, with dated facts where a platform rule or price matters.

## Decision
What we do, and the options we rejected with why.

## Consequences
What gets easier, what gets harder, what follows.
```
