# Operations checklists

## Before creating a facility

- [ ] Confirm the market is registered and the wrapper is canonical at the pinned V2 deployment.
- [ ] Confirm the base asset has exact ERC-20 transfer behaviour.
- [ ] Choose notional, fixed expiry tenor, annual spread and recovery beneficiary.
- [ ] Decide whether to leave collateral idle or bind an immutable ERC-4626 vault.
- [ ] If using a vault, review its asset, loss model, withdrawal limits and share-transfer behaviour.
- [ ] Fund and approve the full notional.
- [ ] Arrange checkpoint monitoring through expiry.

## Before buying cover

- [ ] Read facility immutables and verify the expected market, wrapper, asset and expiry.
- [ ] Verify the current market delinquency accumulator is zero.
- [ ] Check available cover and quote `premium(amount)` close to execution.
- [ ] Hold and approve the required canonical wrapper shares and premium asset.
- [ ] Remember that the receipt replaces the tendered wrapper position.
- [ ] Record the claim deadline and set monitoring.

## While the facility is live

- [ ] Monitor market delinquency and expiry.
- [ ] Treat receipt transfers as transfers of both debt and protection.
- [ ] If allocating unused capacity, keep facility cash at or above receipt supply.
- [ ] Test prospective vault withdrawal before relying on new fill capacity.
- [ ] Do not describe vault accounting value as cash collateral.

## Default path

- [ ] Call `checkpoint()` as soon as the threshold is met and no later than expiry.
- [ ] Verify the irreversible `DefaultRecorded` event and claim deadline.
- [ ] Holders burn receipts with `claim` before the deadline.
- [ ] Reconcile cash payouts and cumulative recovery shares.
- [ ] Recovery beneficiary withdraws assigned wrapper shares separately.
- [ ] After the window, seller releases unclaimed collateral and residual vault shares.

## Healthy path

- [ ] Call `checkpoint()` at or after expiry.
- [ ] Verify `Matured`.
- [ ] Seller calls `releaseCollateral`; vault shares arrive in kind.
- [ ] Holders call `redeemDebt` for wrapper shares.
- [ ] Confirm receipt supply and holder-share balance reach zero after final redemption.

## Live unprotection

- [ ] Quote the wrapper shares returned for the burn amount.
- [ ] Tell the holder that premium is not refunded.
- [ ] Burn with `unprotect` and verify wrapper shares reach the chosen receiver.
- [ ] Confirm equal collateral reaches the seller.
- [ ] Treat that capacity as permanently retired.
