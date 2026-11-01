# Architecture decision records

One file per decision, numbered, never renumbered. A decision that changes an earlier one is a new ADR that says
which one it replaces, and the old one's status becomes "replaced by NNNN".

| ADR | Decision | Status |
|---|---|---|
| [0001](0001-monorepo-and-app-kit.md) | One monorepo, and the app kit every studio app is built on | accepted |

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
