// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";

import { CoveredCDSFactory } from "../src/CoveredCDSFactory.sol";
import { CoveredCDSFacility } from "../src/CoveredCDSFacility.sol";
import {
  MockERC20,
  MockMarket,
  MockWrapper,
  MockArchController,
  MockWrapperFactory
} from "./mocks/MockTokens.sol";

abstract contract CoveredCDSTestBase is Test {
  uint256 internal constant NOTIONAL = 1_000_000e6;
  uint256 internal constant TENOR = 180 days;
  uint256 internal constant SPREAD = 750;

  address internal seller = makeAddr("seller");
  address internal lender = makeAddr("lender");
  address internal alice = makeAddr("alice");
  address internal recovery = makeAddr("recovery");

  MockERC20 internal baseAsset;
  MockMarket internal market;
  MockWrapper internal wrapper;
  MockArchController internal archController;
  MockWrapperFactory internal wrapperFactory;
  CoveredCDSFactory internal factory;

  function setUp() public virtual {
    baseAsset = new MockERC20("Mock USD", "mUSD", 6);
    market = new MockMarket(address(baseAsset));
    wrapper = new MockWrapper(address(market));
    archController = new MockArchController();
    wrapperFactory = new MockWrapperFactory();
    archController.setRegistered(address(market), true);
    wrapperFactory.setWrapper(address(market), address(wrapper));
    factory = new CoveredCDSFactory(address(archController), address(wrapperFactory));
    baseAsset.mint(seller, 2 * NOTIONAL);
    baseAsset.mint(lender, NOTIONAL);
    market.mint(lender, 2 * NOTIONAL);
    vm.prank(seller);
    baseAsset.approve(address(factory), type(uint256).max);
  }

  function _params() internal view returns (CoveredCDSFactory.CreateParams memory params) {
    params = CoveredCDSFactory.CreateParams({
      market: address(market),
      wrapper: address(wrapper),
      recoveryBeneficiary: recovery,
      notional: NOTIONAL,
      fundingDeadline: block.timestamp + 7 days,
      tenor: TENOR,
      annualPremiumBips: SPREAD
    });
  }

  function _create() internal returns (CoveredCDSFacility facility) {
    vm.prank(seller);
    facility = CoveredCDSFacility(factory.createFacility(_params()));
  }

  function _activate(CoveredCDSFacility facility) internal {
    vm.startPrank(lender);
    baseAsset.approve(address(facility), type(uint256).max);
    market.approve(address(facility), type(uint256).max);
    facility.activate();
    vm.stopPrank();
  }
}
