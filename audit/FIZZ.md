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

This campaign proves the listed accounting properties for the mock state machine. It does not replace
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
