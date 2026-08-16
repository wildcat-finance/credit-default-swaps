// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";

import { CoveredCDSFacility } from "../../src/CoveredCDSFacility.sol";
import { CoveredCDSTestBase } from "../CoveredCDSTestBase.sol";
import { MockERC20, MockMarket, MockWrapper } from "../mocks/MockTokens.sol";

contract FacilityHandler is Test {
  CoveredCDSFacility public immutable facility;
  MockMarket public immutable market;
  address public immutable lender;
  address public immutable alice;
  address public immutable seller;
  address public immutable recovery;

  constructor(
    CoveredCDSFacility facility_,
    MockMarket market_,
    address lender_,
    address alice_,
    address seller_,
    address recovery_
  ) {
    facility = facility_;
    market = market_;
    lender = lender_;
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

  function moveReceipt(bool fromLender, uint256 amount) external {
    address from = fromLender ? lender : alice;
    address to = fromLender ? alice : lender;
    amount = bound(amount, 0, facility.balanceOf(from));
    vm.prank(from);
    try facility.transfer(to, amount) { } catch { }
  }

  function claim(bool asLender, uint256 amount) external {
    address holder = asLender ? lender : alice;
    uint256 balance = facility.balanceOf(holder);
    if (balance == 0) return;
    amount = bound(amount, 1, balance);
    vm.prank(holder);
    try facility.claim(amount, holder) { } catch { }
  }

  function redeem(bool asLender, uint256 amount) external {
    address holder = asLender ? lender : alice;
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
}

contract CoveredCDSInvariantTest is CoveredCDSTestBase {
  CoveredCDSFacility internal facility;
  FacilityHandler internal handler;

  function setUp() public override {
    super.setUp();
    wrapper.setShareRatio(7, 3);
    facility = _create();
    _activate(facility);
    handler = new FacilityHandler(facility, market, lender, alice, seller, recovery);
    targetContract(address(handler));
  }

  function invariantCollateralIsFullyAccounted() public view {
    assertEq(
      facility.totalPayouts() + facility.remainingCollateral() + facility.totalSellerReleased(),
      NOTIONAL
    );
    assertLe(facility.totalPayouts(), NOTIONAL);
    assertEq(baseAsset.balanceOf(address(facility)), facility.remainingCollateral());
  }

  function invariantWrapperSharesRemainPartitioned() public view {
    assertEq(
      wrapper.balanceOf(address(facility)),
      facility.remainingHolderShares() + facility.sellerRecoveryShares()
    );
  }

  function invariantReceiptSupplyMatchesBalances() public view {
    assertEq(facility.totalSupply(), facility.balanceOf(lender) + facility.balanceOf(alice));
    assertLe(facility.totalSupply(), NOTIONAL);
  }
}
