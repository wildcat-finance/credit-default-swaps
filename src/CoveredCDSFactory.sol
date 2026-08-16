// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { CoveredCDSFacility } from "./CoveredCDSFacility.sol";
import {
  IERC20Like,
  IERC4626Like,
  IWildcatMarketLike,
  IWildcatWrapperLike,
  IWildcatArchControllerLike,
  IWildcatWrapperFactoryLike
} from "./interfaces/ICoveredCDS.sol";
import { ExactTransfer } from "./libraries/ExactTransfer.sol";

/// @notice Ownerless deployment gate for immutable covered CDS offers.
contract CoveredCDSFactory {
  using ExactTransfer for IERC20Like;

  struct CreateParams {
    address market;
    address wrapper;
    address recoveryBeneficiary;
    address collateralVault;
    uint256 notional;
    uint256 tenor;
    uint256 annualPremiumBips;
  }

  error ZeroAddress();
  error InvalidNotional();
  error InvalidTenor();
  error InvalidPremiumSpread();
  error UnregisteredMarket();
  error NoncanonicalWrapper();
  error InvalidWrapperAsset();
  error InvalidCollateralVaultAsset();
  error InvalidReferenceShareBudget();
  error ZeroDelinquencyFee();
  error ReentrantCall();

  event FacilityCreated(
    address indexed facility, address indexed market, address indexed seller, uint256 notional
  );

  uint256 public constant MAX_TENOR = 10 * 365 days;
  uint256 public constant DEFAULT_DELAY = 90 days;
  uint256 public constant MAX_ANNUAL_PREMIUM_BIPS = 100_000;

  IWildcatArchControllerLike public immutable archController;
  IWildcatWrapperFactoryLike public immutable wrapperFactory;
  address[] public facilities;
  uint256 private _entered = 1;

  constructor(address archController_, address wrapperFactory_) {
    if (archController_ == address(0) || wrapperFactory_ == address(0)) revert ZeroAddress();
    archController = IWildcatArchControllerLike(archController_);
    wrapperFactory = IWildcatWrapperFactoryLike(wrapperFactory_);
  }

  function createFacility(CreateParams calldata params) external returns (address facility) {
    if (_entered != 1) revert ReentrantCall();
    _entered = 2;
    if (params.market == address(0) || params.recoveryBeneficiary == address(0)) {
      revert ZeroAddress();
    }
    if (params.notional == 0) revert InvalidNotional();
    if (params.tenor == 0 || params.tenor > MAX_TENOR) revert InvalidTenor();
    if (params.annualPremiumBips > MAX_ANNUAL_PREMIUM_BIPS) revert InvalidPremiumSpread();
    if (!archController.isRegisteredMarket(params.market)) revert UnregisteredMarket();
    if (
      params.wrapper == address(0)
        || wrapperFactory.wrapperForMarket(params.market) != params.wrapper
    ) {
      revert NoncanonicalWrapper();
    }

    IWildcatMarketLike market = IWildcatMarketLike(params.market);
    IWildcatWrapperLike wrapper = IWildcatWrapperLike(params.wrapper);
    if (wrapper.asset() != params.market) revert InvalidWrapperAsset();
    market.updateState();
    uint256 referenceShareBudget = wrapper.previewWithdraw(params.notional);
    if (referenceShareBudget == 0) revert InvalidReferenceShareBudget();
    if (market.delinquencyFeeBips() == 0) revert ZeroDelinquencyFee();
    if (params.tenor < market.delinquencyGracePeriod() + DEFAULT_DELAY) revert InvalidTenor();
    IERC20Like baseAsset = IERC20Like(market.asset());
    if (address(baseAsset) == address(0)) revert ZeroAddress();
    IERC4626Like collateralVault = IERC4626Like(params.collateralVault);
    if (params.collateralVault != address(0) && collateralVault.asset() != address(baseAsset)) {
      revert InvalidCollateralVaultAsset();
    }

    facility = address(
      new CoveredCDSFacility(
        market,
        wrapper,
        baseAsset,
        collateralVault,
        msg.sender,
        params.recoveryBeneficiary,
        params.notional,
        referenceShareBudget,
        params.tenor,
        params.annualPremiumBips
      )
    );
    baseAsset.pull(msg.sender, facility, params.notional);
    facilities.push(facility);
    _entered = 1;
    emit FacilityCreated(facility, params.market, msg.sender, params.notional);
  }

  function facilitiesLength() external view returns (uint256) {
    return facilities.length;
  }
}
