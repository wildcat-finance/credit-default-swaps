# X-ray: scaffold branch

## Scope

Step 1 adds a research scaffold, not the CDS facility. The authored Solidity surface is nine lines in
`src/Scaffold.sol`: two compile-time constants and no mutable storage, payable function, token flow,
external call, role or permissionless state-changing entry point.

## Repository profile

- Foundry project, Solidity 0.8.28, Cancun, IR compilation and 200 optimiser runs.
- One source file and one test file at commit `a3c2494`.
- Pinned submodules: forge-std `8e40513` and Wildcat V2 `c7be403`.
- The git history is a two-commit new repository. Git-weighted history cannot yet reveal mature
  hotspots.

## Attack surface

There is no value-holding or state-changing contract in this step. The relevant risks are supply-chain
drift, a false dependency claim, CI divergence and research wording that promises behaviour not yet in
code. `script/check-dependencies.sh`, the imported `MarketState` type and the scaffold test address
those points.

## Trust and composition

`Scaffold` makes no external call. The repository compiles against the pinned Wildcat V2 source but
does not deploy or interact with it. The research report's factory, wrapper, market and collateral
flows are specification for Step 2 and must not be read as implemented behaviour.

## Verification

`forge coverage` compiled 26 files and passed 1/1 tests. It reported no executable statements in the
constant-only contract, which is expected. The x-ray enumeration script used GNU `grep -P`, which the
host BSD grep rejected; source and test counts were verified separately with portable scans.

## Audit focus for the next step

Step 2 must receive a fresh x-ray. The main targets are facility lifecycle monotonicity, exact token
balance deltas, canonical-wrapper validation, Wildcat delinquency observation, wrapper-share
partitioning, claim/maturity rounding and seller recovery isolation.
