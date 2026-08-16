# Worked example

Assume a 1,000,000 USDC facility, 365-day tenor and 600 basis-point annual spread. For clarity, this
example assumes one wrapper share represents one debt unit. Production quotes use the wrapper's
creation-time `previewWithdraw` result.

## Staggered entry

On day 0, lender A buys 250,000 USDC of cover:

```text
premium = ceil(250,000 * 600 * 365 / (10,000 * 365))
        = 15,000 USDC
```

On day 90, lender B buys 400,000 USDC with 275 days left:

```text
premium = ceil(400,000 * 600 * 275 / (10,000 * 365))
        = 18,082.191781 USDC
```

The receipt supply is 650,000. Facility cash remains at least 650,000. Up to 350,000 of unused capacity
may sit in the optional vault.

## Transfer and unprotection

A transfers 100,000 receipts to C. C now owns the bundled debt and protection; A has no claim on that
portion. A then unprotects 50,000 receipts. A receives the corresponding wrapper shares, 50,000 USDC
returns to the seller and maximum remaining cover falls permanently to 950,000. Supply is 600,000.

## Default outcome

If the market reaches grace plus 90 days of `timeDelinquent` before expiry and anyone checkpoints:

- A, B and C can burn their 600,000 receipts for 600,000 USDC in total;
- the corresponding wrapper shares accrue to seller recovery; and
- the seller later receives unsold collateral and any residual vault shares.

## Healthy outcome

If the threshold is not recorded by expiry:

- the seller releases the remaining collateral and residual vault shares; and
- A, B and C burn receipts to recover the wrapper shares behind their balances.

No premium is refunded in either outcome.
