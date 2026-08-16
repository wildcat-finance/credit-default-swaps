# Threat model

## Protected assets

- seller base-asset collateral;
- buyer premium before the fill completes;
- canonical wrapper shares behind receipts;
- holder rights to cash settlement or healthy debt redemption; and
- recovery shares assigned after default.

## Trusted facts

The factory trusts the configured Wildcat ArchController and wrapper factory to identify registered
markets and canonical wrappers. A facility trusts the reference market's `updateState()`,
`currentState()`, grace period and delinquency fee semantics. It trusts the base asset and wrapper to
behave as exact-transfer ERC-20s; transfers are checked by balance delta.

No administrator can change terms, record an offchain default or rescue assets.

## Main attack surfaces

### Toxic late entry

A lender may know more about the borrower than the seller. A fill rejects any current nonzero
`timeDelinquent`, not only the final credit-event threshold. This removes entry after the first
onchain arrears signal. Creation and entry also reject a closed market. These guards cannot price
private or offchain information.

Fills remain open until expiry. When less than grace plus 90 days remains, a buyer entering from zero
current delinquency cannot reach the credit-event threshold before expiry. The declining premium does
not remove that structural horizon. This is an explicit prototype term retained to match continuous
entry, not a claim that every late receipt can still default.

### Naked protection

The cover and debt are not separable. Buyers tender canonical wrapper shares and receive one receipt
for the combined position. Transfer and exercise operate on that receipt. Stock V2 balance checks
alone would not provide the same property.

### Fill splitting and rounding

Wrapper contributions use a cumulative full-notional ceiling target. Premium is rounded up for each
fill. A positive fill must advance the target by at least one wrapper share. Splitting a share
contribution cannot dilute incumbents or mint debtless cover, and splitting premium cannot reduce what
the seller receives at a fixed timestamp.

### Split default claims

Recovery shares use cumulative default-supply entitlement rounded against each claimant, not per-call
floor rounding. A claimant cannot split one claim into dust calls to receive cash without surrendering
the corresponding debt.

### Strategy loss or illiquidity

Outstanding cover remains in cash. Only unused capacity may enter the optional vault. A new fill must
restore exact cash first; failure occurs before buyer assets move. Claims never call the vault.
Terminal settlement transfers residual vault shares in kind.

Terminal release reads the facility's actual cash and vault-share balances even when accounting
collateral has reached zero. This prevents strategy yield or rounding residue from becoming stranded.

This does not make the strategy risk-free. Loss reduces seller residual and may close future capacity.
An ERC-4626 share may be hard to sell. The facility does not value or cap strategy risk.

### Reentrancy and hostile tokens

Creation, fill, allocation and settlement cross token and vault boundaries. A single reentrancy guard
covers state-changing facility paths, and the factory guards creation. Exact-transfer checks reject
fee-on-transfer behaviour. Tests exercise premium failure and vault callbacks.

### Expiry observation

Stock Wildcat V2 state does not prove that the threshold was crossed before expiry if nobody recorded
it. Default may be checkpointed through the exact expiry timestamp; after that the healthy maturity
path wins. A production operator needs a keeper and alerting. This is the main offchain availability
assumption.

### Claim-window lapse

Default claims expire after one year. Unclaimed collateral can then return to the seller and the
holder can redeem debt only. Integrations must surface the deadline and exercise on time.

## Explicitly unsupported

- rebasing, fee-on-transfer or otherwise inexact base assets;
- noncanonical wrappers or markets that reject wrapper deposits;
- live claim-reserve deployment;
- naked cover, cash settlement without debt surrender or recovery auctions;
- governance intervention, pausing, upgrades or emergency sweeps; and
- deployment claims based only on this internal review.

## Review priorities

1. Boundary ordering at expiry and claim deadline.
2. Cumulative wrapper-share allocation across fills, unprotection, claims and redemption.
3. Cash backing before and after every vault interaction.
4. Exact-transfer rollback under callback and token failure.
5. Wildcat V2 state semantics at the pinned dependency commit.
