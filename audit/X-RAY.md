# Step 2 X-ray

## Scope

The Step 2 diff replaces the scaffold with an ownerless factory, an immutable one-fill facility,
narrow Wildcat interfaces, exact base-asset transfer helpers, full-precision premium math, mocks,
unit tests, fuzz tests and a stateful invariant handler.

The facility is a funded physical-settlement credit derivative. Its protected-debt receipt carries a
fixed par payout and beneficial ownership of escrowed Wildcat debt. It is not a freely separable cash
CDS. Before default, a holder can burn the receipt to recover the corresponding wrapped debt; doing so
releases the same amount of seller collateral and destroys the cover.

## Trust and value flow

The factory trusts two immutable deployment bindings: the Wildcat ArchController and canonical wrapper
factory. It accepts only a registered market, that market's recorded wrapper, a nonzero delinquency fee
and a tenor long enough to observe grace plus 90 days. It has no owner, fee switch, upgrade or arbitrary
call path.

The seller funds par collateral at creation. One lender activates the offer by paying the prepaid
ACT/365 premium and tendering the complete debt notional. The facility deposits that debt into the
canonical wrapper and mints the same normalized amount of protected-debt receipts.

At default, receipt burns pay par and allocate the default-time proportional wrapper-share entitlement
to seller recovery. At healthy maturity, receipt burns return wrapper shares and the seller recovers
collateral. After the default claim window, unclaimed receipts recover debt rather than par and unused
collateral returns to the seller.

## Attack surfaces

### Accounting boundaries

The most sensitive boundary is between normalized market debt, scaled Wildcat balances and wrapper
shares. Wildcat transfer arguments are normalized, while its internal balances and wrapper shares are
scaled. Activation therefore measures the facility's scaled-balance increase and requires wrapper
shares received to match it. Base collateral and premium remain subject to exact debit and credit
checks because fee-on-transfer or rebasing payout assets would break par settlement.

Default recovery uses cumulative allocation. Calculating a fresh floor against the shrinking supply
would let claim splitting change how much recovery debt a claimant surrenders. The fixed tree snapshots
supply and shares when default is recorded, then advances a cumulative recovery target with each cash
payout.

### Time and state

Activation refuses a market with current delinquency. `checkpoint()` asks the market to update state,
then records default when `timeDelinquent` is at least grace plus 90 days at or before expiry. A call
after expiry records healthy maturity instead. Default and maturity are permanent.

Wildcat's timer decays during cure and is not a lifetime high-water mark. If nobody records a visible
threshold before expiry and the timer later decays, the facility cannot prove the earlier state. This
is an operational keeper dependency, not data the facility can reconstruct.

### External calls

Creation pulls the protection asset only after deploying the facility; factory reentrancy is locked
across the operation. Facility activation, checkpointing, settlement, unprotection and withdrawals are
non-reentrant. State changes precede payout calls and a failed transfer reverts the complete operation.
Seller recovery shares are first assigned internally, so a seller-side wrapper transfer failure cannot
block a holder's cash claim.

The base asset, Wildcat market and canonical wrapper remain external dependencies. Token sanctions,
market transfer hooks, wrapper caps and market pauses can stop activation or debt delivery. They cannot
make a successful exact base-asset payout smaller than the amount recorded.

## Invariants

1. Payouts, live collateral and collateral already released always sum to original notional.
2. Facility base-asset balance equals live collateral for supported exact-transfer assets.
3. Wrapper shares held by the facility equal holder shares plus currently withdrawable seller recovery.
4. Receipt supply equals the sum of holder balances and never exceeds original notional.
5. During `Active`, receipt supply equals remaining collateral.
6. Default recovery allocation never exceeds the default-time holder-share snapshot.
7. A full set of default claims assigns every default-time holder share to seller recovery.
8. No receipt can be minted after activation.
9. Default, maturity and cancellation cannot reverse.
10. Live unprotection burns both the debt entitlement and the cover entitlement for the same receipt amount.

## Test posture

The unit suite exercises factory binding, hostile base assets, activation atomicity, premium rounding,
delinquency boundaries, cure, expiry ordering, receipt transfer, claims, maturity, cancellation,
reentrancy, unprotection and recovery withdrawal. The split-claim regression uses a 3:5 scaled-share
ratio, matching the direction of a real interest-accrued Wildcat wrapper.

The stateful handler varies time, delinquency, transfers, claims, redemptions, unprotection, collateral
release and recovery withdrawal. Its assertions cover collateral, receipt supply and wrapper-share
partitioning. A fork or deployed V2 integration test remains desirable before production deployment;
the pinned V2 source was used to verify interface selectors and scaled accounting for this prototype.

## Readiness

This is a prototype, not a production deployment recommendation. The remaining work is presentation,
operational documentation and a final release gate. Production work would also need a live V2
integration campaign, keeper deployment, sanctions-path decisions and external review.
