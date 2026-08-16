# Product terms

These terms describe the prototype code. They are not legal terms, a quote or an offer.

| Term | Prototype rule |
| --- | --- |
| Reference | One registered Wildcat V2 market |
| Seller | Facility creator; posts full notional |
| Buyer | Any holder able to tender required canonical wrapper shares |
| Capacity | Seller notional less outstanding and permanently unprotected amounts |
| Entry | Any positive available amount before fixed expiry |
| Entry health | Current market `timeDelinquent` must be zero |
| Premium | Upfront, ACT/365, immutable annual basis-point spread, rounded up |
| Receipt | ERC-20 beneficial claim on bundled wrapper debt and cover |
| Credit event | `timeDelinquent >= grace + 90 days`, recorded no later than expiry |
| Payout | One base-asset unit per receipt unit burned during claim window |
| Recovery | Corresponding wrapper shares assigned to recovery beneficiary |
| Healthy outcome | Seller takes collateral; holders redeem wrapper shares |
| Live exit | Burn receipt, recover wrapper shares, release equal collateral to seller |
| Premium refund | None |
| Claim window | One year after expiry |
| Strategy | Optional immutable ERC-4626 for cash above outstanding receipt supply only |

## Fixed notional, growing debt

Protection is denominated in normalized base-asset units and does not grow. Wildcat debt may accrue
inside the wrapper. Coverage can therefore fall below 100% of the debt's later value. Receipt holders
retain the wrapper-share economics on healthy redemption; default pays the fixed protected amount.

## What the receipt price can express

The receipt is transferable and combines a debt claim with a fixed default payout. Its market price
can therefore reflect accrued debt value, borrower credit risk, protection value, time remaining,
liquidity and strategy expectations. The contracts do not supply an oracle or promise a liquid market.

## Non-goals

The prototype does not provide naked cover, borrowed exposure, fractional reserve selling, an AMM, dynamic
spreads, rollover, portfolio netting, a frontend or deployment tooling. It has received internal
security review in this repository but no external audit.
