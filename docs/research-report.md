# Covered credit default swaps for Wildcat markets

Research checked 16 August 2026. This is a product and engineering study for a prototype. It is not
legal advice, a credit opinion, an offer of cover or a production-readiness claim.

## Conclusion

Wildcat provides two things earlier onchain cover systems often had to manufacture: a named onchain
debt claim and a deterministic delinquency state. A small facility can therefore settle borrower
credit protection without a claims committee, an external price oracle, token incentives or a
general-purpose derivatives engine.

The prototype uses a transferable protected-debt receipt. Buyers tender canonical wrapper shares and
the receipt carries beneficial ownership of those shares together with fixed cover. This answers the
covered-only problem throughout the tenor: when the receipt moves, the debt and protection move
together. At default, a holder surrenders the receipt for par and the debt passes to seller recovery.

One seller escrows a maximum notional. Any number of lenders can buy any available amount until a
fixed creation-time expiry. Each pays an upfront ACT/365 premium for the exact time left. A
creation-time wrapper-share budget and cumulative ceiling targets prevent split fills from diluting
earlier buyers. Entry stops at the first nonzero onchain delinquency signal.

An optional ERC-4626 strategy may hold only unused offer capacity. Cash equal to live receipt supply
stays in the facility. A new fill must restore its backing before buyer assets move, and default
claims never call the vault. Deploying live claim reserves remains a distinct, higher-risk design.

## The product

A facility names one registered Wildcat V2 market, base asset, canonical wrapper, seller, recovery
beneficiary, maximum notional, expiry tenor and annual spread. Creation pulls the full notional from
the seller.

A buyer chooses a positive amount of remaining capacity and tenders the wrapper shares which the
facility assigns to that normalized debt amount. The buyer also pays:

```text
premium = ceil(cover amount * annual spread bips * seconds left
               / (10,000 * 365 days))
```

The receipt is an ERC-20. It can trade as a combined debt-and-protection position. Before a terminal
state, a holder may burn through `unprotect` to recover wrapper shares; equal cover collateral returns
to the seller and the premium is not refunded. Retired capacity does not reopen.

Anyone may record default no later than expiry when:

```text
market.timeDelinquent >= market.delinquencyGracePeriod + 90 days
```

Equality triggers. Default is permanent. Holders then have one year after expiry to burn receipts for
par cash. Cumulative wrapper-share entitlement moves to seller recovery. At healthy maturity, the
seller takes residual collateral and holders redeem wrapper shares. After a missed default claim
window, holders retain debt redemption but lose the cash-protection claim.

## Why Nexus Mutual is the wrong tool

Nexus Mutual's present protocol cover addresses listed technical and economic failures such as hacks,
oracle failures, liquidation failures and governance attacks. A claimant provides affected addresses
and evidence, and assessment decides whether the loss fits discretionary wording. The cover itself is
represented separately from the affected position.

An ordinary `wmtUSDC` borrower default is not transformed into a protocol incident by wrapping the
debt. Asking a mutual to decide whether normal credit non-payment falls under exploit-oriented wording
adds discretion without improving the fact source. Wildcat already records delinquency. Physical
settlement of the named debt is cleaner proof that the claimant held the risk.

Sources:

