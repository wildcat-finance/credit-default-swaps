// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";

import { CoveredCDSFacility } from "../../src/CoveredCDSFacility.sol";
import { CoveredCDSTestBase } from "../CoveredCDSTestBase.sol";
import { MockERC20, MockMarket } from "../mocks/MockTokens.sol";

contract FacilityHandler is Test {
  CoveredCDSFacility public immutable facility;
  MockMarket public immutable market;
  MockERC20 public immutable baseAsset;
  address public immutable lender;
  address public immutable lender2;
  address public immutable alice;
  address public immutable seller;
  address public immutable recovery;

  constructor(
    CoveredCDSFacility facility_,
    MockMarket market_,
    MockERC20 baseAsset_,
    address lender_,
    address lender2_,
    address alice_,
    address seller_,
    address recovery_
  ) {
    facility = facility_;
    market = market_;
    baseAsset = baseAsset_;
    lender = lender_;
    lender2 = lender2_;
    alice = alice_;
    seller = seller_;
    recovery = recovery_;
  }

  function advance(uint256 elapsed) external {
    vm.warp(block.timestamp + bound(elapsed, 0, 30 days));
  }

  function setDelinquency(uint32 elapsed) external {
    market.setTimeDelinquent(elapsed);
  }

  function checkpoint() external {
    try facility.checkpoint() { } catch { }
  }

  function fill(uint8 buyerSeed, uint256 amount) external {
    CoveredCDSFacility.Lifecycle state = facility.lifecycle();
    if (
      (state != CoveredCDSFacility.Lifecycle.Offered
          && state != CoveredCDSFacility.Lifecycle.Active)
        || block.timestamp > facility.entryDeadline()
    ) return;
    uint256 available = facility.availableCover();
    if (available == 0) return;
    amount = bound(amount, 1, available);
    address buyer = buyerSeed % 2 == 0 ? lender : lender2;
    vm.prank(buyer);
    try facility.fill(amount, buyer) { } catch { }
  }

  function allocate(uint256 amount) external {
    CoveredCDSFacility.Lifecycle state = facility.lifecycle();
    if (
      (state != CoveredCDSFacility.Lifecycle.Offered
          && state != CoveredCDSFacility.Lifecycle.Active) || block.timestamp >= facility.expiry()
    ) return;
    uint256 cash = baseAsset.balanceOf(address(facility));
    uint256 supply = facility.totalSupply();
    if (cash <= supply) return;
    amount = bound(amount, 1, cash - supply);
    try facility.allocate(amount) { } catch { }
  }

  function moveReceipt(uint8 route, uint256 amount) external {
    address from = route % 3 == 0 ? lender : route % 3 == 1 ? lender2 : alice;
    address to = route % 3 == 0 ? alice : route % 3 == 1 ? lender : lender2;
    amount = bound(amount, 0, facility.balanceOf(from));
    vm.prank(from);
    try facility.transfer(to, amount) { } catch { }
  }

  function claim(uint8 holderSeed, uint256 amount) external {
    address holder = _holder(holderSeed);
    uint256 balance = facility.balanceOf(holder);
    if (balance == 0) return;
    amount = bound(amount, 1, balance);
    vm.prank(holder);
    try facility.claim(amount, holder) { } catch { }
  }

  function unprotect(uint8 holderSeed, uint256 amount) external {
    address holder = _holder(holderSeed);
    uint256 balance = facility.balanceOf(holder);
    if (balance == 0) return;
    amount = bound(amount, 1, balance);
    vm.prank(holder);
    try facility.unprotect(amount, holder) { } catch { }
  }

  function redeem(uint8 holderSeed, uint256 amount) external {
    address holder = _holder(holderSeed);
    uint256 balance = facility.balanceOf(holder);
    if (balance == 0) return;
    amount = bound(amount, 1, balance);
    vm.prank(holder);
    try facility.redeemDebt(amount, holder) { } catch { }
  }

  function releaseCollateral() external {
    vm.prank(seller);
    try facility.releaseCollateral() { } catch { }
  }

  function withdrawRecovery() external {
    vm.prank(recovery);
    try facility.withdrawRecovery(recovery) { } catch { }
  }

  function _holder(uint8 seed) private view returns (address) {
    return seed % 3 == 0 ? lender : seed % 3 == 1 ? lender2 : alice;
  }
}

contract CoveredCDSInvariantTest is CoveredCDSTestBase {
  CoveredCDSFacility internal facility;
  FacilityHandler internal handler;

  function setUp() public override {
    super.setUp();
    wrapper.setShareRatio(7, 3);
    facility = _createWithVault();
    facility.allocate(NOTIONAL / 2);
    _fill(facility, lender, NOTIONAL / 10);
    _fill(facility, lender2, NOTIONAL / 10);
    handler =
      new FacilityHandler(facility, market, baseAsset, lender, lender2, alice, seller, recovery);
    targetContract(address(handler));
  }

  function invariantCollateralAccountingNeverCreatesNotional() public view {
    assertEq(
      facility.totalPayouts() + facility.remainingCollateral() + facility.totalSellerReleased(),
      NOTIONAL
    );
    assertLe(facility.totalPayouts(), NOTIONAL);
  }

  function invariantSuccessfulOpenCoverAlwaysHasCashReserved() public view {
    CoveredCDSFacility.Lifecycle state = facility.lifecycle();
    if (
      state == CoveredCDSFacility.Lifecycle.Offered || state == CoveredCDSFacility.Lifecycle.Active
        || (state == CoveredCDSFacility.Lifecycle.Defaulted && facility.remainingCollateral() != 0)
    ) {
      assertGe(baseAsset.balanceOf(address(facility)), facility.totalSupply());
    }
  }

  function invariantWrapperSharesRemainPartitioned() public view {
    assertEq(
      wrapper.balanceOf(address(facility)),
      facility.remainingHolderShares() + facility.sellerRecoveryShares()
    );
    assertLe(facility.totalRecoverySharesAllocated(), facility.defaultHolderShares());
  }

  function invariantReceiptSupplyMatchesBalancesAndCapacity() public view {
    assertEq(
      facility.totalSupply(),
      facility.balanceOf(lender) + facility.balanceOf(lender2) + facility.balanceOf(alice)
    );
    if (facility.remainingCollateral() != 0) {
      assertLe(facility.totalSupply(), facility.remainingCollateral());
    }
    CoveredCDSFacility.Lifecycle state = facility.lifecycle();
    if (
      state == CoveredCDSFacility.Lifecycle.Offered || state == CoveredCDSFacility.Lifecycle.Active
    ) {
      if (block.timestamp <= facility.entryDeadline()) {
        assertEq(facility.availableCover(), facility.remainingCollateral() - facility.totalSupply());
      } else {
        assertEq(facility.availableCover(), 0);
      }
    }
  }

  function invariantOpenShareTargetSurvivesFillsAndUnprotection() public view {
    CoveredCDSFacility.Lifecycle state = facility.lifecycle();
    if (
      state == CoveredCDSFacility.Lifecycle.Offered || state == CoveredCDSFacility.Lifecycle.Active
    ) {
      uint256 supply = facility.totalSupply();
      uint256 expected =
        supply == 0 ? 0 : _ceilDiv(facility.referenceShareBudget() * supply, NOTIONAL);
      assertEq(facility.remainingHolderShares(), expected);
    }
  }

  function _ceilDiv(uint256 numerator, uint256 denominator) private pure returns (uint256) {
    return (numerator + denominator - 1) / denominator;
  }
}
