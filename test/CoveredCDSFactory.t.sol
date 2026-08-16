// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { CoveredCDSFactory } from "../src/CoveredCDSFactory.sol";
import { ExactTransfer } from "../src/libraries/ExactTransfer.sol";
import { CoveredCDSTestBase } from "./CoveredCDSTestBase.sol";
import { MockWrapper } from "./mocks/MockTokens.sol";

contract CoveredCDSFactoryTest is CoveredCDSTestBase {
  function testCreateBindsCanonicalRegisteredMarketAndEscrowsCollateral() public {
    uint256 sellerBefore = baseAsset.balanceOf(seller);
    CoveredCDSFactory.CreateParams memory params = _params();
    vm.prank(seller);
    address facility = factory.createFacility(params);

    assertEq(baseAsset.balanceOf(seller), sellerBefore - NOTIONAL);
    assertEq(baseAsset.balanceOf(facility), NOTIONAL);
    assertEq(factory.facilities(0), facility);
  }

  function testRejectsUnregisteredMarket() public {
    archController.setRegistered(address(market), false);
    vm.expectRevert(CoveredCDSFactory.UnregisteredMarket.selector);
    vm.prank(seller);
    factory.createFacility(_params());
  }

  function testRejectsNoncanonicalOrInvalidWrapper() public {
    CoveredCDSFactory.CreateParams memory params = _params();
    params.wrapper = address(new MockWrapper(address(market)));
    vm.expectRevert(CoveredCDSFactory.NoncanonicalWrapper.selector);
    vm.prank(seller);
    factory.createFacility(params);
  }

  function testRejectsZeroFeeMarketAndInvalidTerms() public {
    market.setDelinquencyFeeBips(0);
    vm.expectRevert(CoveredCDSFactory.ZeroDelinquencyFee.selector);
    vm.prank(seller);
    factory.createFacility(_params());

    market.setDelinquencyFeeBips(500);
    CoveredCDSFactory.CreateParams memory params = _params();
    params.notional = 0;
    vm.expectRevert(CoveredCDSFactory.InvalidNotional.selector);
    vm.prank(seller);
    factory.createFacility(params);
  }

  function testRejectsFeeOnTransferCollateral() public {
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
    vm.prank(seller);
    factory.createFacility(_params());
    assertEq(factory.facilitiesLength(), 0);
  }
}
