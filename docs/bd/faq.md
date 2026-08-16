# FAQ

## Who can buy cover?

Anyone who can tender the required canonical wrapper shares. Entry rejects any current market
delinquency and stops at expiry.

## Can several lenders use one facility?

Yes. Each chooses an available amount and pays for the exact time left. Very small amounts reject if
they add no canonical wrapper-share unit.

## Can a late fill still default?

Not always. Entry requires zero delinquency. If less than grace plus 90 days remains, that clock
cannot reach the threshold before expiry. The prototype still permits entry as requested, so buyers
must check the remaining trigger horizon rather than relying on the premium quote alone.

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
