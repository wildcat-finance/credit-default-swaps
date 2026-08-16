// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { CoveredCDSFactory } from "../src/CoveredCDSFactory.sol";
import { CoveredCDSFacility } from "../src/CoveredCDSFacility.sol";
import { ExactTransfer } from "../src/libraries/ExactTransfer.sol";
import { CoveredCDSTestBase } from "./CoveredCDSTestBase.sol";
import { MockERC20, MockWrapper, MockVault } from "./mocks/MockTokens.sol";

contract CoveredCDSFactoryTest is CoveredCDSTestBase {
  function testCreateBindsCanonicalRegisteredMarketAndEscrowsCollateral() public {
    uint256 sellerBefore = baseAsset.balanceOf(seller);
    CoveredCDSFactory.CreateParams memory params = _params();
    vm.prank(seller);
    address facility = factory.createFacility(params);

    assertEq(baseAsset.balanceOf(seller), sellerBefore - NOTIONAL);
    assertEq(baseAsset.balanceOf(facility), NOTIONAL);
    assertEq(factory.facilities(0), facility);
    assertEq(CoveredCDSFacility(facility).referenceShareBudget(), NOTIONAL);
    assertEq(CoveredCDSFacility(facility).expiry(), block.timestamp + TENOR);
    assertEq(
      CoveredCDSFacility(facility).entryDeadline(),
      block.timestamp + TENOR - market.delinquencyGracePeriod() - 90 days
    );
  }

  function testRejectsUnregisteredMarket() public {
    archController.setRegistered(address(market), false);
    vm.expectRevert(CoveredCDSFactory.UnregisteredMarket.selector);
    vm.prank(seller);
    factory.createFacility(_params());
  }

  function testRejectsClosedMarket() public {
    market.setClosed(true);
    vm.expectRevert(CoveredCDSFactory.MarketClosed.selector);
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

    params = _params();
    params.tenor = market.delinquencyGracePeriod() + 90 days;
    vm.expectRevert(CoveredCDSFactory.InvalidTenor.selector);
    vm.prank(seller);
    factory.createFacility(params);

    params.tenor -= 1;
    vm.expectRevert(CoveredCDSFactory.InvalidTenor.selector);
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

  function testSnapshotsReferenceShareBudgetAndRejectsZeroPreview() public {
    wrapper.setShareRatio(7, 3);
    CoveredCDSFacility facility = _create();
    assertEq(facility.referenceShareBudget(), (NOTIONAL * 7 + 2) / 3);

    wrapper.setShareRatio(0, 1);
    vm.expectRevert(CoveredCDSFactory.InvalidReferenceShareBudget.selector);
    vm.prank(seller);
    factory.createFacility(_params());
  }

  function testShareBudgetRoundsUpEnoughToWithdrawFullNotional() public {
    wrapper.setShareRatio(2, 3);
    CoveredCDSFactory.CreateParams memory params = _params();
    params.notional = 1;
    vm.prank(seller);
    CoveredCDSFacility facility = CoveredCDSFacility(factory.createFacility(params));
    assertEq(wrapper.previewDeposit(1), 0);
    assertEq(facility.referenceShareBudget(), 1);
  }

  function testValidatesOptionalVaultAsset() public {
    MockERC20 otherAsset = new MockERC20("Other", "OTHER", 6);
    MockVault wrongVault = new MockVault(address(otherAsset));
    CoveredCDSFactory.CreateParams memory params = _params();
    params.collateralVault = address(wrongVault);
    vm.expectRevert(CoveredCDSFactory.InvalidCollateralVaultAsset.selector);
    vm.prank(seller);
    factory.createFacility(params);

    params.collateralVault = address(vault);
    vm.prank(seller);
    CoveredCDSFacility facility = CoveredCDSFacility(factory.createFacility(params));
    assertEq(address(facility.collateralVault()), address(vault));
  }
}
