# Protection seller brief

You choose one market, notional, tenor, annual spread, recovery beneficiary and optional ERC-4626
vault. Creation locks the full notional. Any number of eligible debt holders may buy remaining cover
through the derived entry deadline while the market has zero current delinquency. That deadline leaves
market grace plus 90 days before fixed expiry.

Premium arrives upfront on every fill. Live unprotection returns equal collateral to you and retires
that capacity. On default, cash goes to receipt holders and wrapper debt accrues to the recovery
beneficiary. On healthy maturity, you recover residual cash and any vault shares.

Only capacity above sold cover can be allocated. Vault losses belong to your residual and may prevent
new fills. The contract does not value vault shares or promise their liquidity.
