#!/usr/bin/env python3
import pathlib

root = pathlib.Path(__file__).resolve().parent.parent
document = (root / "docs/bd/worked-example.md").read_text()
scale = 10**6
denominator = 10_000 * 365

def premium(amount, spread, days):
    numerator = amount * scale * spread * days
    return (numerator + denominator - 1) // denominator

cases = [
    (250_000, 600, 365, "15,000 USDC"),
    (400_000, 600, 275, "18,082.191781 USDC"),
]
for amount, spread, days, rendered in cases:
    value = premium(amount, spread, days)
    expected = f"{value // scale:,}.{value % scale:06d} USDC"
    if value % scale == 0:
        expected = f"{value // scale:,} USDC"
    if expected != rendered or rendered not in document:
        raise SystemExit(f"worked example mismatch: expected {expected}")

print("Worked example arithmetic passed")
