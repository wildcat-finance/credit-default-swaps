# Delivery runbook

The repository starts empty. Each step begins from the previous step's pushed branch and ends with a
green, independently reviewable pull request. The branches are stacked because later work depends on
files introduced by earlier steps. Nothing in this runbook authorises a deployment or a production
claim.

## Step 1: Scaffold the research repository

**Goal.** Establish the pinned Foundry project and publish the researched product boundary before any
facility code is added.

**Entry.** Empty `wildcat-finance/credit-default-swaps` repository, local unborn `main`, tracking issue
`#1`, and the receipted study at `.hexaemeron/study.md`.

**Exit.** A repository with `main` bootstrap, Foundry and dependency pins, CI, licence, contribution
checks, a direct README, and committed copies of the study and runbook. `forge build`, the initial
scaffold test, dependency checks and Markdown checks pass.

**Files.** `README.md`, `LICENSE`, `.gitignore`, `.gitmodules`, `foundry.toml`, `remappings.txt`,
`config/dependencies.env`, `.github/workflows/ci.yml`, `script/check-dependencies.sh`,
`script/check-markdown.sh`, `src/Scaffold.sol`, `test/Scaffold.t.sol`, `docs/research-report.md`, and
`docs/runbook.md`.

**Tests.** One scaffold test confirms the compiler, test runner and pinned dependency surface. Shell
checks confirm submodule commits and basic Markdown hygiene.

## Step 2: Implement the protected-debt facility

**Goal.** Implement an ownerless factory and one-shot fully collateralised facility whose ERC-20
receipt keeps Wildcat debt and cover economically paired through maturity or default.

**Entry.** The pushed Step 1 branch, with all scaffold checks green and the exact product terms in
`docs/research-report.md`.

**Exit.** `CoveredCDSFactory` validates the registered market and canonical wrapper, then deploys an
immutable offer. `CoveredCDSFacility` escrows seller collateral, activates only on one full debt fill,
calculates the upfront ACT/365 premium, wraps the debt, records the V2-observable 90-day post-grace
default, pays par against burned receipts, partitions recovery shares, returns wrapped debt at healthy
maturity, and cancels an unfilled offer after deadline. Unit and fuzz tests plus the
`test/invariant/` suite pass under the pinned Foundry profile.

**Files.** `src/CoveredCDSFactory.sol`, `src/CoveredCDSFacility.sol`, narrow interfaces and libraries
under `src/`, mocks under `test/mocks/`, unit and fuzz tests under `test/`, invariant handlers under
`test/invariant/`, and updates to build configuration and validation evidence.

**Tests.** Tests cover factory binding, exact collateral and premium deltas, full activation, rejected
partial and late fills, zero-fee market rejection, threshold boundaries, cure decay, default/expiry
ordering, receipt transfers, partial and final claims, healthy redemptions, recovery withdrawal,
rounding dust, reentrancy attempts against `CoveredCDSFacility.claim`, hostile token deltas and
terminal-state irreversibility. The `test/invariant/` suite conserves seller collateral and wrapper
shares across random lifecycle actions.

## Step 3: Demonstrate and present the prototype

**Goal.** Turn the audited contracts into a reviewable technical and commercial field kit, using the
supplied Wildcat brand system and generated bitmap artwork.

**Entry.** The pushed Step 2 branch, with facility unit and fuzz tests plus `test/invariant/` green and
the audit log closed.

**Exit.** The README runs the complete worked example from offer through healthy maturity and default.
`docs/architecture.md`, `docs/threat-model.md`, validation evidence, product terms, FAQ, lender and
seller briefs, and an operational checklist match the contracts. Generated 1920 x 1080 PNG assets use
the supplied palette
and remain free of embedded economic text. `./script/release-gate.sh` runs dependency checks, the full
Foundry suite, Markdown checks and asset checks successfully.

**Files.** `README.md`, `docs/architecture.md`, `docs/threat-model.md`, `docs/validation-evidence.md`,
`docs/product-terms.md`, `docs/bd/`, generated PNGs in `docs/bd/assets/`, `script/release-gate.sh`,
`script/check-assets.sh`, and any test needed to keep the public worked example executable.

**Tests.** The release gate runs every unit and fuzz test plus `test/invariant/` from Step 2, validates documented
example constants against an executable test, checks Markdown links and shape, and verifies that final
PNG assets are 1920 x 1080. The final demo is the same seller/lender/default path named in the study.

## Delivery order

1. Scaffold the research repository.
2. Implement the protected-debt facility.
3. Demonstrate and present the prototype.

Each step gets its own issue, branch, audit record and pull request. Step issues sit under tracking
issue #1. Pull requests remain unmerged for human review.
