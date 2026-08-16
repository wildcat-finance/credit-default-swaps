# Audit log

## Step 2, round 1 -- 2026-08-16

Suite: `hexaemeron:x-ray`, `hexaemeron:solidity-auditor`, `hexaemeron:fizz`.

| id | severity | file | finding | status |
| --- | --- | --- | --- | --- |
| S2-R1-01 | medium | `src/CoveredCDSFacility.sol` | Per-call floor rounding let many small default claims receive par while assigning less debt recovery than one claim for the same total amount. | fixed in `e226d13`; recovery allocation now uses the cumulative payout against a default-time supply and share snapshot |
| S2-R1-02 | low | `src/CoveredCDSFacility.sol`, `src/libraries/ExactTransfer.sol` | Exact checks on normalized Wildcat balances could reject valid transfers after the market scale factor moved away from one. | fixed in `e226d13`; the facility measures pulled scaled debt and requires the wrapper to mint that exact share amount |
| S2-R1-03 | low | `src/CoveredCDSFacility.sol` | Activation trusted constructor accounting without checking that the protection asset remained present. | fixed in `e226d13`; activation checks actual collateral before taking premium or debt |
| S2-R1-04 | medium | `src/CoveredCDSFactory.sol` | A tenor shorter than grace plus 90 days could never reach the stated default trigger from a clean activation. | fixed in `e226d13`; the factory rejects an insufficient tenor |
| S2-R1-05 | informational | `src/CoveredCDSFacility.sol` | Permanent debt custody made a protected position harder to return to the raw Wildcat market than the product needed. | fixed in `e226d13`; holders can burn live receipts to recover debt while matching seller collateral is released |

Leads not pursued: a late checkpoint cannot reconstruct a threshold crossed and cured before expiry.
The contract and product documents disclose this stock-V2 observation limit and require a keeper to
record default no later than expiry. Exact monotonic cumulative delinquency needs a market change or an
oracle, so it remains outside this prototype.

Evidence:

- `forge fmt --check`
- `forge build`
- `forge test`: 23 tests passed after fixes
- stateful campaigns: 256 runs and 128,000 calls per invariant, with no failure or handler revert
- split-claim regression uses wrapper shares below notional and compares cumulative recovery allocation
- `audit/X-RAY.md`
- `audit/FIZZ.md`
