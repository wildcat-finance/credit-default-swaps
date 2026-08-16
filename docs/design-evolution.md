# Design evolution

This note records the models considered during the prototype. It is not a defence of the last model.
The requirements changed as the accounting became concrete, and another model may fit a different
market or product objective better.

## The questions that drove the changes

1. How can cover remain covered after the buyer moves its debt?
2. Can the protected position trade without depending on a new Wildcat hook?
3. Can several lenders share one seller's quoted capacity?
4. Must entry stop at an arbitrary funding deadline?
5. Which collateral can earn yield without making an existing claim depend on strategy liquidity?

## Model 1: separable balance-gated cover

The first sketch minted a cover ERC-20 only to debt holders. Transfers and claims would check the
holder's market-token balance.

**What it preserves:** raw debt stays in the lender's wallet, cover has an independent market price
and existing DeFi venues can trade it directly.

**What breaks:** a stock Wildcat V2 market does not call the CDS contract when debt moves. A buyer can
pass the mint check, sell the debt and retain cover. Rechecking at claim lets the buyer reacquire
impaired debt after default. The token is covered at checkpoints, not throughout its life.

**Revisit if:** Wildcat adds a protocol-level lien registry or a hook which makes debt disposal notify
the cover contract. This model may also be acceptable when naked exposure is an explicit product
feature rather than a defect.

## Model 2: one-fill protected-debt receipt

The next model escrowed canonical wrapper shares and issued one ERC-20 carrying both debt and cover.
One lender had to take the whole notional.

**What it preserves:** the receipt is always covered. Selling it transfers the debt and protection
together. Physical settlement sends par to the holder and the debt to seller recovery.

**What breaks:** all-or-nothing activation fragments liquidity and makes a large offer depend on one
lender. It also makes the receipt's secondary market do work that primary issuance could do more
simply.

**Revisit if:** a facility is negotiated bilaterally, the notional is deliberately indivisible or
the seller needs one known buyer for legal or operational reasons.

## Model 3: multi-fill with a funding window

The third model let several lenders fill arbitrary amounts during a subscription period, then fixed a
common tenor when anyone finalised the facility.

**What it preserves:** buyers can size independently, share accounting is cumulative and all holders
receive the same protection term after finalisation.

**What breaks:** capital waits through an arbitrary funding deadline, a finalisation call is required,
and late buyers receive the same tenor despite entering later. The window removes useful primary
liquidity without solving a settlement problem.

**Revisit if:** the product is an auction, the seller needs a minimum subscription before accepting
risk or every buyer must start with the same forward protection period.

## Model 4: continuous fixed-expiry issuance

The implemented model fixes expiry when the seller creates the facility. Any number of lenders can
buy any available amount until that timestamp. Each fill pays for its exact remaining term. Buyers
tender canonical wrapper shares; the facility mints the same normalized amount of protected-debt
receipts.

This removes the funding window and finalisation transaction. A creation-time full-notional wrapper
share budget, combined with cumulative ceiling-rounded targets, makes equivalent split and single
fills contribute the same aggregate shares. Entry stops at the first nonzero delinquency signal.

The cost is that early and late buyers hold receipts with the same expiry but pay different premiums.
That is intended: they bought different amounts of time. There is no dynamic spread, order book or
mark-to-market adjustment.

## Collateral strategy variants

Three capital rules remain plausible:

| Rule | Existing claim liquidity | Seller capital efficiency | Added dependency |
| --- | --- | --- | --- |
| Hold all collateral as cash | Highest | Lowest | Base asset only |
| Deploy only unused capacity | Live cover stays cash-backed | Improves while capacity is open | Optional ERC-4626 for future fills |
| Deploy live claim reserves | Depends on instant withdrawal | Highest | Strategy liquidity and solvency at claim |

The prototype implements the middle rule. Only cash above outstanding receipt supply may enter the
bound vault. A new fill restores its cash backing before taking buyer assets. Default claims never
call the vault. This makes vault loss or illiquidity a limit on future fills and seller residual, not
an impairment of protection already sold.

Deploying live claim reserves is not dismissed. It may be commercially necessary. It needs a separate
risk budget: reserve ratios, an unwind schedule at first delinquency, adapter-specific loss handling,
and a decision about whether a holder waits, accepts vault shares in kind or bears a shortfall. Aave
V3 also needs an adapter because its pool is not an ERC-4626 vault.

## Decision matrix

| Question | Balance-gated | One fill | Funding window | Continuous |
| --- | --- | --- | --- | --- |
| Covered throughout tenor | No | Yes | Yes | Yes |
| Raw debt remains separate | Yes | No | No | No |
| Several primary buyers | Yes | No | Yes | Yes |
| Entry until expiry | Yes | No | No | Yes |
| Common post-entry tenor | Per purchase | One buyer | Yes | No |
| Works on stock V2 | Partly | Yes | Yes | Yes |
| Current implementation | No | Historical | Historical | Yes |

## Open decisions for the team

- Is bundled debt acceptable for integrations which want a separate cover price?
- Should unprotection permanently retire capacity, as implemented, or let a seller resell it?
- Should spread stay fixed while credit quality changes offchain?
- Does seller capital efficiency justify putting live claim reserves at strategy risk?
- Should a future naked product reuse this factory or have a visibly separate contract family?

The current code answers these for one prototype. It does not settle them for the product.
