# Architecture

## Scope

The prototype creates immutable, fixed-expiry, fully collateralised protection for one registered
Wildcat V2 market. It has two contracts and no owner, upgrade proxy, price oracle, claims committee or
protocol fee.

## Contracts

### `CoveredCDSFactory`

The factory checks:

- the ArchController recognises the reference market;
- the supplied wrapper is the market's canonical wrapper;
- the wrapper asset is the reference market;
- the market base asset and optional ERC-4626 vault asset match;
- the market has a nonzero delinquency fee;
- the refreshed market is not closed;
- tenor exceeds grace plus 90 days and is no more than ten years; and
- notional, spread and the wrapper share budget are valid.

It calls `market.updateState()`, snapshots
`wrapper.previewWithdraw(notional)` as the full-notional share budget, deploys the facility and pulls
the complete notional from the seller. `previewWithdraw` rounds towards enough shares; a floor-rounded
`previewDeposit` could underfund small boundary amounts.

### `CoveredCDSFacility`

The facility is the ERC-20 protected-debt receipt and settlement contract. Its immutable terms are:

- market, canonical wrapper and base asset;
- optional collateral vault;
- seller and recovery beneficiary;
- maximum notional and full-notional wrapper share budget;
- creation-time tenor, expiry and claim deadline; and
- annual premium spread.

The lifecycle is `Offered`, `Active`, `Defaulted` or `Matured`. Supply can move between zero and
the permanently reduced collateral capacity before expiry. Default and maturity are terminal.

## Continuous issuance

`fill(coverAmount, receiver)` accepts available amounts through `entryDeadline`, calculated as
`expiry - (grace + 90 days)`. The facility first
updates the market and rejects entry if it is closed or `timeDelinquent != 0`. It then restores cash equal to the
prospective receipt supply before pulling either buyer asset.

For prospective supply `S`, initial notional `N` and reference share budget `B`, the share target is:

```text
target(0) = 0
target(N) = B
target(S) = ceil(B * S / N)
```

The buyer contributes `target(newSupply) - currentHolderShares`. This cumulative target makes
aggregate wrapper shares independent of fill splitting or order. The buyer pays the ceiling-rounded
ACT/365 premium for the exact seconds left and receives one receipt unit per normalized cover unit.
If the target increment is zero because wrapper shares are coarser than cover units, the fill rejects.
This prevents a buyer from using wrapper shares overcontributed by earlier fills, at the cost of a
market-dependent minimum fill granularity.

## Transfer and live exit

The receipt uses ordinary ERC-20 balances and allowances. Wrapper shares stay inside the facility, so
a receipt transfer moves beneficial ownership of the debt and protection together.

`unprotect(amount, receiver)` is available only while active. It burns receipts, returns the
corresponding share-target difference, releases the same cash amount to the seller and permanently
reduces `remainingCollateral`. There is no premium refund. A full burn returns the lifecycle to
`Offered`, but retired capacity does not reappear.

## Optional ERC-4626 strategy

`allocate(assets)` may deposit only:

```text
facility cash - receipt supply
```

into the immutable vault. This is unused offer capacity, not live claim reserves. A later fill calls
`_restoreCash(newSupply)`; exact vault withdrawal must succeed before the buyer pays premium or
contributes wrapper shares. Default claims use cash only.

After terminal settlement, `releaseCollateral` sends remaining cash and vault shares to the seller
in kind. It does not withdraw from the vault. Strategy loss may reduce the value of the seller's
residual or stop future fills, but successful fills remain cash-backed.

## Default

`checkpoint()` calls `market.updateState()`. While active and no later than expiry it records default
when:

```text
timeDelinquent >= delinquencyGracePeriod + 90 days
```

The facility snapshots receipt supply and holder wrapper shares. During the one-year claim window,
`claim(amount, receiver)` burns receipts, pays equal base asset and assigns the cumulative pro-rata
wrapper entitlement to seller recovery. Cumulative accounting prevents split claims from avoiding
recovery-share surrender. Partial claims round the cumulative recovery obligation up against the
claimant; the last claim receives all remaining shares.

Only the immutable recovery beneficiary can withdraw recovery shares. The claim does not attempt that
transfer, so a hostile or inaccessible recovery address cannot block the holder's cash payout.

## Healthy maturity and expired claims

At expiry, `checkpoint()` records maturity unless a qualifying default has priority at the same
timestamp. The seller may release collateral. Receipt holders burn through `redeemDebt` and receive
their pro-rata wrapper shares; the final burn receives rounding dust.

After a default claim window expires, unclaimed holders can also redeem debt rather than cash, and the
seller can release the remaining collateral. Missing the claim window therefore forfeits protection,
not the bundled debt.

## Accounting identities

Before terminal release:

```text
totalPayouts + remainingCollateral + totalSellerReleased = initialNotional
totalSupply <= remainingCollateral
facility cash >= totalSupply
holderShares + allocatedRecoveryShares = contributedWrapperShares
```

Vault assets are not counted as cash backing for outstanding cover. `remainingCollateral` is nominal
contract accounting; residual vault shares may be worth more or less than their deposited assets.
