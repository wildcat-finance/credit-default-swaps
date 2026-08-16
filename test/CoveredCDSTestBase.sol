// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";

import { CoveredCDSFactory } from "../src/CoveredCDSFactory.sol";
import { CoveredCDSFacility } from "../src/CoveredCDSFacility.sol";
import {
  MockERC20,
  MockMarket,
  MockWrapper,
  MockVault,
  MockArchController,
  MockWrapperFactory
} from "./mocks/MockTokens.sol";

abstract contract CoveredCDSTestBase is Test {
  uint256 internal constant NOTIONAL = 1_000_000e6;
  uint256 internal constant TENOR = 180 days;
  uint256 internal constant SPREAD = 750;

  address internal seller = makeAddr("seller");
  address internal lender = makeAddr("lender");
  address internal lender2 = makeAddr("lender2");
  address internal alice = makeAddr("alice");
  address internal recovery = makeAddr("recovery");

  MockERC20 internal baseAsset;
  MockMarket internal market;
  MockWrapper internal wrapper;
  MockVault internal vault;
  MockArchController internal archController;
  MockWrapperFactory internal wrapperFactory;
  CoveredCDSFactory internal factory;

  function setUp() public virtual {
    baseAsset = new MockERC20("Mock USD", "mUSD", 6);
    market = new MockMarket(address(baseAsset));
    wrapper = new MockWrapper(address(market));
    vault = new MockVault(address(baseAsset));
    archController = new MockArchController();
    wrapperFactory = new MockWrapperFactory();
    archController.setRegistered(address(market), true);
    wrapperFactory.setWrapper(address(market), address(wrapper));
    factory = new CoveredCDSFactory(address(archController), address(wrapperFactory));
    baseAsset.mint(seller, 2 * NOTIONAL);
    baseAsset.mint(lender, NOTIONAL);
    baseAsset.mint(lender2, NOTIONAL);
    wrapper.mint(lender, 10 * NOTIONAL);
    wrapper.mint(lender2, 10 * NOTIONAL);
    vm.prank(seller);
    baseAsset.approve(address(factory), type(uint256).max);
  }

  function _params() internal view returns (CoveredCDSFactory.CreateParams memory params) {
    params = CoveredCDSFactory.CreateParams({
      market: address(market),
      wrapper: address(wrapper),
      recoveryBeneficiary: recovery,
      collateralVault: address(0),
      notional: NOTIONAL,
      tenor: TENOR,
      annualPremiumBips: SPREAD
    });
  }

  function _create() internal returns (CoveredCDSFacility facility) {
    vm.prank(seller);
    facility = CoveredCDSFacility(factory.createFacility(_params()));
  }

  function _createWithVault() internal returns (CoveredCDSFacility facility) {
    CoveredCDSFactory.CreateParams memory params = _params();
    params.collateralVault = address(vault);
    vm.prank(seller);
    facility = CoveredCDSFacility(factory.createFacility(params));
  }

  function _fill(CoveredCDSFacility facility, address buyer, uint256 amount) internal {
    vm.startPrank(buyer);
    baseAsset.approve(address(facility), type(uint256).max);
    wrapper.approve(address(facility), type(uint256).max);
    facility.fill(amount, buyer);
    vm.stopPrank();
  }

  function _activate(CoveredCDSFacility facility) internal {
    _fill(facility, lender, NOTIONAL);
  }
}
