# Step 2 invariant campaign

## Harness

`test/invariant/CoveredCDSInvariant.t.sol` deploys one fully funded and active facility with wrapper
shares below normalized debt. Its handler selects among:

- advancing time;
- changing observable delinquency;
- checkpointing default or maturity;
- transferring protected-debt receipts;
- unprotecting a live position;
- claiming par after default;
- redeeming debt after maturity or claim-window expiry;
- releasing seller collateral; and
- withdrawing seller recovery shares.

Calls that are invalid for the current lifecycle are caught by the handler. The completed campaign
reported no handler reverts, so random values were bounded into valid holder balances before each
holder action.

## Properties

- `totalPayouts + remainingCollateral + totalSellerReleased == notional`
- `asset.balanceOf(facility) == remainingCollateral`
- `wrapper.balanceOf(facility) == remainingHolderShares + sellerRecoveryShares`
- `totalSupply == balanceOf(lender) + balanceOf(alice)`
- `totalSupply <= notional`
- `totalRecoverySharesAllocated <= defaultHolderShares`

## Round 1 result

The implementation campaign passed before manual review, but its original share ratios were greater
than one. The Solidity audit then found that sub-unit share ratios exposed a claim-splitting error. The
harness and regression suite were refreshed to exercise a 3:5 scaled-share ratio and live
unprotection.

After `e226d13`:

- Foundry unit, fuzz and invariant suites: 23 passed, 0 failed, 0 skipped;
- invariant runs: 256;
- calls per invariant: 128,000;
- handler reverts: 0; and
- invariant failures: 0.

This campaign checks the listed accounting properties against the mock state machine. It does not replace
a deployed Wildcat V2 integration test or establish that the stock market timer preserves a missed
historical threshold.

## Round 2 result

The fixed tree and refreshed unprotection handler passed the CI campaign:

- unit, fuzz and invariant suites: 23 passed, 0 failed, 0 skipped;
- fuzz runs: 1,000 for each of two properties;
- invariant runs: 256;
- calls: 32,768 for each of three properties; and
- handler reverts: 0.

Manual review found one documentation mismatch for unprotection and no new contract or harness defect.

## Round 3 result

No Solidity changed after round 2. The CI campaign was repeated after the product documents were
corrected: 23 tests passed, including both 1,000-run fuzz properties and three 32,768-call stateful
properties. No accounting property failed and no handler call reverted.

# Step 3 invariant campaign

## Refresh

The existing stateful harness was refreshed for continuous issuance and the optional collateral vault.
It starts with two independent lenders, live cash cover and part of the unused capacity in the vault.
The handler can advance time, change observed delinquency, fill from either lender, allocate excess
cash, transfer receipts, unprotect, checkpoint, claim, redeem debt, release collateral and withdraw
recovery.

The campaign asserts five property families:

- collateral accounting never creates notional;
- open cover remains cash-backed;
- wrapper shares stay partitioned between holders and recovery;
- receipt supply agrees with holder balances and remaining capacity; and
- open holder shares remain at the cumulative ceiling target after fills and unprotection.

## Round 1 result

The default Foundry campaign completed 128,000 calls for each of five invariants. The CI campaign
completed 32,768 calls for each invariant and ran each fuzz property 1,000 times. No property failed
and the handler reported no revert.

The Solidity review still found boundary cases outside the original randomized shapes. Four directed
regressions were added for zero-share fills, discrete partial-claim recovery, closed markets and
terminal vault yield. This is a refreshed Foundry stateful campaign; no claim is made that the Fizz
generator produced a separate Medusa or Echidna harness for this round.

## Round 2 result

The fixed tree repeated the default stateful campaign during coverage collection. All 36 tests passed;
each of the five invariants completed 128,000 calls with no failed property or handler revert. Directed
regressions for the four round-one defects also passed. The second review found no new harness or
contract defect.

## Supplemental horizon result

The handler now stops fill attempts after the derived entry deadline, and the capacity property expects
`availableCover()` to be zero after that point. The default and CI campaigns passed on the revised
tree: 38 tests, two fuzz properties at 1,000 CI runs and five stateful properties at 32,768 CI calls
or 128,000 default-profile calls. No property failed and no handler call reverted.
