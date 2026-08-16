# Wildcat covered credit default swaps

![Protected Wildcat debt](docs/bd/assets/covered-debt-hero.png)

One market. One expiry. Cover in any size.

This repository tests fixed-term, fully collateralised credit protection for a single Wildcat V2
market. A seller escrows the maximum payout. Debt holders buy any available amount while enough term
remains for a fresh default, tender the corresponding canonical wrapper shares and pay an upfront
ACT/365 premium for the time left. The facility mints an ERC-20 receipt that carries the debt and
protection together.

The code is a research prototype. It is not deployed, externally audited, production-ready or an
offer of credit protection.

## Why bundle the debt

A balance check can prove that a buyer owns debt at one instant. It cannot stop that debt moving away
later. Here the receipt is the protected position: transferring it transfers both the debt claim and
the right to protection. A former holder cannot keep cover after selling the receipt.

```text
seller collateral + lender wrapper shares + lender premium
                           |
                           v
              transferable protected-debt receipt
                    /                         \
      90 days penalised delinquency       healthy expiry
      par cash to receipt holder          debt back to holder
      debt to recovery beneficiary        collateral back to seller
```

Holders may also `unprotect` before a terminal state. The receipt burns, the corresponding wrapper
shares return to the holder, the same amount of collateral returns to the seller and the premium is
not refunded. This restores raw debt liquidity without leaving detached protection behind.

## Continuous fills

Every facility has one notional cap and one expiry fixed at creation. It has no arbitrary funding
window, finalisation transaction or single-buyer rule. Entry closes at:

```text
expiry - (market grace period + 90 days)
```

Any number of lenders may fill available capacity while:

- the block timestamp is no later than that entry deadline;
- the reference market is not closed;
- the market's current delinquency accumulator is zero; and
- the purchase adds at least one canonical wrapper-share unit; and
- the facility can restore cash reserves to the enlarged receipt supply.

The premium for cover amount `N`, annual spread `s` in basis points and seconds remaining `t` is:

```text
ceil(N * s * t / (10,000 * 365 days))
```

The facility uses a creation-time full-notional wrapper-share budget and cumulative ceiling-rounded
targets. Splitting or reordering fills cannot dilute earlier receipt holders.

![Continuous cover lifecycle](docs/bd/assets/continuous-cover-lifecycle.png)

## Collateral strategy boundary

The no-vault configuration holds all seller collateral as cash. A seller may instead bind one
immutable ERC-4626 vault. Only cash above outstanding receipt supply may enter it. Before a new fill,
the facility restores exact cash backing; a strategy loss or liquidity shortfall rejects the fill
before the buyer's premium or wrapper shares move. Default claims never call the vault.

This is deliberately narrower than deploying live claim reserves. A compatible ERC-4626 vault can be
bound directly. Aave V3 needs an adapter, which is outside this prototype. Terminal settlement sends
residual vault shares to the seller in kind so strategy liquidity cannot block holder debt redemption.

## Default and maturity

Anyone may call `checkpoint`. Default records when the market reports at least
`delinquencyGracePeriod + 90 days` of `timeDelinquent` no later than expiry. At exact expiry, default
has priority if the threshold is met. Otherwise the facility matures. Stock V2 cannot reconstruct a
threshold crossing after the fact, so a live deployment would need a keeper at the expiry boundary.
The derived entry deadline ensures every admitted buyer has at least the full default threshold left.
A tenor that does not exceed that threshold is rejected at creation.

![Default and healthy maturity](docs/bd/assets/default-and-maturity.png)

## Read the repository

- [Research report](docs/research-report.md): prior art, product reasoning and Wildcat semantics
- [Design evolution](docs/design-evolution.md): the models tried, why they changed and when to revisit them
- [Architecture](docs/architecture.md): contracts, accounting and lifecycle
- [Threat model](docs/threat-model.md): trust assumptions and failure modes
- [Product terms](docs/product-terms.md): the prototype's exact commercial boundary
- [Operations checklists](docs/operations-checklists.md): creation through terminal settlement
- [Validation evidence](docs/validation-evidence.md): tests, invariants and release commands
- [BD field kit](docs/bd/README.md): one-page brief, worked example, role briefs and FAQ
- [Historical delivery runbook](docs/runbook.md): the sealed plan before requirements changed

## Toolchain and checks

- Foundry v1.7.1
- Solidity 0.8.28, Cancun, `via_ir`, 200 optimiser runs
- forge-std v1.11.0 at `8e40513d678f392f398620b3ef2b418648b33e89`
- Wildcat V2 at `c7be4039f8f383a9dda4e45f63331c17d63f9ed9`

Clone with submodules, then run the release gate:

```sh
git submodule update --init --recursive
./script/release-gate.sh
```

## Licence

Repository-authored code and documentation are available under the [MIT Licence](LICENSE). Pinned
dependencies retain their own licences.
