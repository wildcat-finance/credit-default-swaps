# Covered credit default swaps for Wildcat markets

Research checked 16 August 2026. This is a product and engineering study for a prototype. It is not
legal advice, an offer of cover, a price, a credit opinion, or a claim that the eventual contracts are
ready for production.

## Decision

Build a permissionless, fixed-term, fully collateralised facility against one Wildcat V2 market. A
protection seller escrows the settlement asset, chooses the notional, funding deadline, tenor and
annual premium spread, and names a recovery beneficiary. One lender fills the complete offer by
depositing the same face amount of Wildcat debt and paying the premium up front. The facility puts the
debt into the market's canonical ERC-4626 wrapper and mints an ERC-20 protected-debt receipt.

The receipt carries both the fixed CDS entitlement and beneficial ownership of the escrowed debt. A
transfer therefore moves the debt and protection together. The token is never economically naked even
though the underlying wrapper shares remain in the facility. Default is mechanical. Anyone may record
it while the facility is live once the market's canonical state reports at least 90 days of penalised
delinquency. A holder burns the receipt for par from seller escrow; the corresponding wrapper shares
become seller recovery. At healthy maturity, the seller recovers the protection collateral and
holders burn receipts for their share of the wrapped debt, including accrued interest.

The first prototype leaves escrow idle. Aave, Morpho and generic ERC-4626 deployment are later work.
The CDS promise is only useful if the cash is there when the market is not.

## Problem statement

Wildcat lenders take the credit risk of a named borrower. Existing crypto cover products mostly insure
smart-contract exploits, oracle failures or other protocol incidents. They are a poor fit for an
ordinary Wildcat default: a claims committee would have to decide whether a lender's loss falls within
wording designed for technical failures, and pooled underwriters may not have isolated the right
amount or asset for that market.

The proposed facility is for an existing Wildcat lender that wants to cap a fixed amount of borrower
credit exposure for a fixed period. It is also for a protection seller willing to post the maximum
cash payout at inception in return for a quoted premium. It deliberately excludes traders who cannot
deliver the associated debt when they exercise.

A working prototype proves this path in Foundry:

1. A seller creates a facility and escrows 400,000 units of the Wildcat market's base asset.
2. A lender fills all 400,000 units of cover and pays the upfront premium.
3. The facility deposits that debt into the canonical wrapper and mints exactly 400,000 protected-debt
   receipts. Partial or second fills fail.
4. A secondary transfer moves the bundled debt claim and protection together without consulting an
   external lender balance.
5. The market's canonical `timeDelinquent` reaches `delinquencyGracePeriod + 90 days` before expiry.
6. Any account records default once; the record never reverses.
7. The lender burns 400,000 receipts and receives 400,000 base-asset units. The wrapper shares become
   seller recovery.
8. Before default, a holder may burn receipts to recover the matching wrapped debt. The same amount of
   seller collateral is released and the prepaid premium is not refunded.
9. In the no-default path, the seller recovers collateral after expiry and holders redeem the wrapped
   debt rather than a CDS payout.

The release check is a passing Foundry unit, fuzz and invariant suite covering those paths, the
solvency identity `payouts + remaining collateral = initial collateral` before seller release, and
partition of every wrapper share between remaining holders and seller recovery.

## What counts as a CDS here

A credit default swap names a reference obligation or entity, defines a credit event, has a finite
notional and term, charges the buyer a premium, and assigns a payout obligation to the seller. This
prototype has each part. “Swap” is conventional product language; the cashflows are an upfront
premium followed by either expiry or a default settlement.

Protocol exploit cover is not ordinarily credit protection. Tranching is not a CDS either: it moves
loss between claims on the same pool rather than adding a separate pot of protection capital. Both are
still useful precedents for claims, capital and recovery design.

## Historical attempts and what survived them

### CDx: tokenised loans as reference obligations, 2017-2018

CDx proposed an Ethereum protocol in which smart contracts acted as custodian, clearinghouse and
enforcement layer for tokenised CDS, with intended compatibility with Dharma tokenised debt. The
shape is close to the present idea: protection against a specific onchain loan rather than a generic
protocol failure. The study found no primary evidence of sustained production use or meaningful
liquidity, so CDx is evidence of design lineage, not product-market fit.

