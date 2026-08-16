# Validation evidence

This file records reproducible checks for the current prototype. It is not an external audit report.

## Toolchain

- Foundry v1.7.1
- Solidity 0.8.28, Cancun, IR compilation, 200 optimiser runs
- forge-std v1.11.0 at `8e40513d678f392f398620b3ef2b418648b33e89`
- Wildcat V2 at `c7be4039f8f383a9dda4e45f63331c17d63f9ed9`

## Test evidence

The implementation phase passed:

- 31 Foundry tests under the default profile;
- the same 31 tests under the CI profile;
- two fuzz tests at 1,000 runs under CI;
- five stateful invariants at 256 runs and 32,768 calls each under CI; and
- formatting, build-size, dependency, Markdown and diff hygiene checks.

The default invariant profile ran 128,000 calls per invariant. At the implementation checkpoint,
`CoveredCDSFacility` runtime bytecode was 10,893 bytes and `CoveredCDSFactory` was 15,042 bytes.

Coverage includes multiple lenders, staggered premium decay, split-fill share equivalence, exact
rounding, delinquent and expired entry, live unprotection, default partitioning, maturity, fee tokens,
vault allocation and restoration, loss, illiquidity, in-kind terminal release and reentrant callbacks.

## Stateful properties

1. Collateral accounting never creates notional.
2. Every successful open cover unit remains backed by facility cash.
3. Receipt supply agrees with tracked balances and permanently reduced capacity.
4. Wrapper shares remain partitioned between holders and recovery.
5. The cumulative share target survives arbitrary fills and unprotection.

## Reproduce

```sh
git submodule update --init --recursive
./script/release-gate.sh
```

The release gate checks dependency pins, Markdown hygiene, image dimensions and hashes, the worked
example, Foundry formatting, build sizes, the default suite and the CI suite.

## Review status

Earlier implementation stages have internal audit logs and stacked audit branches. Step 3 changes must
complete a fresh Fiat audit round before publication. Nothing in this repository should be described
as externally audited or production-ready.
