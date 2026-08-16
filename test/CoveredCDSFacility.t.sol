// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { CoveredCDSFacility } from "../src/CoveredCDSFacility.sol";
import { ExactTransfer } from "../src/libraries/ExactTransfer.sol";
import { CoveredCDSTestBase } from "./CoveredCDSTestBase.sol";

contract CoveredCDSFacilityTest is CoveredCDSTestBase {
  function testActivationMovesExactPremiumAndDebtAndMintsFullReceipt() public {
    CoveredCDSFacility facility = _create();
    uint256 expectedPremium = facility.premium();
    uint256 sellerBefore = baseAsset.balanceOf(seller);
    uint256 lenderBefore = baseAsset.balanceOf(lender);
    _activate(facility);

    assertEq(expectedPremium, 36_986_301_370);
    assertEq(baseAsset.balanceOf(seller), sellerBefore + expectedPremium);
    assertEq(baseAsset.balanceOf(lender), lenderBefore - expectedPremium);
    assertEq(market.balanceOf(lender), NOTIONAL);
    assertEq(market.balanceOf(address(wrapper)), NOTIONAL);
    assertEq(facility.balanceOf(lender), NOTIONAL);
    assertEq(facility.totalSupply(), NOTIONAL);
    assertEq(uint256(facility.lifecycle()), uint256(CoveredCDSFacility.Lifecycle.Active));
  }

  function testActivationRequiresCollateralStillPresent() public {
    CoveredCDSFacility facility = _create();
    baseAsset.burn(address(facility), 1);
    vm.startPrank(lender);
    baseAsset.approve(address(facility), type(uint256).max);
    market.approve(address(facility), type(uint256).max);
    vm.expectRevert(
      abi.encodeWithSelector(
        CoveredCDSFacility.InsufficientCollateral.selector, NOTIONAL, NOTIONAL - 1
      )
    );
    facility.activate();
    vm.stopPrank();
  }

  function testRejectsLateDelinquentAndSecondActivation() public {
    CoveredCDSFacility facility = _create();
    market.setTimeDelinquent(1);
    vm.startPrank(lender);
    baseAsset.approve(address(facility), type(uint256).max);
    market.approve(address(facility), type(uint256).max);
    vm.expectRevert(CoveredCDSFacility.MarketAlreadyDelinquent.selector);
    facility.activate();
    vm.stopPrank();

    market.setTimeDelinquent(0);
    vm.warp(facility.fundingDeadline() + 1);
    vm.expectRevert(CoveredCDSFacility.FundingClosed.selector);
    vm.prank(lender);
    facility.activate();
  }

  function testPremiumOrDebtTransferFailureIsAtomic() public {
    CoveredCDSFacility facility = _create();
    baseAsset.setFeeBips(100);
    vm.startPrank(lender);
    baseAsset.approve(address(facility), type(uint256).max);
    market.approve(address(facility), type(uint256).max);
    uint256 expectedPremium = facility.premium();
    vm.expectRevert(
      abi.encodeWithSelector(
        ExactTransfer.InexactTransfer.selector,
        address(baseAsset),
        expectedPremium,
        expectedPremium,
        expectedPremium - (expectedPremium * 100) / 10_000
      )
    );
    facility.activate();
    vm.stopPrank();
    assertEq(facility.totalSupply(), 0);
    assertEq(market.balanceOf(lender), 2 * NOTIONAL);
  }

  function testDefaultBoundaryCureAndExpiryOrdering() public {
    CoveredCDSFacility facility = _create();
    _activate(facility);
    uint32 threshold = uint32(facility.defaultThreshold());

    market.setTimeDelinquent(threshold - 1);
    facility.checkpoint();
    assertEq(uint256(facility.lifecycle()), uint256(CoveredCDSFacility.Lifecycle.Active));
    market.setTimeDelinquent(0);
    facility.checkpoint();
    assertEq(uint256(facility.lifecycle()), uint256(CoveredCDSFacility.Lifecycle.Active));

    vm.warp(facility.expiry());
    market.setTimeDelinquent(threshold);
    facility.checkpoint();
    assertEq(uint256(facility.lifecycle()), uint256(CoveredCDSFacility.Lifecycle.Defaulted));

    CoveredCDSFacility healthy = _createAndActivateAtCurrentTime();
    vm.warp(healthy.expiry() + 1);
    market.setTimeDelinquent(type(uint32).max);
    healthy.checkpoint();
    assertEq(uint256(healthy.lifecycle()), uint256(CoveredCDSFacility.Lifecycle.Matured));
  }

  function testReceiptTransferPartialAndFinalClaimsPartitionAllShares() public {
    wrapper.setShareRatio(3, 2);
    CoveredCDSFacility facility = _create();
    _activate(facility);
    uint256 initialShares = (NOTIONAL * 3) / 2;
    uint256 aliceAmount = NOTIONAL / 3;
    vm.prank(lender);
    facility.transfer(alice, aliceAmount);

    market.setTimeDelinquent(uint32(facility.defaultThreshold()));
    facility.checkpoint();
    vm.prank(alice);
    facility.claim(aliceAmount, alice);
    assertEq(baseAsset.balanceOf(alice), aliceAmount);
    uint256 aliceShares = (initialShares * aliceAmount) / NOTIONAL;
    assertEq(facility.sellerRecoveryShares(), aliceShares);

    vm.prank(lender);
    facility.claim(NOTIONAL - aliceAmount, lender);
    assertEq(facility.totalPayouts(), NOTIONAL);
    assertEq(facility.remainingCollateral(), 0);
    assertEq(facility.remainingHolderShares(), 0);
    assertEq(facility.sellerRecoveryShares(), initialShares);

    vm.prank(recovery);
    facility.withdrawRecovery(recovery);
    assertEq(wrapper.balanceOf(recovery), initialShares);
  }

  function testSplitClaimsCannotPreserveSellerRecoveryDebt() public {
    wrapper.setShareRatio(3, 5);
    CoveredCDSFacility facility = _create();
    _activate(facility);
    uint256 claimed = 400;
    market.setTimeDelinquent(uint32(facility.defaultThreshold()));
    facility.checkpoint();

    vm.startPrank(lender);
    for (uint256 i; i < claimed; ++i) {
      facility.claim(1, lender);
    }
    vm.stopPrank();

    assertEq(facility.sellerRecoveryShares(), (claimed * 3) / 5);
    assertEq(facility.totalRecoverySharesAllocated(), (claimed * 3) / 5);
    assertEq(facility.remainingHolderShares(), (NOTIONAL * 3) / 5 - (claimed * 3) / 5);
  }

  function testUnprotectReturnsDebtAndReleasesMatchingCollateral() public {
    wrapper.setShareRatio(3, 5);
    CoveredCDSFacility facility = _create();
    _activate(facility);
    uint256 amount = NOTIONAL / 4;
    uint256 sellerBefore = baseAsset.balanceOf(seller);

    vm.prank(lender);
    facility.unprotect(amount, lender);

    assertEq(facility.totalSupply(), NOTIONAL - amount);
    assertEq(facility.remainingCollateral(), NOTIONAL - amount);
    assertEq(wrapper.balanceOf(lender), (amount * 3) / 5);
    assertEq(baseAsset.balanceOf(seller), sellerBefore + amount);

    market.setTimeDelinquent(uint32(facility.defaultThreshold()));
    facility.checkpoint();
    vm.expectRevert(
      abi.encodeWithSelector(
        CoveredCDSFacility.WrongLifecycle.selector,
        CoveredCDSFacility.Lifecycle.Active,
        CoveredCDSFacility.Lifecycle.Defaulted
      )
    );
    vm.prank(lender);
    facility.unprotect(1, lender);
  }

  function testHealthyMaturityReturnsCollateralAndAllDebtShareDust() public {
    wrapper.setShareRatio(7, 3);
    CoveredCDSFacility facility = _create();
    _activate(facility);
    uint256 shares = (NOTIONAL * 7) / 3;
    vm.prank(lender);
    facility.transfer(alice, 1);

    vm.warp(facility.expiry() + 1);
    facility.checkpoint();
    vm.prank(seller);
    facility.releaseCollateral();
    vm.prank(alice);
    facility.redeemDebt(1, alice);
    vm.prank(lender);
    facility.redeemDebt(NOTIONAL - 1, lender);

    assertEq(baseAsset.balanceOf(address(facility)), 0);
    assertEq(wrapper.balanceOf(alice) + wrapper.balanceOf(lender), shares);
    assertEq(facility.remainingHolderShares(), 0);
  }

  function testCancelOnlyAfterDeadlineReturnsCollateral() public {
    CoveredCDSFacility facility = _create();
    vm.expectRevert(CoveredCDSFacility.FundingStillOpen.selector);
    vm.prank(seller);
    facility.cancel();
    vm.warp(facility.fundingDeadline() + 1);
    vm.prank(seller);
    facility.cancel();
    assertEq(baseAsset.balanceOf(address(facility)), 0);
    assertEq(uint256(facility.lifecycle()), uint256(CoveredCDSFacility.Lifecycle.Cancelled));
  }

  function testClaimReentrancyIsRejectedWithoutBlockingPayout() public {
    CoveredCDSFacility facility = _create();
    _activate(facility);
    market.setTimeDelinquent(uint32(facility.defaultThreshold()));
    facility.checkpoint();
    baseAsset.setCallback(address(facility), abi.encodeCall(facility.claim, (1, lender)), true);
    vm.prank(lender);
    facility.claim(NOTIONAL, lender);
    assertFalse(baseAsset.lastCallbackSuccess());
    assertEq(facility.totalPayouts(), NOTIONAL);
  }

  function testHostilePayoutFailureRestoresClaimAccounting() public {
    CoveredCDSFacility facility = _create();
    _activate(facility);
    market.setTimeDelinquent(uint32(facility.defaultThreshold()));
    facility.checkpoint();
    baseAsset.setFeeBips(100);
    vm.expectRevert(
      abi.encodeWithSelector(
        ExactTransfer.InexactTransfer.selector,
        address(baseAsset),
        NOTIONAL,
        NOTIONAL,
        (NOTIONAL * 99) / 100
      )
    );
    vm.prank(lender);
    facility.claim(NOTIONAL, lender);
    assertEq(facility.balanceOf(lender), NOTIONAL);
    assertEq(facility.remainingCollateral(), NOTIONAL);
    assertEq(facility.totalPayouts(), 0);
  }

  function testExpiredClaimReturnsDebtAndLetsSellerReleaseUnusedCollateral() public {
    CoveredCDSFacility facility = _create();
    _activate(facility);
    market.setTimeDelinquent(uint32(facility.defaultThreshold()));
    facility.checkpoint();
    vm.warp(facility.claimDeadline() + 1);
    vm.prank(lender);
    facility.redeemDebt(NOTIONAL, lender);
    vm.prank(seller);
    facility.releaseCollateral();
    assertEq(facility.totalSupply(), 0);
    assertEq(facility.totalSellerReleased(), NOTIONAL);
  }

  function testFuzzPremiumRoundsUp(uint96 notional_, uint24 spread_, uint32 tenor_) public pure {
    notional_ = uint96(bound(notional_, 1, type(uint96).max));
    spread_ = uint24(bound(spread_, 1, 100_000));
    tenor_ = uint32(bound(tenor_, 1, 10 * 365 days));
    uint256 numerator = uint256(notional_) * spread_ * tenor_;
    uint256 denominator = 10_000 * 365 days;
    uint256 expected = (numerator + denominator - 1) / denominator;
    assertGe(expected, 1);
  }

  function testFuzzPartialClaimConservesCollateralAndShares(uint256 amount) public {
    wrapper.setShareRatio(7, 3);
    CoveredCDSFacility facility = _create();
    _activate(facility);
    market.setTimeDelinquent(uint32(facility.defaultThreshold()));
    facility.checkpoint();
    amount = bound(amount, 1, NOTIONAL);
    uint256 initialShares = (NOTIONAL * 7) / 3;
    vm.prank(lender);
    facility.claim(amount, lender);

    assertEq(facility.totalPayouts() + facility.remainingCollateral(), NOTIONAL);
    assertEq(facility.remainingHolderShares() + facility.sellerRecoveryShares(), initialShares);
    assertEq(facility.totalSupply(), NOTIONAL - amount);
  }

  function _createAndActivateAtCurrentTime() private returns (CoveredCDSFacility facility) {
    market.setTimeDelinquent(0);
    facility = _create();
    _activate(facility);
  }
}
