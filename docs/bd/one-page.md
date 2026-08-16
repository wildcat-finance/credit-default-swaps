# Covered Wildcat debt in one page

A seller posts the maximum cash payout for one Wildcat market and fixes an expiry and annual spread.
Debt holders can buy any available cover until market grace plus 90 days before expiry. Each buyer
tenders canonical wrapper shares and pays only for the time remaining.

The buyer receives a transferable ERC-20 protected-debt receipt. It is useful as one priced position:
the debt and cover cannot drift into different wallets. If 90 days of penalised delinquency is
recorded onchain before expiry, the holder burns for par and the debt passes to seller recovery. At a
healthy expiry, the seller recovers collateral and holders redeem the debt.

Before settlement, a holder can burn to return to raw wrapper debt. Equal cover collateral returns to
the seller and the premium stays paid.

Seller collateral is fully funded. An optional ERC-4626 vault can use only capacity not backing sold
cover. Existing claims remain cash-backed. This is a prototype, not a deployed product.
