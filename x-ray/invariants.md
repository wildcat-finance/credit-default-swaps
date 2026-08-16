# Invariants

## Enforced properties

- `STATUS` always returns `research-scaffold`.
- `V2_PROTOCOL_COMMIT` always returns the first 20 bytes of
  `c7be4039f8f383a9dda4e45f63331c17d63f9ed9`.
- No call can change either value because the contract has no storage write or mutating entry point.

## Specification properties deferred to Step 2

The collateral, receipt supply, wrapper-share partition and terminal-state properties in
`docs/research-report.md` are not properties of `Scaffold`. They become executable claims only when
the facility contracts and their handler suite arrive.
