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
record default no later than expiry. An exact lifetime counter that never decreases needs a market change or an
oracle, so it remains outside this prototype.

Evidence:

- `forge fmt --check`
- `forge build`
- `forge test`: 23 tests passed after fixes
- stateful campaigns: 256 runs and 128,000 calls per invariant, with no failure or handler revert
- split-claim regression uses wrapper shares below notional and compares cumulative recovery allocation
- `audit/X-RAY.md`
- `audit/FIZZ.md`

## Step 2, round 2 -- 2026-08-16

| id | severity | file | finding | status |
| --- | --- | --- | --- | --- |
| S2-R2-01 | low | `docs/research-report.md`, `README.md` | The new live unprotection path contradicted the earlier collateral-release rule and was absent from the lifecycle description. | fixed in `42c2a43`; the report now states the burn, debt return, collateral release and non-refundable premium |

Leads not pursued: exact historical threshold reconstruction remains outside stock V2, as recorded in
round 1. The fixed contracts, selectors, lifecycle paths and accounting properties produced no new
code finding.

Evidence:

- `forge fmt --check`
- `forge build`
- `FOUNDRY_PROFILE=ci forge test`: 23 passed, 0 failed, 0 skipped
- two fuzz properties at 1,000 runs each
- three invariant properties at 256 runs and 32,768 calls each, with no handler revert

## Step 2, round 3 -- 2026-08-16

| id | severity | file | finding | status |
| --- | --- | --- | --- | --- |
| -- | -- | -- | No findings. | clean |

Leads not pursued: the disclosed stock-V2 historical observation limit only.

The X-ray model, contract review and refreshed Fizz-compatible Foundry campaign were repeated after
the documentation fix. Contract behaviour, documentation and the accounting properties agree.

Evidence:

- `forge fmt --check`
- `forge build`
- `FOUNDRY_PROFILE=ci forge test`: 23 passed, 0 failed, 0 skipped
- two fuzz properties at 1,000 runs each
- three invariant properties at 256 runs and 32,768 calls each, with no handler revert
- `script/check-markdown.sh`

## Step 3, round 1 -- 2026-08-16

Suite review: `hexaemeron:x-ray`, `hexaemeron:solidity-auditor` and a refreshed
`hexaemeron:fizz`-compatible stateful Foundry campaign.

The twelve Solidity audit lenses produced 17 unique `(contract, function)` leads after mechanical
deduplication. Four were confirmed implementation defects, one was a confirmed product limitation,
and the remaining leads were rejected or retained as disclosed external assumptions.

| id | severity | file | finding | status |
| --- | --- | --- | --- | --- |
| S3-R1-01 | medium | `src/CoveredCDSFacility.sol` | A positive fill could sit on a cumulative share-target plateau, minting additional cover without contributing new debt shares. | fixed; zero-increment fills now revert and a coarse-share regression covers the boundary |
| S3-R1-02 | medium | `src/CoveredCDSFacility.sol` | A small partial default claim could round recovery down to zero, pay cash and leave all debt for later redemption. | fixed; non-final cumulative recovery rounds up against the claimant and a low-share regression covers the split |
| S3-R1-03 | medium | `src/CoveredCDSFacility.sol` | Vault appreciation or rounding could leave shares after `remainingCollateral` reached zero, while the terminal release rejected a zero accounting amount. | fixed; release now considers actual cash and vault-share balances and a yield regression proves cleanup |
| S3-R1-04 | medium | `src/CoveredCDSFactory.sol`, `src/CoveredCDSFacility.sol` | A facility could be created for, or accept a later fill from, an already closed Wildcat market even though its default path was no longer meaningful. | fixed; refreshed closed state is rejected at creation and entry |
| S3-R1-05 | medium | `src/CoveredCDSFacility.sol` | A fill made with less than grace plus 90 days remaining cannot reach the credit-event threshold from the required zero-delinquency entry state before expiry. | accepted for the prototype; continuous entry until expiry is an explicit product choice and the horizon is now disclosed |

Leads not pursued: permissionless allocation matches issue #10 and cannot move cash backing existing
receipts; stock V2 cannot reconstruct a threshold that crossed and cured without a timely checkpoint;
token sanctions, persistent market-update failure, negative rebase and arbitrary vault quality remain
documented dependency risks. Seller-side share-transfer failure may delay collateral release but does
not block holder debt redemption or default cash claims. Directly deployed facility lookalikes have no
factory provenance, so integrations must use factory events or registry state.

Evidence:

- `audit/X-RAY.md`
- `audit/FIZZ.md`
- 36 Foundry tests, including directed regressions for all four fixed defects
- five stateful accounting properties at 128,000 calls each under the default profile
- CI fuzz properties at 1,000 runs and stateful properties at 32,768 calls each
- `script/release-gate.sh`: passed, including dependency, Markdown, raster, arithmetic and size checks

## Step 3, round 2 -- 2026-08-16

| id | severity | file | finding | status |
| --- | --- | --- | --- | --- |
| -- | -- | -- | No findings. | clean |

The X-ray model, all four round-one fixes, adjacent state transitions and the refreshed stateful
campaign were reviewed again. Closed-market guards run after state refresh; every positive fill now
advances wrapper custody; cumulative claim rounding never decreases as `totalPayouts` rises and stays
capped by the default snapshot;
and terminal release cannot bypass the claim window or holder debt redemption.

Leads not pursued: the accepted late-entry horizon and stock-V2 historical observation limit remain
product terms. The seller-selected vault, exact-transfer assets and reference-market availability
remain explicit external assumptions rather than defects introduced by the fixes.

Evidence:

- `forge coverage --report summary`: 89.24% lines, 87.87% statements, 65.56% branches and 90.59% functions
- `src/CoveredCDSFacility.sol`: 92.23% line coverage
- `src/CoveredCDSFactory.sol`: 97.37% line coverage
- 36 Foundry tests passed
- five invariants completed 128,000 calls each with no failure or handler revert
- round-one release gate remained green on the fixed tree

## Step 3, supplemental horizon round -- 2026-08-16

The product decision made after round 2 replaces the accepted S3-R1-05 term. Primary issuance now
closes at `expiry - (market grace + 90 days)`, and the factory rejects a tenor which leaves no positive
entry period. This preserves the zero-delinquency entry guard while ensuring that a fresh uninterrupted
default can still reach the threshold for every admitted buyer.

| id | severity | file | finding | status |
| --- | --- | --- | --- | --- |
| -- | -- | -- | No finding in the revised deadline calculation, boundary ordering or adjacent settlement paths. | clean |

S3-R1-05 is superseded by this revision. Its earlier `accepted` status remains in round 1 as the
historical result at that commit.

Review points:

- Wildcat V2 declares `delinquencyGracePeriod` immutable, so a creation-time deadline cannot drift.
- Factory validation uses `tenor > grace + 90 days`, preventing constructor underflow and a zero-length entry period.
- A fill is valid at deadline equality and rejected one second later, before buyer assets move.
- At equality, `expiry - entryDeadline == defaultThreshold`; default still wins at expiry equality.
- `availableCover()` reports zero after entry closes, while allocation and terminal settlement remain unchanged.

Evidence:

- `script/release-gate.sh`: 38 tests passed under default and CI profiles
- two CI fuzz properties at 1,000 runs each
- five invariants at 128,000 default-profile calls and 32,768 CI calls, with no failure or handler revert
- `forge coverage --report summary`: 89.30% lines, 87.97% statements, 66.30% branches and 90.59% functions
- facility line coverage: 92.34%; factory line coverage: 97.37%
