# Spec: discovery-gap fixture

**Track:** feature
**Tier:** full
**Status:** signed-off

A minimal full-tier spec carrying the two WS-7 discovery fields, paired with `plan.md` to prove
BOTH actuations are mechanically detectable: a `## Success metrics` row `ff-verify` must turn into
a `### SM<n>` contract item, and a `## Requirement graph` AC-edge whose derived task dependency the
companion plan deliberately drops. The SEMANTIC catches (an unproven metric actually blocking
`done`, AC6; an un-derivable edge actually surfacing at the plan's Outcome gate, AC8) are a manual
fresh-session self-run named in the 0.17.0 CHANGELOG.

## Acceptance criteria

- [ ] AC1: When the loader starts, it reads `config.json`.
- [ ] AC2: When a request arrives, it is served from the loaded config.

## Success metrics

> **Full tier only.** A lite spec omits this section — no placeholder, no warning.

- [ ] SM1: p95 request latency ≤ 200ms, measured by `bench.sh`.

## Requirement graph

| AC | Depends on |
|----|------------|
| AC1 | — (root) |
| AC2 | AC1 |