Source: [Introducing CDx](https://medium.com/@andrew_young/introducing-cdx-77703b754f4a).

### Nexus Mutual: naked cover led back to proof of loss

Nexus Mutual launched as a discretionary mutual for smart-contract cover. Its early product did not
require the buyer to have money in the covered protocol. In 2020, founder Hugh Karp described the
product as conceptually acting like a CDS because it could be bought without the underlying exposure,
then proposed cryptographic proof of loss. The discussion considered surrendering impaired tokens in
the same way as physical CDS settlement.

Current Single Protocol Cover protects against listed technical and economic failures such as hacks,
oracle failures, liquidation failures and governance takeovers. A claimant supplies affected wallet
addresses and evidence of actual loss. The Claims Committee decides whether the loss fits the wording.
Current cover is discretionary and represented by an ERC-721, not a mechanical borrower-default swap.

This history matters to the imagined `wmtUSDC` default. Ordinary borrower non-payment is not made into
a covered protocol incident merely because the debt is wrapped as an ERC-4626 share. Nexus can assess
a liquidation bug or exploit that creates lender bad debt; a plain Wildcat default needs its own
credit-event wording and loss proof. Wildcat already exposes an onchain delinquency record, so adding a
committee would reintroduce discretion where the reference market can supply the fact.

Sources:

- [Nexus proof-of-loss governance discussion](https://forum.nexusmutual.io/t/add-proof-of-loss-requirement-to-cover-wording/131)
- [Current Nexus cover products](https://docs.nexusmutual.io/overview/cover-products/)
- [Single Protocol Cover and upfront proof of loss](https://docs.nexusmutual.io/overview/cover-products/protocol-cover/)
- [Tokenised cover](https://docs.nexusmutual.io/protocol/cover/)
- [Claims contract and assessment flow](https://docs.nexusmutual.io/developers/contracts/Claims/)

Lesson: possession of a cover token is not proof of loss. Exercise should require the impaired debt.

### Opium: the closest generic fully collateralised derivative, 2020-2021

Opium implemented a generic smart escrow. A derivative recipe fixed margin, maturity, settlement
token, oracle and payout logic, then minted tokenised long and short positions. Opium launched CDS
products around Aave Credit Delegation and crypto impairment risks. The wBTC product used upfront
premium, fixed maturity, fully posted margin, tokenised positions and yDAI as productive collateral.

Opium proves that the broad escrow-and-position-token construction is feasible. Its products were not
tied to ownership of the reference exposure, so they could be naked. Price or oracle triggers also
introduced basis risk against the credit event. Productive collateral added Yearn and withdrawal risk
to the payout promise. The study found launch records and current protocol infrastructure, but not
evidence of sustained CDS liquidity. That absence is not proof of failure; it is a reason not to build
the prototype around assumed secondary-market depth.

Sources:

- [Opium high-level architecture](https://docs.opium.network/for-developers/high-level-overview)
- [Opium Protocol V2](https://docs.opium.network/for-developers/opium-protocol-v2)
- [Opium derivative mechanics](https://docs.opium.network/complex-description/opium-derivatives)
- [Opium production statistics and current positioning](https://opium.network/)
- [Opium governance proposal listing suspended USDT-protection pools](https://forum.opium.network/t/proposal-global-withdrawal-of-old-suspended-pools/323)

Lesson: use the Wildcat market's own state instead of a separate oracle, and do not count a yield share
as cash collateral.

### Cover Protocol and Ruler: direct DeFi CDS, 2020-2021

Cover's core model let a market maker deposit collateral and mint fungible `CLAIM` and `NOCLAIM`
tokens. In February 2021 it announced CDS for undercollateralised lending and named Ruler Protocol as
an initial integration. Ruler lenders could hedge borrower-side insolvency where liquidation did not
make them whole. The product is a direct precedent for named lending pairs, expiry, collateral-backed
fungible protection and borrower-default settlement.

The surrounding incentive system failed operationally. In December 2020, a stale accounting copy in
the Blacksmith rewards contract, amplified by a near-empty pool, allowed roughly 40 quadrillion
`COVER` to be minted. Cover stated that the core coverage contracts were unaffected. It dropped native
shield mining, compensated eligible holders from returned funds and a new token, and continued work.
Core contributors left in September 2021 and the protocol did not become durable credit-protection
infrastructure.

Sources:

- [Cover product paper](https://coverprotocol.medium.com/cover-protocol-product-paper-9bf5d689dd98)
- [Cover introduces CDS](https://coverprotocol.medium.com/introduce-credit-default-swaps-a68a3a22b7aa)
- [Cover exploit post-mortem](https://coverprotocol.medium.com/12-28-post-mortem-34c5f9f718d4)
- [Compensation plan](https://coverprotocol.medium.com/compensation-plan-b089d499191e)
- [Cover's post-exploit plan](https://coverprotocol.medium.com/the-future-plans-e328a58e8a47)
- [September 2021 contributor departures](https://coverprotocol.medium.com/structure-and-personnel-changes-757057611ede)

Lesson: the CDS can be small even when emissions, AMM incentives and rollover machinery become the
dangerous part. The prototype has none of them.

### BarnBridge: tranching is related, but not protection capital

BarnBridge SMART Yield pooled deposits into third-party lending protocols and divided returns and
shortfalls between senior and junior claims. Junior capital took the first shortfall and earned the
residual return. This is first-loss structuring, not a separate CDS: the same pool's depositors
rearranged their risk.

The US Securities and Exchange Commission's 2023 orders describe more than $509 million entering
SMART Yield pools and the eventual settlement over unregistered securities and investment-company
claims. That is a US enforcement precedent, not a legal conclusion about this repository. It does
mean a live facility needs specialist analysis before distribution, particularly if outward material
uses “insurance”, “guaranteed”, “bond”, “fixed return” or “CDS” without qualification.

Sources:

- [BarnBridge whitepaper repository](https://github.com/BarnBridge/BarnBridge-Whitepaper)
- [SEC order describing SMART Yield](https://www.sec.gov/files/litigation/admin/2023/33-11262.pdf)

Lesson: segregated payout collateral is easier to explain and test than a loss promise inside the
reference pool.

### Mutual and pooled cover: Unslashed, InsurAce and Sherlock

Unslashed pooled risks into underwriting buckets, represented positions as ERC-20s, streamed premium,
invested capital and sent disputed claims to Kleros. The UST collapse produced a cluster of claims,
which is the normal shape of tail risk rather than an exception. InsurAce likewise couples a cover
payment pool to underwriting pools and an investment arm. Its documentation permits investment of
free cover capital and allows withdrawals to be suspended during claims.

Sherlock supplied an especially relevant warning. Its underwriting pool placed $5 million into a
Maple pool containing uncollateralised Orthogonal Trading credit. After FTX and Orthogonal's default,
Sherlock reported an expected 20-25% recovery. Capital backing one protection business had taken a
separate credit loss before it might be needed for claims.

Sources:

- [Unslashed design manifesto](https://medium.com/unslashed/manifesto-for-a-decentralised-crypto-insurance-unslashed-finance-873078fd0ddd)
- [Kleros integration catalogue](https://docs.kleros.io/integrations/live-and-upcoming-integrations)
- [InsurAce design and investment arm](https://docs.insurace.io/landing-page/documentation/overview/what-is-insurace)
- [InsurAce cover products](https://docs.insurace.io/landing-page/documentation/cover-products)
- [Sherlock documentation repository](https://github.com/sherlock-protocol/sherlock-docs)
- [Maple default and impairment mechanics](https://docs.maple.finance/maple-for-lenders/defaults-and-impairments)

Lesson: never deploy Wildcat payout collateral into unsecured or correlated credit. Adapter losses may
reduce the seller's residual; they must not create a cover shortfall.

### Risk Harbor and Cork: tender the impaired asset

Risk Harbor used parametric onchain detectors and settled by exchanging distressed covered tokens for
USDC. Its original documentation is no longer readily available, so the surviving operating record is
secondary. The settlement shape remains useful: the claimant proved exposure by tendering the asset,
and underwriters received it.

Cork is the strongest current analogue. A depositor splits collateral into a Principal Token and a
Swap Token. The Swap Token permits its owner to exchange the reference asset for collateral before
expiry. The identity `Swap Token + Reference Asset = Collateral Asset` is physically settled,
fully collateralised protection against impairment, depeg or credit risk.

Cork also shows where complexity bites. Its May 2025 post-mortem attributes an exploit to rollover
pricing manipulation and missing authorisation checks in a Uniswap v4 hook while the simpler base
module operated as intended.

Sources:

- [OpenCover's Risk Harbor record](https://opencover.com/risk-harbor/)
- [Cork overview](https://docs.cork.tech/)
- [Cork Swap Token](https://docs.cork.tech/core-concepts/swap-token)
- [Cork Principal Token](https://docs.cork.tech/core-concepts/principal-token)
- [Cork May 2025 post-mortem](https://www.cork.tech/blog/post-mortem)

Lesson: physical settlement solves exposure and recovery cleanly. Leave AMMs and automatic rollover
outside the fixed-term core.

## Wildcat V2 as the reference system

The inspected V2 baseline is `wildcat-finance/v2-protocol` commit
`c7be4039f8f383a9dda4e45f63331c17d63f9ed9` on 16 August 2026.

`WildcatMarket.currentState()` returns a canonical `MarketState`. `MarketState.timeDelinquent` is a
`uint32` count of delinquent seconds. `FeeMath.updateDelinquency` increases it while the market is
delinquent and decreases it while the market is healthy. The market's configured
`delinquencyGracePeriod` determines when the delinquency fee begins.

The user's “90 days cumulative penalised delinquency” therefore needs an exact reading. The prototype
uses:

```text
currentState.timeDelinquent >= market.delinquencyGracePeriod() + 90 days
```

Equality triggers. The record is permanent once made. Because `timeDelinquent` decays during a cure,
this is a net delinquency accumulator, not a monotonic lifetime counter. “Cumulative” in the product
material refers to the market's current accumulator after cure decay. A different meaning would need
a separate observer that records every delinquent interval, which is deliberately absent.

`currentState()` calculates the state that would apply at the current block, but the market cannot
reconstruct whether the threshold had been met at an earlier expiry if nobody recorded it. The
prototype therefore requires `triggerDefault()` no later than expiry. `release()` is allowed only
after expiry, giving a same-timestamp trigger priority. A production facility needs a keeper and an
explicit operational guarantee around this boundary.

Wildcat market balances grow with the scale factor. CDS notional does not. A holder that activates 100
units of protection keeps a fixed 100-unit payout entitlement while the escrowed debt accrues inside
the wrapper. Less than 100% coverage is therefore normal over time and stated plainly.

Transfers of Wildcat market tokens call the market's configured hooks. Some markets disable transfers
or require recipient access. Activation works only where the market permits the lender to deposit into
the canonical wrapper. After activation, secondary transfers use the protected-debt receipt and do not
move raw market tokens. The prototype does not install, replace or depend on a singleton role
provider. The factory verifies the registered market and canonical wrapper, while an incompatible
market policy makes activation fail atomically.

Sources:

- [`MarketState.sol`](https://github.com/wildcat-finance/v2-protocol/blob/c7be4039f8f383a9dda4e45f63331c17d63f9ed9/src/libraries/MarketState.sol)
- [`FeeMath.sol`](https://github.com/wildcat-finance/v2-protocol/blob/c7be4039f8f383a9dda4e45f63331c17d63f9ed9/src/libraries/FeeMath.sol)
- [`WildcatMarketBase.sol`](https://github.com/wildcat-finance/v2-protocol/blob/c7be4039f8f383a9dda4e45f63331c17d63f9ed9/src/market/WildcatMarketBase.sol)
- [`WildcatMarketToken.sol`](https://github.com/wildcat-finance/v2-protocol/blob/c7be4039f8f383a9dda4e45f63331c17d63f9ed9/src/market/WildcatMarketToken.sol)

## Adverse selection is reduced, not removed

Requiring reference debt rules out a trader with no lender exposure. It does not make flow innocent.
An existing lender can observe a borrower deteriorating and buy cover just before the objective
threshold.

The prototype uses three controls:

- the seller fixes a funding deadline and the offer can be filled only once, in full;
- activation fails once `timeDelinquent` is nonzero, including the market's grace period;
- the premium is an immutable annual spread applied to the complete tenor.

This does not price private information or offchain borrower distress. It gives the seller a bounded
subscription period and stops new flow at the first onchain arrears signal. Dynamic spreads, auctions
and market makers are later experiments.

## Premium and tenor

For cover amount `N`, annual premium spread `s` in basis points and tenor `D`, the prototype charges:

```text
premium = ceil(N * s * D / (10,000 * 365 days))
```

The day-count convention is ACT/365. Premium is paid once to the protection seller when the full offer
activates. An unfilled seller may cancel after the funding deadline and recover collateral. There is no
external discount curve. A quoted annual spread can be produced by an offchain discounted-cashflow
model, but calling the onchain calculation “DCF” would invent a curve that the contract does not have.

## The holdability limit

A separate cover ERC-20 can check that a recipient's cover does not exceed its current market-token
balance. It cannot stop that recipient from moving the market debt later because an arbitrary existing
Wildcat market does not call the CDS facility when the lender reduces its balance. Rechecking on claim
still permits a buyer to sell healthy debt during the tenor, buy distressed debt cheaply after default
and tender it at par. That trade is naked protection in substance.

The selected construction escrows the debt at activation and makes the ERC-20 a receipt for the whole
protected position. The wrapper shares stay partitioned behind the receipt, so transferring the token
transfers beneficial ownership of the debt and the cover in one operation. Strictly separable cover
would require a lien callback in the market hook, a protocol-level lien registry, or trusted balance
observations. Stock V2 supplies none of them across every existing market.

## Design options

### Option A: balance-gated cash settlement

Mint a normal cover ERC-20, check debt balance on receipt and pay cash on burn.

This is small, but weak. The debt can move away after the receipt check, and a claimant may keep later
recoveries after receiving full notional. It fails the covered-only purpose at the moment that matters.

### Option B: escrow the debt with the cover - selected

Require one lender to deposit the full notional of market tokens into the canonical wrapper and mint a
paired debt-plus-cover receipt. The receipt remains an ERC-20 and can guarantee that every cover unit
stays attached to beneficial ownership of debt.

This changes the wallet shape: the receipt replaces separate cover and raw debt during the tenor. It
uses the existing wrapper rather than reproducing Wildcat scaled accounting, and returns wrapper
shares at healthy maturity rather than operating a withdrawal queue. It is the only option here that
meets the user's covered-only purpose throughout the tenor.

### Option C: physically settled separate cover ERC-20

Keep the cover ERC-20 and the underlying market token separate. Check the recipient on cover
transfers. At default, require equal market-token tender for the cash payout and send the debt to the
recovery recipient.

This prevents double recovery and assigns workout value correctly, but it leaves a trading gap between
receipt and exercise. The buyer can dispose of healthy debt and reacquire it after default. It is
rejected because it does not meet the covered-only purpose over the full tenor.

### Option D: generic derivative core or discretionary mutual

Build recipes, oracles, pools, claims governance, AMM liquidity and rollover around the facility.

Opium, Nexus and Cover already explored those general systems. The extra control plane does not prove
the Wildcat-specific idea and would dominate the audit. It is rejected for the prototype.

## Contract outline

### `CoveredCDSFactory`

An immutable, ownerless factory deploys facilities and verifies the Wildcat bindings. It accepts only
a registered market, the canonical wrapper for that market, the market's base asset as collateral and
a market with a nonzero delinquency fee. Anyone may create an offer. There is no factory fee, owner,
upgrade or mutable allowlist.

### `CoveredCDSFacility`

One immutable offer, one full fill and one ERC-20 protected-debt ledger:

- `market`: the reference Wildcat market and raw debt token;
- `wrapper`: the canonical ERC-4626 wrapper whose `asset()` is `market`;
- `asset`: `market.asset()`, used for seller collateral, premium and payout;
- `seller` and `recoveryBeneficiary`;
- `notional`, `remainingCollateral` and wrapper-share partitions;
- `fundingDeadline`, `tenor`, activation timestamp, expiry and claim deadline;
- `annualPremiumBips` and the fixed 90-day post-grace threshold;
- lifecycle `Offered -> Active -> Defaulted` or `Offered -> Active -> Matured`, plus unfilled
  cancellation and partial receipt burns while active;
- ERC-20 receipt balances, supply and allowances.

Creation pulls the full notional from the seller. `activate` is all-or-nothing: it pulls the complete
reference debt and premium from one lender, deposits the debt into the canonical wrapper, and mints
exactly `notional` receipts. It refuses partial fills, later fills, late funding and any nonzero
delinquency. `checkpoint` calls `market.updateState()`, reads the current state, and makes default or
maturity permanent.

While active, `unprotect` lets a holder burn any receipt amount for its proportional wrapper shares.
The facility releases the same normalized amount of protection collateral to the seller. Cover and
debt therefore remain paired, but a holder can return the protected position to raw debt liquidity
without waiting for expiry. The upfront premium remains with the seller.

On default, `claim` burns receipts, reduces collateral, assigns the proportional wrapper shares to the
seller's recovery account and pays par. It does not transfer recovery shares during the payout, so a
seller-side transfer failure cannot block the protected holder. On healthy maturity, the seller
withdraws collateral and holders burn receipts for their proportional wrapper shares. The final burn
receives rounding dust in either path.

## Idle capital

The first version holds the base asset. This is a product rule, not missing polish.

Aave explains that suppliers may withdraw only while the pool has enough unborrowed liquidity. Morpho
Vault V1 liquidity depends on the liquidity and withdrawal queue of its underlying markets. Vault V2
adds force deallocation and in-kind exits, neither of which guarantees same-transaction base-asset
payout at par. A generic ERC-4626 reports shares and asset conversions; it does not promise liquid
cash when the reference borrower has also failed.

Sources:

- [Aave supply withdrawal behaviour](https://aave.com/help/supplying/withdraw-tokens)
- [MetaMorpho / Morpho Vault V1](https://github.com/morpho-org/metamorpho)
- [Morpho Vault V2](https://github.com/morpho-org/vault-v2)
- [ERC-4626](https://eips.ethereum.org/EIPS/eip-4626)

A later adapter experiment should have one allowlisted implementation, a hard allocation cap, liquid
reserve, automatic de-risk schedule beginning at first delinquency, complete unwind well before the
90-day trigger, and loss borne by seller residual rather than protection notional. “Any ERC-4626” is
not a safe interface policy.

## Constraints and non-goals

### Starting point

- Destination: empty public repository `wildcat-finance/credit-default-swaps`.
- Base branch: `main`.
- Tracking issue: `https://github.com/wildcat-finance/credit-default-swaps/issues/1`.
- Reference style: `laurenceday/brc-research` at
  `12f9e1b259f5887835c0e32644fbdf4acdc74182` and `wildcat-finance/wildcat-tranching` at
  `a01e14e259d5531b12df069679ee5470f77a9632`.
- Brand source: `Wildcat Brand Guideline (1).pdf`, 10 pages, supplied 16 August 2026.

### Toolchain

Use Foundry, Solidity 0.8.28, Cancun, optimiser 200 runs and `via_ir = true`, matching the current
research repositories. Pin `forge-std` and the inspected Wildcat V2 commit. Keep generated controller
state, renders and temporary image sources out of the authored tree.

### Prototype non-goals

- Naked cover, synthetic shorting or payout without debt tender.
- Uncollateralised, fractional-reserve or delegated protection sellers.
- Recovery-price auctions or cash settlement at par minus recovery.
- Dynamic pricing, an order book, AMM, liquidity mining or governance token.
- Automatic rollover, portfolio cover, cross-market netting or reinsurance.
- A claims committee, optimistic oracle or offchain default attestation.
- Generic ERC-4626, Morpho or Aave deployment of payout collateral.
- Upgradeability, pause, administrator sweep or arbitrary call execution.
- Separable cover whose holder keeps raw debt in another wallet.
- Partial fills, continuous issuance or more than one primary buyer per facility.
- Compatibility with markets whose transfer policy rejects deposit into the canonical wrapper.
- A frontend, deployment, live facility, legal opinion or production-readiness claim.

## Risk register seed

| Risk | Why it matters | First control or audit question |
| --- | --- | --- |
| False default observation | `timeDelinquent` accrues and decays under Wildcat rules | Use `currentState()` and the exact `grace + 90 days` comparison; test equality, cure and permanence |
| Expiry race | State cannot be reconstructed retrospectively | Permit trigger at `timestamp == expiry`; release only after; test both calls in the boundary block |
| Late toxic flow | Lenders can see deterioration before the threshold | Refuse purchase after deadline or any nonzero `timeDelinquent` |
| Naked payout | Separate cover and debt can split after a receipt check | Escrow the full debt at activation and transfer the bundled receipt |
| Double recovery | Par payment plus retained debt over-indemnifies the holder | Allocate the receipt's wrapper shares to seller recovery when par is paid |
| Market hook incompatibility | Wrapper deposit can revert on access or disabled transfers | Verify the canonical wrapper; test failed activation with no receipt or premium loss |
| Interest and rounding | Market balances grow and wrapper conversions round | Keep CDS notional fixed; partition actual wrapper-share deltas and give final-burn dust |
| Collateral shortfall | Every cover unit must remain payable | Never mint above initial collateral; assert payouts never exceed it |
| Fee-on-transfer asset | Escrow or premium can arrive short | Measure balance deltas or reject unsupported assets in tests and documentation |
| Reentrancy | Two ERC-20 transfers occur during claim | Apply a guard and checks-effects-interactions; use hostile-token tests if the interface permits |
| Seller/recovery address sanctions | Wrapper-share transfer can reject a recipient | Accrue seller recovery internally so payout does not depend on recovery withdrawal |
| Claim-window forfeiture | A covered lender can miss exercise | Make the window explicit, long and immutable; no silent seller release before it ends |
| Stuck collateral or debt | Terminal paths may leave assets trapped | Account for every base-asset unit and every tendered debt transfer; no general rescue route |
| Strategy liquidity | External yield may vanish when claims arrive | No adapter in v0; later adapters count only withdrawn cash as collateral |
| Correlated strategy loss | A second borrower default can impair payout capital | Ban unsecured and reference-correlated deployment |
| Regulatory description | “CDS” and ERC-20 transferability can carry legal consequences | Keep prototype warnings visible and obtain jurisdiction-specific advice before distribution |
| Dependency drift | V2 state or hook semantics may change | Pin commits and repeat the study when upgrading |

## Invariants for implementation and fuzzing

1. Receipt supply is zero before activation, exactly `notional` when activation succeeds, and may
   decrease only through settlement, redemption or live unprotection.
2. No receipt can be minted after activation.
3. `totalPayouts + remainingCollateral + totalSellerReleased = initialCollateral`.
4. `totalPayouts <= initialCollateral` forever.
5. Default and healthy maturity are mutually exclusive and each is irreversible.
6. No activation succeeds after deadline or with nonzero delinquency.
7. Actual wrapper shares received at activation are fully partitioned between remaining holders and
   seller recovery.
8. A default claim cannot pay more than receipts burned or remaining collateral.
9. A failed payout leaves receipt balance, collateral and wrapper partitions unchanged.
10. Seller collateral can leave only after healthy maturity, an expired claim window, unfilled
    cancellation, or a live receipt burn that destroys the same amount of cover.
11. Premium cannot leave the buyer unless activation and wrapper deposit both succeed.
12. A recovery-share transfer failure cannot block a default payout.
13. Final default claim or maturity redemption receives the wrapper-share rounding remainder.

## Glossary seeds

- **Base asset:** the ERC-20 used by the reference Wildcat market and by the CDS for collateral,
  premium and payout.
- **Reference market:** the one Wildcat V2 market whose borrower delinquency determines the credit
  event.
- **Reference debt:** the reference market's ERC-20 lender claim, tendered in physical settlement.
- **Protection seller:** the facility creator that posts full collateral and receives premium.
- **Recovery beneficiary:** the immutable address authorised to withdraw wrapper shares assigned to
  seller recovery.
- **Protected-debt receipt:** the facility's ERC-20 carrying both beneficial ownership of wrapped
  reference debt and a fixed base-asset-denominated CDS entitlement.
- **Funding deadline:** the last timestamp at which one lender can fill the complete offer if
  delinquency is still zero.
- **Expiry:** the last timestamp at which the facility can record default.
- **Annual premium spread:** the immutable ACT/365 basis-point quote used to calculate the upfront
  premium for remaining term.
- **Penalised delinquency:** `max(0, timeDelinquent - delinquencyGracePeriod)` under the current Wildcat
  state.
- **Credit event:** at least 90 days of penalised delinquency recorded no later than expiry.
- **Physical settlement:** exchange of the protected-debt receipt for par base asset, with the bundled
  wrapper shares assigned to seller recovery.
- **Claim window:** the post-trigger period during which holders may physically settle.
- **Covered CDS:** protection whose payout requires delivery of the associated debt.
- **Naked CDS:** protection that can pay without ownership or delivery of the reference debt; excluded.

## Repository and brand direction

The repository should follow the information shape of `brc-research` and `wildcat-tranching`: a direct
README, one worked economic example, architecture and threat-model documents, validation evidence,
and a small business-development field kit. The outward visuals use 1920 x 1080 bitmap assets, large
Liberation Sans headings, Inter body copy where available, pale cards, black line work and restrained
Wildcat gradients.

The supplied brand palette gives the working colours: Bunker `#141414`, Ultramarine `#3E68FF`, Purple
Heart `#4D26BC`, Hawkes Blue `#D2DDFF`, Carmine Pink `#F1464B`, Galliano `#D7A820` and Oasis
`#FBEDC3`. Exact words, figures, addresses and formulae stay as Markdown or typeset layout text rather
than generated pixels. Generated bitmap art may carry a cover or story beat, but not the economic
claim.

## Source index

### Wildcat and reference repositories

- [Wildcat V2 protocol](https://github.com/wildcat-finance/v2-protocol/tree/c7be4039f8f383a9dda4e45f63331c17d63f9ed9)
- [BRC research prototype](https://github.com/laurenceday/brc-research/tree/12f9e1b259f5887835c0e32644fbdf4acdc74182)
- [Wildcat tranching prototype](https://github.com/wildcat-finance/wildcat-tranching/tree/a01e14e259d5531b12df069679ee5470f77a9632)
- [Wildcat documentation](https://docs.wildcat.finance/)

### Standards and market conventions

- [ERC-20](https://eips.ethereum.org/EIPS/eip-20)
- [ERC-4626](https://eips.ethereum.org/EIPS/eip-4626)
- [ISDA credit-derivatives resources](https://www.isda.org/category/credit-derivatives/)

### Prior art

- [CDx introduction](https://medium.com/@andrew_young/introducing-cdx-77703b754f4a)
- [Nexus Mutual proof-of-loss discussion](https://forum.nexusmutual.io/t/add-proof-of-loss-requirement-to-cover-wording/131)
- [Nexus Single Protocol Cover](https://docs.nexusmutual.io/overview/cover-products/protocol-cover/)
- [Opium architecture](https://docs.opium.network/for-developers/high-level-overview)
- [Opium Protocol V2](https://docs.opium.network/for-developers/opium-protocol-v2)
- [Cover introduces CDS](https://coverprotocol.medium.com/introduce-credit-default-swaps-a68a3a22b7aa)
- [Cover exploit post-mortem](https://coverprotocol.medium.com/12-28-post-mortem-34c5f9f718d4)
- [BarnBridge whitepaper](https://github.com/BarnBridge/BarnBridge-Whitepaper)
- [SEC BarnBridge order](https://www.sec.gov/files/litigation/admin/2023/33-11262.pdf)
- [InsurAce overview](https://docs.insurace.io/landing-page/documentation/overview/what-is-insurace)
- [Sherlock documentation](https://github.com/sherlock-protocol/sherlock-docs)
- [Maple defaults and impairments](https://docs.maple.finance/maple-for-lenders/defaults-and-impairments)
- [Cork Swap Token](https://docs.cork.tech/core-concepts/swap-token)
- [Cork post-mortem](https://www.cork.tech/blog/post-mortem)

## Research conclusion

The product is credible because Wildcat supplies what earlier cover systems lacked: a named onchain
debt claim and a deterministic delinquency state. The facility does not need a mutual, oracle, token
incentive or claims vote to discover whether its own reference market crossed the agreed line.

The protected-debt receipt is the decisive choice. Escrowing Wildcat debt at activation and burning the
bundled receipt for par handles proof of exposure, continuous covered status, duplicate recovery and
workout rights without changing the market's hooks. The prototype should prove that rule with idle
cash. Productive collateral, separable cover and naked facilities are separate experiments once the
fixed-term core survives review.
