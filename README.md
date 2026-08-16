# Wildcat covered credit default swaps

This repository is a research prototype for fixed-term, fully collateralised credit protection on a
single Wildcat V2 market. It is not deployed, audited, production-ready or an offer of credit
protection.

## Product boundary

The selected design is a protected-debt receipt. A protection seller escrows the full payout
notional. One lender fills the offer by depositing the matching Wildcat market debt and paying an
upfront ACT/365 premium. The facility wraps that debt and issues an ERC-20 receipt carrying both the
fixed cover entitlement and beneficial ownership of the debt.

Keeping the two claims together prevents the receipt from becoming naked after transfer. If the
market records at least 90 days of penalised delinquency before expiry, the holder burns receipts for
par and the matching wrapped debt becomes seller recovery. At healthy maturity, the seller takes back
the idle collateral and receipt holders recover their wrapped debt.

The prototype deliberately excludes partial fills, claims committees, external default oracles,
productive collateral, naked cover, AMMs, rollover and deployment tooling. Seller collateral remains
idle because a yield strategy can be illiquid precisely when a claim must pay.

## Repository status

This first step contains only the pinned research scaffold. Facility contracts arrive in the next
delivery step. Start with the [research report](docs/research-report.md), then read the ordered
[delivery runbook](docs/runbook.md).

## Toolchain

- Foundry v1.7.1
- Solidity 0.8.28
- Cancun EVM target
- IR compilation with 200 optimiser runs
- forge-std v1.11.0 at `8e40513d678f392f398620b3ef2b418648b33e89`
- Wildcat V2 at `c7be4039f8f383a9dda4e45f63331c17d63f9ed9`

Clone with submodules and run the same checks as CI:

```sh
git submodule update --init --recursive
./script/check-dependencies.sh
forge build
forge test
./script/check-markdown.sh
```

## Licence

Repository-authored code and documentation are available under the [MIT Licence](LICENSE). Pinned
dependencies retain their own licences.
