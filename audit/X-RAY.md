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

Creation pulls the protection asset only after deploying the facility; the factory's `_entered` lock
covers the operation. The facility uses the same lock for activation, checkpointing, settlement,
unprotection and withdrawals. State changes precede payout calls and a failed transfer reverts the complete operation.
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
callback re-entry, unprotection and recovery withdrawal. The split-claim regression uses a 3:5 scaled-share
ratio, matching the direction of a real interest-accrued Wildcat wrapper.

The stateful handler varies time, delinquency, transfers, claims, redemptions, unprotection, collateral
release and recovery withdrawal. Its assertions cover collateral, receipt supply and wrapper-share
partitioning. A fork or deployed V2 integration test remains desirable before production deployment;
the pinned V2 source was used to verify interface selectors and scaled accounting for this prototype.

## Readiness

This is a prototype, not a production deployment recommendation. The remaining work is presentation,
operational documentation and a final release gate. Production work would also need a live V2
integration campaign, keeper deployment, sanctions-path decisions and external review.

# Step 3 X-ray

## Scope

Step 3 changes the facility from one-shot activation to continuous primary issuance and adds an
optional ERC-4626 adapter for unused capacity. It also adds the product field kit, branded raster
assets, release checks and the design-history note. The reviewed implementation baseline was
`74b1a93`.

The factory fixes expiry when the seller creates the facility and snapshots the full-notional wrapper
share budget with `previewWithdraw(notional)`. Multiple lenders can enter through the market-specific
deadline at `expiry - (grace + 90 days)`. Each fill pays an ACT/365 premium for its own remaining term,
tenders the incremental canonical wrapper shares and receives the combined debt-and-cover receipt.

## Value and trust boundaries

The facility can hold base asset, canonical wrapper shares and shares in one immutable collateral
vault. Base asset equal to live receipt supply stays in cash. Only unused capacity may be allocated,
and a later fill restores exact cash before taking premium or debt from the buyer. Claims never depend
on a vault withdrawal. Terminal settlement transfers any residual vault shares in kind.

The ownerless factory trusts the pinned ArchController and wrapper factory. A facility trusts the
market state machine, the exact-transfer behaviour of its asset and wrapper, and the seller's chosen
vault. There is no upgrade, fee switch, oracle or rescue authority.

## Primary attack surfaces

- cumulative rounding across fills, unprotection and default claims;
- cash solvency while unused capacity enters and leaves the vault;
- expiry ordering and the stock-V2 checkpoint availability dependency;
- callbacks from the asset, wrapper, market and vault;
- market closure and changing delinquency between facility creation and later fills; and
- terminal cleanup of cash, wrapper shares and strategy residue.

The first audit pass found four implementation defects at those boundaries: a zero-share fill plateau,
floor-rounded partial recovery, missing closed-market guards and residual vault yield that could not be
released after accounting collateral reached zero. All four have regression tests on the audit branch.

## Invariants

1. `totalPayouts + remainingCollateral + totalSellerReleased == notional`.
2. Open cover has base-asset cash at least equal to receipt supply.
3. Wrapper shares equal holder shares plus unwithdrawn recovery shares.
4. Open-state holder shares equal the cumulative ceiling target for receipt supply.
5. Receipt supply never exceeds remaining collateral.
6. A successful positive fill contributes at least one new wrapper share.
7. Cumulative default recovery never allocates less debt than the claimant's rounded entitlement.
8. Default and maturity cannot reverse.
9. Failed vault restoration occurs before any buyer asset moves.
10. Terminal release can recover actual cash and vault shares even when accounting collateral is zero.
11. Every successful fill leaves at least `grace + 90 days` before expiry.

## Test posture

The implementation baseline had 31 Foundry tests and 88.51% line coverage. The first audit pass adds
five regression tests, taking the suite to 36 tests. The horizon revision adds two more, taking the
suite to 38. The stateful handler varies time, delinquency,
fills, allocation, transfers, unprotection, checkpointing, claims, debt redemption and both seller-side
withdrawal paths.

Mocks exercise the pinned interfaces but are not a deployed V2 integration. A production candidate
still needs a live-market campaign, adapter-specific vault review, keeper deployment, sanctions-path
decisions and independent review.
