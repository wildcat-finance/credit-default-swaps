// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC20Like, IWildcatMarketLike, IWildcatWrapperLike } from "./interfaces/ICoveredCDS.sol";
import { ExactTransfer } from "./libraries/ExactTransfer.sol";
import { FullMath } from "./libraries/FullMath.sol";

/// @notice A one-fill, fully collateralised CDS whose receipt keeps debt and cover paired.
contract CoveredCDSFacility {
  using ExactTransfer for IERC20Like;

  enum Lifecycle {
    Offered,
    Active,
    Defaulted,
    Matured,
    Cancelled
  }

  error ZeroAddress();
  error ZeroAmount();
  error WrongLifecycle(Lifecycle expected, Lifecycle actual);
  error NotSeller();
  error NotRecoveryBeneficiary();
  error FundingStillOpen();
  error FundingClosed();
  error MarketAlreadyDelinquent();
  error DefaultNotRecorded();
  error ClaimWindowClosed();
  error ClaimWindowOpen();
  error InsufficientBalance();
  error InsufficientAllowance();
  error InvalidReceiver();
  error ReentrantCall();
  error WrapperShareMismatch(uint256 reported, uint256 received);
  error ReferenceShareMismatch(uint256 pulled, uint256 deposited);
  error InsufficientCollateral(uint256 required, uint256 available);

  event Activated(address indexed buyer, uint256 premium, uint256 wrapperShares, uint256 expiry);
  event DefaultRecorded(uint256 timeDelinquent, uint256 threshold);
  event Matured();
  event Cancelled();
  event Claimed(address indexed owner, address indexed receiver, uint256 amount, uint256 shares);
  event DebtRedeemed(
    address indexed owner, address indexed receiver, uint256 amount, uint256 shares
  );
  event Unprotected(
    address indexed owner, address indexed receiver, uint256 amount, uint256 shares
  );
  event RecoveryWithdrawn(address indexed receiver, uint256 shares);
  event CollateralReleased(uint256 amount);
  event Transfer(address indexed from, address indexed to, uint256 amount);
  event Approval(address indexed owner, address indexed spender, uint256 amount);

  uint256 public constant DEFAULT_DELAY = 90 days;
  uint256 public constant CLAIM_WINDOW = 365 days;
  uint256 private constant PREMIUM_DENOMINATOR = 10_000 * 365 days;

  address public immutable factory;
  IWildcatMarketLike public immutable market;
  IWildcatWrapperLike public immutable wrapper;
  IERC20Like public immutable asset;
  address public immutable seller;
  address public immutable recoveryBeneficiary;
  uint256 public immutable notional;
  uint256 public immutable fundingDeadline;
  uint256 public immutable tenor;
  uint256 public immutable annualPremiumBips;

  Lifecycle public lifecycle;
  uint256 public activatedAt;
  uint256 public expiry;
  uint256 public claimDeadline;
  uint256 public remainingCollateral;
  uint256 public totalPayouts;
  uint256 public remainingHolderShares;
  uint256 public sellerRecoveryShares;
  uint256 public defaultSupply;
  uint256 public defaultHolderShares;
  uint256 public totalRecoverySharesAllocated;
  uint256 public totalSellerReleased;

  string public constant name = "Wildcat Protected Debt";
  string public constant symbol = "wCDS";
  uint8 public immutable decimals;
  uint256 public totalSupply;
  mapping(address => uint256) public balanceOf;
  mapping(address => mapping(address => uint256)) public allowance;

  uint256 private _entered = 1;

  modifier nonReentrant() {
    if (_entered != 1) revert ReentrantCall();
    _entered = 2;
    _;
    _entered = 1;
  }

  constructor(
    IWildcatMarketLike market_,
    IWildcatWrapperLike wrapper_,
    IERC20Like asset_,
    address seller_,
    address recoveryBeneficiary_,
    uint256 notional_,
    uint256 fundingDeadline_,
    uint256 tenor_,
    uint256 annualPremiumBips_
  ) {
    factory = msg.sender;
    market = market_;
    wrapper = wrapper_;
    asset = asset_;
    seller = seller_;
    recoveryBeneficiary = recoveryBeneficiary_;
    notional = notional_;
    fundingDeadline = fundingDeadline_;
    tenor = tenor_;
    annualPremiumBips = annualPremiumBips_;
    remainingCollateral = notional_;
    decimals = market_.decimals();
  }

  function premium() public view returns (uint256) {
    return FullMath.mulDivUp(notional, annualPremiumBips * tenor, PREMIUM_DENOMINATOR);
  }

  function defaultThreshold() public view returns (uint256) {
    return market.delinquencyGracePeriod() + DEFAULT_DELAY;
  }

  function activate() external nonReentrant {
    _requireLifecycle(Lifecycle.Offered);
    if (block.timestamp > fundingDeadline) revert FundingClosed();
    if (market.currentState().timeDelinquent != 0) revert MarketAlreadyDelinquent();
    uint256 collateralBalance = asset.balanceOf(address(this));
    if (collateralBalance < remainingCollateral) {
      revert InsufficientCollateral(remainingCollateral, collateralBalance);
    }

    uint256 premiumAmount = premium();
    if (premiumAmount != 0) asset.pull(msg.sender, seller, premiumAmount);
    uint256 scaledBefore = market.scaledBalanceOf(address(this));
    ExactTransfer.callPull(IERC20Like(address(market)), msg.sender, address(this), notional);
    uint256 scaledReceived = market.scaledBalanceOf(address(this)) - scaledBefore;

    uint256 sharesBefore = wrapper.balanceOf(address(this));
    ExactTransfer.setApproval(IERC20Like(address(market)), address(wrapper), 0);
    ExactTransfer.setApproval(IERC20Like(address(market)), address(wrapper), notional);
    uint256 reportedShares = wrapper.deposit(notional, address(this));
    ExactTransfer.setApproval(IERC20Like(address(market)), address(wrapper), 0);
    uint256 receivedShares = wrapper.balanceOf(address(this)) - sharesBefore;
    if (reportedShares == 0 || receivedShares != reportedShares) {
      revert WrapperShareMismatch(reportedShares, receivedShares);
    }
    if (receivedShares != scaledReceived) {
      revert ReferenceShareMismatch(scaledReceived, receivedShares);
    }

    lifecycle = Lifecycle.Active;
    activatedAt = block.timestamp;
    expiry = block.timestamp + tenor;
    claimDeadline = expiry + CLAIM_WINDOW;
    remainingHolderShares = receivedShares;
    _mint(msg.sender, notional);
    emit Activated(msg.sender, premiumAmount, receivedShares, expiry);
  }

  /// @notice Updates the market, latches default through expiry, or latches healthy maturity after it.
  function checkpoint() external nonReentrant {
    _requireLifecycle(Lifecycle.Active);
    market.updateState();
    uint256 delinquency = market.currentState().timeDelinquent;
    uint256 threshold = defaultThreshold();
    if (block.timestamp <= expiry && delinquency >= threshold) {
      lifecycle = Lifecycle.Defaulted;
      defaultSupply = totalSupply;
      defaultHolderShares = remainingHolderShares;
      emit DefaultRecorded(delinquency, threshold);
    } else if (block.timestamp > expiry) {
      lifecycle = Lifecycle.Matured;
      emit Matured();
    }
  }

  function claim(uint256 amount, address receiver) external nonReentrant {
    _requireLifecycle(Lifecycle.Defaulted);
    if (block.timestamp > claimDeadline) revert ClaimWindowClosed();
    _burn(msg.sender, amount);
    uint256 newTotalPayouts = totalPayouts + amount;
    uint256 targetRecoveryShares = newTotalPayouts == defaultSupply
      ? defaultHolderShares
      : FullMath.mulDiv(defaultHolderShares, newTotalPayouts, defaultSupply);
    uint256 shares = targetRecoveryShares - totalRecoverySharesAllocated;
    remainingCollateral -= amount;
    remainingHolderShares -= shares;
    totalPayouts = newTotalPayouts;
    totalRecoverySharesAllocated = targetRecoveryShares;
    sellerRecoveryShares += shares;
    asset.push(_validReceiver(receiver), amount);
    emit Claimed(msg.sender, receiver, amount, shares);
  }

  /// @notice Burns live protection and returns its debt, releasing the same seller collateral.
  function unprotect(uint256 amount, address receiver) external nonReentrant {
    _requireLifecycle(Lifecycle.Active);
    uint256 shares = _burnAndPartition(msg.sender, amount);
    remainingCollateral -= amount;
    totalSellerReleased += amount;
    IERC20Like(address(wrapper)).push(_validReceiver(receiver), shares);
    asset.push(seller, amount);
    emit Unprotected(msg.sender, receiver, amount, shares);
    emit CollateralReleased(amount);
  }

  /// @notice Returns debt shares after healthy maturity or after an expired default claim window.
  function redeemDebt(uint256 amount, address receiver) external nonReentrant {
    Lifecycle state = lifecycle;
    if (state != Lifecycle.Matured) {
      if (state != Lifecycle.Defaulted) revert WrongLifecycle(Lifecycle.Matured, state);
      if (block.timestamp <= claimDeadline) revert ClaimWindowOpen();
    }
    uint256 shares = _burnAndPartition(msg.sender, amount);
    IERC20Like(address(wrapper)).push(_validReceiver(receiver), shares);
    emit DebtRedeemed(msg.sender, receiver, amount, shares);
  }

  function withdrawRecovery(address receiver) external nonReentrant {
    if (msg.sender != recoveryBeneficiary) revert NotRecoveryBeneficiary();
    uint256 shares = sellerRecoveryShares;
    if (shares == 0) revert ZeroAmount();
    sellerRecoveryShares = 0;
    IERC20Like(address(wrapper)).push(_validReceiver(receiver), shares);
    emit RecoveryWithdrawn(receiver, shares);
  }

  function releaseCollateral() external nonReentrant {
    if (msg.sender != seller) revert NotSeller();
    Lifecycle state = lifecycle;
    if (state == Lifecycle.Defaulted && block.timestamp <= claimDeadline) revert ClaimWindowOpen();
    if (state != Lifecycle.Matured && state != Lifecycle.Defaulted) {
      revert WrongLifecycle(Lifecycle.Matured, state);
    }
    _releaseRemainingCollateral();
  }

  function cancel() external nonReentrant {
    if (msg.sender != seller) revert NotSeller();
    _requireLifecycle(Lifecycle.Offered);
    if (block.timestamp <= fundingDeadline) revert FundingStillOpen();
    lifecycle = Lifecycle.Cancelled;
    _releaseRemainingCollateral();
    emit Cancelled();
  }

  function transfer(address to, uint256 amount) external returns (bool) {
    _transfer(msg.sender, to, amount);
    return true;
  }

  function approve(address spender, uint256 amount) external returns (bool) {
    allowance[msg.sender][spender] = amount;
    emit Approval(msg.sender, spender, amount);
    return true;
  }

  function transferFrom(address from, address to, uint256 amount) external returns (bool) {
    uint256 allowed = allowance[from][msg.sender];
    if (allowed != type(uint256).max) {
      if (allowed < amount) revert InsufficientAllowance();
      unchecked {
        allowance[from][msg.sender] = allowed - amount;
      }
      emit Approval(from, msg.sender, allowance[from][msg.sender]);
    }
    _transfer(from, to, amount);
    return true;
  }

  function _burnAndPartition(address owner, uint256 amount) private returns (uint256 shares) {
    uint256 supply = totalSupply;
    shares = amount == supply
      ? remainingHolderShares
      : FullMath.mulDiv(remainingHolderShares, amount, supply);
    _burn(owner, amount);
    unchecked {
      remainingHolderShares -= shares;
    }
  }

  function _burn(address owner, uint256 amount) private {
    if (amount == 0) revert ZeroAmount();
    uint256 ownerBalance = balanceOf[owner];
    if (ownerBalance < amount) revert InsufficientBalance();
    unchecked {
      balanceOf[owner] = ownerBalance - amount;
      totalSupply -= amount;
    }
    emit Transfer(owner, address(0), amount);
  }

  function _releaseRemainingCollateral() private {
    uint256 amount = remainingCollateral;
    if (amount == 0) revert ZeroAmount();
    remainingCollateral = 0;
    totalSellerReleased += amount;
    asset.push(seller, amount);
    emit CollateralReleased(amount);
  }

  function _mint(address to, uint256 amount) private {
    totalSupply = amount;
    balanceOf[to] = amount;
    emit Transfer(address(0), to, amount);
  }

  function _transfer(address from, address to, uint256 amount) private {
    _validReceiver(to);
    uint256 fromBalance = balanceOf[from];
    if (fromBalance < amount) revert InsufficientBalance();
    unchecked {
      balanceOf[from] = fromBalance - amount;
      balanceOf[to] += amount;
    }
    emit Transfer(from, to, amount);
  }

  function _validReceiver(address receiver) private view returns (address) {
    if (receiver == address(0) || receiver == address(this)) revert InvalidReceiver();
    return receiver;
  }

  function _requireLifecycle(Lifecycle expected) private view {
    if (lifecycle != expected) revert WrongLifecycle(expected, lifecycle);
  }
}
