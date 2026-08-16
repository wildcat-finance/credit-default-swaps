// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { CoveredCDSFacility } from "../src/CoveredCDSFacility.sol";
import { CoveredCDSFactory } from "../src/CoveredCDSFactory.sol";
import { ExactTransfer } from "../src/libraries/ExactTransfer.sol";
import { CoveredCDSTestBase } from "./CoveredCDSTestBase.sol";

contract CoveredCDSFacilityTest is CoveredCDSTestBase {
  function testManyLendersFillContinuouslyAgainstOneShareBudget() public {
    wrapper.setShareRatio(7, 3);
    CoveredCDSFacility facility = _create();
    uint256 first = NOTIONAL / 7;
    uint256 second = NOTIONAL / 3;
    uint256 sellerBefore = baseAsset.balanceOf(seller);

    _fill(facility, lender, first);
    _fill(facility, lender2, second);

    uint256 supply = first + second;
    assertEq(facility.balanceOf(lender), first);
    assertEq(facility.balanceOf(lender2), second);
    assertEq(facility.totalSupply(), supply);
    assertEq(
      wrapper.balanceOf(address(facility)),
      _ceilDiv(facility.referenceShareBudget() * supply, NOTIONAL)
    );
    assertEq(baseAsset.balanceOf(address(facility)), NOTIONAL);
    assertGt(baseAsset.balanceOf(seller), sellerBefore);
    assertEq(uint256(facility.lifecycle()), uint256(CoveredCDSFacility.Lifecycle.Active));
  }

  function testSplitSharesMatchSingleFillAtAnyPoint() public {
    wrapper.setShareRatio(3, 5);
    CoveredCDSFacility split = _create();
    CoveredCDSFacility single = _create();
    uint256 first = 400_000_000_001;
    uint256 second = 199_999_999_999;
    _fill(split, lender, first);
    _fill(split, lender2, second);
    _fill(single, lender, first + second);
    assertEq(wrapper.balanceOf(address(split)), wrapper.balanceOf(address(single)));
  }

  function testPremiumDecaysWithExactTimeRemainingAndSplitCannotReduceIt() public {
    CoveredCDSFacility facility = _create();
    uint256 amount = NOTIONAL / 5;
    uint256 denominator = 10_000 * 365 days;
    uint256 expected = _ceilDiv(amount * SPREAD * TENOR, denominator);
    assertEq(facility.premium(amount), expected);

    uint256 sellerBefore = baseAsset.balanceOf(seller);
    _fill(facility, lender, amount / 2);
    _fill(facility, lender2, amount - amount / 2);
    uint256 splitPremium = baseAsset.balanceOf(seller) - sellerBefore;
    assertGe(splitPremium, expected);

    vm.warp(block.timestamp + 30 days);
    uint256 lateExpected = _ceilDiv(amount * SPREAD * (TENOR - 30 days), denominator);
    assertEq(facility.premium(amount), lateExpected);
    assertLt(lateExpected, expected);
  }

  function testRejectsDelinquentExpiredAndExcessEntry() public {
    CoveredCDSFacility facility = _create();
    market.setTimeDelinquent(1);
    vm.startPrank(lender);
    baseAsset.approve(address(facility), type(uint256).max);
    wrapper.approve(address(facility), type(uint256).max);
    vm.expectRevert(CoveredCDSFacility.MarketAlreadyDelinquent.selector);
    facility.fill(1, lender);
    vm.stopPrank();

    market.setTimeDelinquent(0);
    _fill(facility, lender, NOTIONAL);
    vm.expectRevert(abi.encodeWithSelector(CoveredCDSFacility.CoverUnavailable.selector, 1, 0));
    vm.prank(lender2);
    facility.fill(1, lender2);

    CoveredCDSFacility expired = _create();
    vm.warp(expired.expiry());
    vm.expectRevert(CoveredCDSFacility.Expired.selector);
    vm.prank(lender);
    expired.fill(1, lender);
  }

  function testRejectsClosedMarketEntry() public {
    CoveredCDSFacility facility = _create();
    market.setClosed(true);
    vm.expectRevert(CoveredCDSFacility.MarketClosed.selector);
    vm.prank(lender);
    facility.fill(1, lender);
  }

  function testRejectsPositiveFillWithZeroIncrementalDebtShares() public {
    wrapper.setShareRatio(2, 3);
    CoveredCDSFactory.CreateParams memory params = _params();
    params.notional = 3;
    vm.prank(seller);
    CoveredCDSFacility facility = CoveredCDSFacility(factory.createFacility(params));

    _fill(facility, lender, 1);
    _fill(facility, lender2, 1);
    vm.expectRevert(CoveredCDSFacility.ZeroDebtShareFill.selector);
    vm.prank(alice);
    facility.fill(1, alice);
  }

  function testUnprotectPermanentlyReducesMaximumAndPreservesShareTargetOnRefill() public {
    wrapper.setShareRatio(7, 3);
    CoveredCDSFacility facility = _create();
    uint256 first = NOTIONAL / 2;
    _fill(facility, lender, first);
    uint256 removed = NOTIONAL / 5;

    vm.prank(lender);
    facility.unprotect(removed, lender);
    assertEq(facility.remainingCollateral(), NOTIONAL - removed);
    assertEq(facility.totalSupply(), first - removed);
    assertEq(facility.availableCover(), NOTIONAL - first);

    _fill(facility, lender2, facility.availableCover());
    assertEq(facility.totalSupply(), NOTIONAL - removed);
    assertEq(facility.availableCover(), 0);
    assertEq(
      facility.remainingHolderShares(),
      _ceilDiv(facility.referenceShareBudget() * (NOTIONAL - removed), NOTIONAL)
    );
  }

  function testFullUnprotectReturnsLifecycleToOfferedButNotOriginalCapacity() public {
    CoveredCDSFacility facility = _create();
    _fill(facility, lender, NOTIONAL / 3);
    vm.prank(lender);
    facility.unprotect(NOTIONAL / 3, lender);
    assertEq(uint256(facility.lifecycle()), uint256(CoveredCDSFacility.Lifecycle.Offered));
    assertEq(facility.availableCover(), NOTIONAL - NOTIONAL / 3);
  }

  function testNoVaultLeavesAllSellerCollateralIdleAndLiquid() public {
    CoveredCDSFacility facility = _create();
    assertEq(address(facility.collateralVault()), address(0));
    vm.expectRevert(CoveredCDSFacility.NoCollateralVault.selector);
    facility.allocate(1);
    _fill(facility, lender, NOTIONAL / 2);
    assertEq(baseAsset.balanceOf(address(facility)), NOTIONAL);
    assertGe(baseAsset.balanceOf(address(facility)), facility.totalSupply());
  }

  function testVaultAllocationAndFillRestoreExactClaimCashFirst() public {
    CoveredCDSFacility facility = _createWithVault();
    facility.allocate(NOTIONAL);
    assertEq(baseAsset.balanceOf(address(facility)), 0);
    assertEq(vault.balanceOf(address(facility)), NOTIONAL);

    uint256 amount = NOTIONAL / 4;
    _fill(facility, lender, amount);
    assertEq(baseAsset.balanceOf(address(facility)), amount);
    assertEq(facility.totalSupply(), amount);
    assertEq(vault.balanceOf(address(facility)), NOTIONAL - amount);

    vm.expectRevert(
      abi.encodeWithSelector(CoveredCDSFacility.InsufficientExcessCash.selector, 1, 0)
    );
    facility.allocate(1);
  }

  function testVaultIlliquidityRejectsFillBeforeBuyerAssetsMove() public {
    CoveredCDSFacility facility = _createWithVault();
    facility.allocate(NOTIONAL);
    vault.setWithdrawLimit(0);
    uint256 buyerPremium = baseAsset.balanceOf(lender);
    uint256 buyerShares = wrapper.balanceOf(lender);
    vm.startPrank(lender);
    baseAsset.approve(address(facility), type(uint256).max);
    wrapper.approve(address(facility), type(uint256).max);
    vm.expectRevert(bytes("WITHDRAW_LIMIT"));
    facility.fill(NOTIONAL / 4, lender);
    vm.stopPrank();
    assertEq(baseAsset.balanceOf(lender), buyerPremium);
    assertEq(wrapper.balanceOf(lender), buyerShares);
    assertEq(facility.totalSupply(), 0);
  }

  function testVaultLossRejectsFillBeforeBuyerAssetsMove() public {
    CoveredCDSFacility facility = _createWithVault();
    facility.allocate(NOTIONAL);
    baseAsset.burn(address(vault), NOTIONAL);
    uint256 buyerPremium = baseAsset.balanceOf(lender);
    uint256 buyerShares = wrapper.balanceOf(lender);
    vm.startPrank(lender);
    baseAsset.approve(address(facility), type(uint256).max);
    wrapper.approve(address(facility), type(uint256).max);
    vm.expectRevert();
    facility.fill(NOTIONAL / 4, lender);
    vm.stopPrank();
    assertEq(baseAsset.balanceOf(lender), buyerPremium);
    assertEq(wrapper.balanceOf(lender), buyerShares);
  }

  function testDefaultClaimsNeverCallVault() public {
    CoveredCDSFacility facility = _createWithVault();
    facility.allocate(NOTIONAL);
    uint256 amount = NOTIONAL / 3;
    _fill(facility, lender, amount);
    vault.setWithdrawLimit(0);
    market.setTimeDelinquent(uint32(facility.defaultThreshold()));
    facility.checkpoint();
    vm.prank(lender);
    facility.claim(amount, lender);
    assertEq(facility.totalPayouts(), amount);
    assertEq(baseAsset.balanceOf(address(facility)), 0);
    assertEq(vault.balanceOf(address(facility)), NOTIONAL - amount);
  }

  function testTerminalReleaseTransfersCashAndIlliquidVaultSharesInKind() public {
    CoveredCDSFacility facility = _createWithVault();
    facility.allocate(NOTIONAL);
    uint256 amount = NOTIONAL / 3;
    _fill(facility, lender, amount);
    baseAsset.mint(address(vault), 100e6);
    vault.setWithdrawLimit(0);
    vm.warp(facility.expiry() + 1);
    facility.checkpoint();

    uint256 sellerCashBefore = baseAsset.balanceOf(seller);
    vm.prank(seller);
    facility.releaseCollateral();
    assertEq(baseAsset.balanceOf(seller), sellerCashBefore + amount);
    assertEq(vault.balanceOf(seller), NOTIONAL - amount);

    vm.prank(lender);
    facility.redeemDebt(amount, lender);
    assertEq(facility.totalSupply(), 0);
  }

  function testVaultCallbacksCannotReenterAllocationOrFill() public {
    CoveredCDSFacility facility = _createWithVault();
    vault.setCallback(address(facility), abi.encodeCall(facility.allocate, (1)), true);
    facility.allocate(NOTIONAL);
    assertFalse(vault.lastCallbackSuccess());

    vault.setCallback(address(facility), abi.encodeCall(facility.fill, (1, lender2)), true);
    _fill(facility, lender, NOTIONAL / 4);
    assertFalse(vault.lastCallbackSuccess());
    assertEq(facility.totalSupply(), NOTIONAL / 4);
  }

  function testPremiumTransferFailureIsAtomic() public {
    CoveredCDSFacility facility = _create();
    baseAsset.setFeeBips(100);
    vm.startPrank(lender);
    baseAsset.approve(address(facility), type(uint256).max);
    wrapper.approve(address(facility), type(uint256).max);
    uint256 expectedPremium = facility.premium(NOTIONAL);
    vm.expectRevert(
      abi.encodeWithSelector(
        ExactTransfer.InexactTransfer.selector,
        address(baseAsset),
        expectedPremium,
        expectedPremium,
        expectedPremium - (expectedPremium * 100) / 10_000
      )
    );
    facility.fill(NOTIONAL, lender);
    vm.stopPrank();
    assertEq(facility.totalSupply(), 0);
    assertEq(wrapper.balanceOf(address(facility)), 0);
  }

  function testDefaultSplitClaimsPartitionAllShares() public {
    wrapper.setShareRatio(3, 2);
    CoveredCDSFacility facility = _create();
    _fill(facility, lender, NOTIONAL / 3);
    _fill(facility, lender2, NOTIONAL - NOTIONAL / 3);
    uint256 shares = facility.referenceShareBudget();
    market.setTimeDelinquent(uint32(facility.defaultThreshold()));
    facility.checkpoint();
    vm.prank(lender);
    facility.claim(NOTIONAL / 3, lender);
    vm.prank(lender2);
    facility.claim(NOTIONAL - NOTIONAL / 3, lender2);
    assertEq(facility.sellerRecoveryShares(), shares);
    assertEq(facility.remainingCollateral(), 0);
  }

  function testPartialDefaultClaimRoundsRecoveryDebtAgainstClaimant() public {
    wrapper.setShareRatio(2, 3);
    CoveredCDSFactory.CreateParams memory params = _params();
    params.notional = 3;
    vm.prank(seller);
    CoveredCDSFacility facility = CoveredCDSFacility(factory.createFacility(params));
    _fill(facility, lender, 3);

    market.setTimeDelinquent(uint32(facility.defaultThreshold()));
    facility.checkpoint();
    vm.prank(lender);
    facility.claim(1, lender);
    assertEq(facility.sellerRecoveryShares(), 1);
    assertEq(facility.remainingHolderShares(), 1);

    vm.warp(facility.claimDeadline() + 1);
    vm.prank(lender);
    facility.redeemDebt(2, lender);
    assertEq(facility.remainingHolderShares(), 0);
  }

  function testTerminalReleaseRecoversVaultYieldAfterAccountingCollateralIsZero() public {
    CoveredCDSFactory.CreateParams memory params = _params();
    params.notional = 1_100;
    params.collateralVault = address(vault);
    vm.prank(seller);
    CoveredCDSFacility facility = CoveredCDSFacility(factory.createFacility(params));
    facility.allocate(1_100);
    baseAsset.mint(address(vault), 110);
    vault.setRate(11, 10);

    _fill(facility, lender, 1_100);
    assertEq(vault.balanceOf(address(facility)), 100);
    vm.prank(lender);
    facility.unprotect(1_100, lender);
    assertEq(facility.remainingCollateral(), 0);

    vm.warp(facility.expiry());
    facility.checkpoint();
    vm.prank(seller);
    facility.releaseCollateral();
    assertEq(vault.balanceOf(seller), 100);
  }

  function testHealthyMaturityReturnsDebtAfterSellerTakesCollateral() public {
    CoveredCDSFacility facility = _create();
    _fill(facility, lender, NOTIONAL / 2);
    vm.warp(facility.expiry());
    facility.checkpoint();
    vm.prank(seller);
    facility.releaseCollateral();
    vm.prank(lender);
    facility.redeemDebt(NOTIONAL / 2, lender);
    assertEq(facility.totalSupply(), 0);
  }

  function testFuzzSplitFillsAlwaysReachSupplyShareTarget(uint96 a, uint96 b) public {
    wrapper.setShareRatio(7, 3);
    CoveredCDSFacility facility = _create();
    a = uint96(bound(a, 1, NOTIONAL - 1));
    b = uint96(bound(b, 1, NOTIONAL - a));
    _fill(facility, lender, a);
    _fill(facility, lender2, b);
    uint256 supply = uint256(a) + b;
    assertEq(
      facility.remainingHolderShares(), _ceilDiv(facility.referenceShareBudget() * supply, NOTIONAL)
    );
  }

  function testFuzzSplittingPremiumCannotReducePayment(uint96 amount, uint96 split) public {
    amount = uint96(bound(amount, 2, NOTIONAL));
    split = uint96(bound(split, 1, amount - 1));
    CoveredCDSFacility facility = _create();
    uint256 whole = facility.premium(amount);
    uint256 pieces = facility.premium(split) + facility.premium(amount - split);
    assertGe(pieces, whole);
  }

  function _ceilDiv(uint256 numerator, uint256 denominator) private pure returns (uint256) {
    return (numerator + denominator - 1) / denominator;
  }
}