- [Nexus proof-of-loss governance discussion](https://forum.nexusmutual.io/t/add-proof-of-loss-requirement-to-cover-wording/131)
- [Current Nexus cover products](https://docs.nexusmutual.io/overview/cover-products/)
- [Single Protocol Cover](https://docs.nexusmutual.io/overview/cover-products/protocol-cover/)
- [Claims flow](https://docs.nexusmutual.io/developers/contracts/Claims/)

## Prior attempts

### CDx

CDx proposed Ethereum contracts as custodian, clearinghouse and enforcement layer for tokenised CDS
against tokenised loans. It is close in shape to a named onchain debt facility. The available record
does not show durable production liquidity, so it establishes lineage rather than market fit.

Source: [Introducing CDx](https://medium.com/@andrew_young/introducing-cdx-77703b754f4a).

### Opium

Opium built generic fully collateralised derivatives with fixed recipes, maturity, settlement asset,
oracle and tokenised long and short positions. It launched CDS products around Aave credit delegation
and impairment risks, including productive yDAI margin.

The construction proves that escrow plus fungible positions works. It also shows the cost of generic
recipes and separate settlement oracles. Productive margin adds strategy liquidity to the payout
promise. This prototype instead uses the reference market's state and does not count vault shares as
cash backing for live protection.

Sources:

- [Opium architecture](https://docs.opium.network/for-developers/high-level-overview)
- [Opium Protocol V2](https://docs.opium.network/for-developers/opium-protocol-v2)
- [Derivative mechanics](https://docs.opium.network/complex-description/opium-derivatives)

### Cover Protocol and Ruler

Cover let market makers deposit collateral and mint fungible `CLAIM` and `NOCLAIM` tokens. Its
Ruler integration targeted insolvency in undercollateralised lending. Named pairs, expiry, fungible
protection and collateral-backed settlement are direct precedents.

The December 2020 Blacksmith exploit concerned rewards accounting rather than the core cover
contracts, but it illustrates how emissions and pool incentives can dominate the risk of a small
settlement core. Cover's contributors later departed. This prototype has no liquidity mining,
governance token or rollover machinery.

Sources:

- [Cover product paper](https://coverprotocol.medium.com/cover-protocol-product-paper-9bf5d689dd98)
- [Cover introduces CDS](https://coverprotocol.medium.com/introduce-credit-default-swaps-a68a3a22b7aa)
- [Cover exploit post-mortem](https://coverprotocol.medium.com/12-28-post-mortem-34c5f9f718d4)
- [Contributor departures](https://coverprotocol.medium.com/structure-and-personnel-changes-757057611ede)

### BarnBridge

BarnBridge SMART Yield divided third-party lending returns and shortfalls between senior and junior
claims. Junior capital absorbed first loss. This is tranching, not a separate pot of credit
protection, but it is relevant to how onchain instruments price and transfer lending risk.

The SEC's 2023 orders describe more than $509 million entering SMART Yield pools and a settlement over
US securities and investment-company claims. That is a US enforcement record, not a legal conclusion
about this code. A live product would need specialist analysis before distribution.

Sources:

- [BarnBridge whitepaper](https://github.com/BarnBridge/BarnBridge-Whitepaper)
- [SEC order](https://www.sec.gov/files/litigation/admin/2023/33-11262.pdf)

### Pooled cover and productive capital

Unslashed and InsurAce coupled cover pools to investment or underwriting machinery. Sherlock supplied
a sharper warning: capital backing its protection business entered a Maple pool containing
uncollateralised Orthogonal Trading credit, then suffered expected loss after FTX and Orthogonal's
default. Payout capital had taken a second credit risk when it might be needed for claims.

This does not mean productive collateral is impossible. It means an interface label such as ERC-4626
does not remove economic correlation, loss or withdrawal risk.

Sources:

- [Unslashed design](https://medium.com/unslashed/manifesto-for-a-decentralised-crypto-insurance-unslashed-finance-873078fd0ddd)
- [InsurAce overview](https://docs.insurace.io/landing-page/documentation/overview/what-is-insurace)
- [Sherlock documentation](https://github.com/sherlock-protocol/sherlock-docs)
- [Maple defaults and impairments](https://docs.maple.finance/maple-for-lenders/defaults-and-impairments)

### Risk Harbor and Cork

Risk Harbor settled parametric protection by exchanging distressed covered tokens for USDC. Cork's
Swap Token likewise lets its owner exchange the reference asset for collateral before expiry. The
identity is physical settlement: protection plus the impaired asset unlocks collateral.

Cork's May 2025 incident concerned rollover pricing and missing Uniswap v4 hook authorization while
its simpler base module remained intact. The lesson is to prove the fixed-term core before adding AMMs
and automatic rollover.

Sources:

- [Risk Harbor record](https://opencover.com/risk-harbor/)
- [Cork Swap Token](https://docs.cork.tech/core-concepts/swap-token)
- [Cork post-mortem](https://www.cork.tech/blog/post-mortem)

## Wildcat V2 semantics

The inspected baseline is `wildcat-finance/v2-protocol` commit
`c7be4039f8f383a9dda4e45f63331c17d63f9ed9`.

`MarketState.timeDelinquent` counts delinquent seconds. It rises while delinquent and decreases during
a cure. The prototype's threshold is therefore the current net accumulator, not a monotonic lifetime
sum. “Ninety days of penalised delinquency” means grace plus 90 days in that current state.

`currentState()` can calculate the present state, but stock V2 cannot later prove that the threshold
was met before expiry. The prototype gives qualifying default priority at the exact expiry timestamp.
A production deployment still needs a keeper; an overdue checkpoint cannot reconstruct history.

Wildcat balances grow with the scale factor while cover notional is fixed. A 100-unit receipt keeps a
100-unit payout even as its bundled debt accrues. Less than complete coverage of the debt's later value
is normal.

Market transfer hooks may disable or restrict wrapper deposits. The factory verifies the registered
market and canonical wrapper, but a market policy can still make a buyer's fill revert atomically. The
facility uses V2 infrastructure and does not depend on a new singleton role provider.

Sources:

- [MarketState.sol](https://github.com/wildcat-finance/v2-protocol/blob/c7be4039f8f383a9dda4e45f63331c17d63f9ed9/src/libraries/MarketState.sol)
- [FeeMath.sol](https://github.com/wildcat-finance/v2-protocol/blob/c7be4039f8f383a9dda4e45f63331c17d63f9ed9/src/libraries/FeeMath.sol)
- [WildcatMarketBase.sol](https://github.com/wildcat-finance/v2-protocol/blob/c7be4039f8f383a9dda4e45f63331c17d63f9ed9/src/market/WildcatMarketBase.sol)
- [WildcatMarketToken.sol](https://github.com/wildcat-finance/v2-protocol/blob/c7be4039f8f383a9dda4e45f63331c17d63f9ed9/src/market/WildcatMarketToken.sol)

## Adverse selection

Covered-only entry removes traders who cannot tender debt, but an existing lender can still know that
the borrower is deteriorating. The prototype rejects a fill after any nonzero onchain delinquency. It
does not observe private information or offchain distress. A fixed quoted spread also cannot reprice
new information. Auctions, dynamic spreads and dealer markets are separate product experiments.

## Collateral deployment

Aave suppliers can withdraw only while sufficient liquidity is available. Morpho vault liquidity
depends on underlying markets and withdrawal queues. ERC-4626 standardizes vault accounting; it does
not guarantee instant redemption at par.

The implemented compromise keeps cash equal to outstanding receipt supply and allows only excess cash
to enter one immutable vault. A future fill restores cash first. Default never calls the vault.
Terminal settlement sends residual shares to the seller in kind.

Sources:

- [Aave withdrawal behaviour](https://aave.com/help/supplying/withdraw-tokens)
- [MetaMorpho](https://github.com/morpho-org/metamorpho)
- [Morpho Vault V2](https://github.com/morpho-org/vault-v2)
- [ERC-4626](https://eips.ethereum.org/EIPS/eip-4626)

## Alternatives and non-goals

The initial balance-gated cover token, one-buyer receipt, funding-window multi-fill and current
continuous model are compared in [Design evolution](design-evolution.md). The current choice is not
final or inevitable.

The prototype excludes naked protection, fractional-reserve sellers, recovery auctions, dynamic
pricing, AMMs, rollover, portfolio cover, claims governance, upgradeability, a frontend and
deployment. It also excludes investing live claim reserves. Aave V3 requires an adapter; a compatible
ERC-4626 vault can bind directly.

## Risk summary

| Risk | Current control |
| --- | --- |
| Naked claim | Debt and protection stay bundled behind one receipt |
| Late toxic flow | Reject every fill after any nonzero delinquency |
| Split-fill dilution | Cumulative ceiling wrapper-share targets |
| Split-claim recovery avoidance | Cumulative default entitlement |
| Collateral shortfall | Full seller escrow and cash at least equal to live supply |
| Vault illiquidity | Restore before buyer assets; claims never call vault |
| Expiry race | Default priority at equality; keeper still required |
| Inexact tokens | Balance-delta checked transfers |
| Reentrancy | Guarded facility and factory paths; hostile callback tests |
| Missed claim | One-year window, followed by debt-only redemption |
| Regulatory treatment | Prototype warnings and need for jurisdiction-specific advice |

## Repository status

The repository includes contracts, unit and fuzz tests, five stateful invariants, architecture and
operations documents, a worked economic example and generated brand artwork. Review evidence is
recorded in [Validation evidence](validation-evidence.md). None of this is a substitute for an
independent audit, deployment review or legal analysis.
