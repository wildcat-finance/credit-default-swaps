# FAQ

## Who can buy cover?

Anyone who can tender the required canonical wrapper shares. Entry rejects any current market
delinquency and stops at the derived entry deadline, market grace plus 90 days before expiry.

## Can several lenders use one facility?

Yes. Each chooses an available amount and pays for the exact time left. Very small amounts reject if
they add no canonical wrapper-share unit.

## Why does entry close before expiry?

Entry requires zero delinquency. Closing at market grace plus 90 days before expiry ensures every
admitted buyer has enough time for a fresh uninterrupted delinquency to reach the credit-event
threshold. The last buyer still pays premium through expiry.

## Is the receipt transferable?

Yes. It transfers the debt claim and cover together. There is no separate cover token to leave behind.

## Can a holder get the raw debt back early?

Yes, through `unprotect`. The same protection amount ends, collateral returns to the seller and no
premium is refunded.

## What triggers default?

The reference market must report `timeDelinquent >= delinquencyGracePeriod + 90 days`, and someone
must checkpoint it no later than expiry.

## Does collateral earn yield?

Only unused capacity may enter the immutable optional ERC-4626 vault. Cash backing live receipts stays
in the facility. A compatible ERC-4626 vault can bind directly. Aave V3 needs an adapter and is not
integrated here.

## Is this naked CDS?

No. Cash settlement burns the receipt whose bundled debt becomes seller recovery. Naked versions are
future work and should be visibly separate.

## Is it live or audited?

No. It is a research prototype with tests and internal review, not a deployment or external audit.
