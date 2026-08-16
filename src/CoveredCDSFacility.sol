// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {
  IERC20Like,
  IERC4626Like,
  IWildcatMarketLike,
  IWildcatWrapperLike
} from "./interfaces/ICoveredCDS.sol";
import { MarketState } from "v2-protocol/libraries/MarketState.sol";
import { ExactTransfer } from "./libraries/ExactTransfer.sol";
import { FullMath } from "./libraries/FullMath.sol";

/// @notice A continuously fillable, fully collateralised CDS whose receipt bundles debt and cover.
contract CoveredCDSFacility {
  using ExactTransfer for IERC20Like;

  enum Lifecycle {
    Offered,
    Active,
    Defaulted,
    Matured
  }

  error ZeroAmount();
  error WrongLifecycle(Lifecycle expected, Lifecycle actual);
  error NotSeller();
  error NotRecoveryBeneficiary();
  error Expired();
  error CoverUnavailable(uint256 requested, uint256 available);
  error MarketAlreadyDelinquent();
  error MarketClosed();
  error ZeroDebtShareFill();
  error ClaimWindowClosed();
  error ClaimWindowOpen();
  error InsufficientBalance();
  error InsufficientAllowance();
  error InvalidReceiver();
  error ReentrantCall();
  error NoCollateralVault();
  error InsufficientCollateral(uint256 required, uint256 available);
  error InsufficientExcessCash(uint256 requested, uint256 available);
  error VaultDepositMismatch(uint256 reportedShares, uint256 receivedShares, uint256 spentAssets);
  error VaultWithdrawalMismatch(
    uint256 reportedShares, uint256 burnedShares, uint256 receivedAssets
  );

  event Filled(
    address indexed buyer,
    address indexed receiver,
    uint256 coverAmount,
    uint256 premium,
    uint256 wrapperShares,
    uint256 supply
  );
  event CollateralAllocated(uint256 assets, uint256 shares);
  event DefaultRecorded(uint256 timeDelinquent, uint256 threshold);
  event Matured();
  event Claimed(address indexed owner, address indexed receiver, uint256 amount, uint256 shares);
  event DebtRedeemed(
    address indexed owner, address indexed receiver, uint256 amount, uint256 shares
  );
  event Unprotected(
    address indexed owner, address indexed receiver, uint256 amount, uint256 shares
  );
  event RecoveryWithdrawn(address indexed receiver, uint256 shares);
  event CollateralReleased(uint256 accountingAmount, uint256 cash, uint256 vaultShares);
  event Transfer(address indexed from, address indexed to, uint256 amount);
  event Approval(address indexed owner, address indexed spender, uint256 amount);

  uint256 public constant DEFAULT_DELAY = 90 days;
  uint256 public constant CLAIM_WINDOW = 365 days;
  uint256 private constant PREMIUM_DENOMINATOR = 10_000 * 365 days;

  address public immutable factory;
  IWildcatMarketLike public immutable market;
  IWildcatWrapperLike public immutable wrapper;
  IERC20Like public immutable asset;
  IERC4626Like public immutable collateralVault;
  address public immutable seller;
  address public immutable recoveryBeneficiary;
  uint256 public immutable notional;
  uint256 public immutable referenceShareBudget;
  uint256 public immutable tenor;
  uint256 public immutable annualPremiumBips;
  uint256 public immutable expiry;
  uint256 public immutable claimDeadline;

  Lifecycle public lifecycle;
  uint256 public totalFilled;
  uint256 public totalPremiumPaid;
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
    IERC4626Like collateralVault_,
    address seller_,
    address recoveryBeneficiary_,
    uint256 notional_,
    uint256 referenceShareBudget_,
    uint256 tenor_,
    uint256 annualPremiumBips_
  ) {
    factory = msg.sender;
    market = market_;
    wrapper = wrapper_;
    asset = asset_;
    collateralVault = collateralVault_;
    seller = seller_;
    recoveryBeneficiary = recoveryBeneficiary_;
    notional = notional_;
    referenceShareBudget = referenceShareBudget_;
    tenor = tenor_;
    annualPremiumBips = annualPremiumBips_;
    expiry = block.timestamp + tenor_;
    claimDeadline = block.timestamp + tenor_ + CLAIM_WINDOW;
    remainingCollateral = notional_;
    decimals = market_.decimals();
  }

  function availableCover() public view returns (uint256) {
    return remainingCollateral > totalSupply ? remainingCollateral - totalSupply : 0;
  }

  function premium(uint256 coverAmount) public view returns (uint256) {
    if (block.timestamp >= expiry) return 0;
    return FullMath.mulDivUp(
      coverAmount, annualPremiumBips * (expiry - block.timestamp), PREMIUM_DENOMINATOR
    );
  }

  function defaultThreshold() public view returns (uint256) {
    return market.delinquencyGracePeriod() + DEFAULT_DELAY;
  }

  /// @notice Buys cover until expiry by tendering the associated canonical wrapper shares.
  function fill(uint256 coverAmount, address receiver) external nonReentrant {
    Lifecycle state = lifecycle;
    if (state != Lifecycle.Offered && state != Lifecycle.Active) {
      revert WrongLifecycle(Lifecycle.Active, state);
    }
    if (block.timestamp >= expiry) revert Expired();
    if (coverAmount == 0) revert ZeroAmount();
    receiver = _validReceiver(receiver);

    market.updateState();
    MarketState memory marketState = market.currentState();
    if (marketState.isClosed) revert MarketClosed();
    if (marketState.timeDelinquent != 0) revert MarketAlreadyDelinquent();

    uint256 capacity = availableCover();
    if (coverAmount > capacity) revert CoverUnavailable(coverAmount, capacity);
    uint256 newSupply = totalSupply + coverAmount;

    // Restore claim cash before taking either of the buyer's assets.
    _restoreCash(newSupply);

    uint256 shareTarget = _shareTarget(newSupply);
    uint256 shares = shareTarget - remainingHolderShares;
    if (shares == 0) revert ZeroDebtShareFill();
    uint256 premiumAmount = premium(coverAmount);
    if (premiumAmount != 0) asset.pull(msg.sender, seller, premiumAmount);
    if (shares != 0) IERC20Like(address(wrapper)).pull(msg.sender, address(this), shares);

    totalFilled += coverAmount;
    totalPremiumPaid += premiumAmount;
    remainingHolderShares = shareTarget;
    lifecycle = Lifecycle.Active;
    _mint(receiver, coverAmount);
    emit Filled(msg.sender, receiver, coverAmount, premiumAmount, shares, newSupply);
  }

  /// @notice Deposits only cash that is not currently reserved for outstanding claims.
  function allocate(uint256 assets) external nonReentrant {
    Lifecycle state = lifecycle;
    if (state != Lifecycle.Offered && state != Lifecycle.Active) {
      revert WrongLifecycle(Lifecycle.Active, state);
    }
    if (block.timestamp >= expiry) revert Expired();
    if (address(collateralVault) == address(0)) revert NoCollateralVault();
    if (assets == 0) revert ZeroAmount();
    uint256 cash = asset.balanceOf(address(this));
    uint256 excess = cash > totalSupply ? cash - totalSupply : 0;
    if (assets > excess) revert InsufficientExcessCash(assets, excess);

    uint256 sharesBefore = collateralVault.balanceOf(address(this));
    ExactTransfer.setApproval(asset, address(collateralVault), 0);
    ExactTransfer.setApproval(asset, address(collateralVault), assets);
    uint256 reportedShares = collateralVault.deposit(assets, address(this));
    ExactTransfer.setApproval(asset, address(collateralVault), 0);
    uint256 receivedShares = collateralVault.balanceOf(address(this)) - sharesBefore;
    uint256 spentAssets = cash - asset.balanceOf(address(this));
    if (reportedShares == 0 || receivedShares != reportedShares || spentAssets != assets) {
      revert VaultDepositMismatch(reportedShares, receivedShares, spentAssets);
    }
    emit CollateralAllocated(assets, receivedShares);
  }

  /// @notice Latches default through expiry, or healthy maturity at expiry.
  function checkpoint() external nonReentrant {
    Lifecycle state = lifecycle;
    if (state != Lifecycle.Offered && state != Lifecycle.Active) {
      revert WrongLifecycle(Lifecycle.Active, state);
    }
    market.updateState();
    uint256 delinquency = market.currentState().timeDelinquent;
    uint256 threshold = defaultThreshold();
    if (state == Lifecycle.Active && block.timestamp <= expiry && delinquency >= threshold) {
      lifecycle = Lifecycle.Defaulted;
      defaultSupply = totalSupply;
      defaultHolderShares = remainingHolderShares;
      emit DefaultRecorded(delinquency, threshold);
    } else if (block.timestamp >= expiry) {
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
      : FullMath.mulDivUp(defaultHolderShares, newTotalPayouts, defaultSupply);
    uint256 shares = targetRecoveryShares - totalRecoverySharesAllocated;
    remainingCollateral -= amount;
    remainingHolderShares -= shares;
    totalPayouts = newTotalPayouts;
    totalRecoverySharesAllocated = targetRecoveryShares;
    sellerRecoveryShares += shares;
    asset.push(_validReceiver(receiver), amount);
    emit Claimed(msg.sender, receiver, amount, shares);
  }

  /// @notice Burns live protection, returns its debt and permanently reduces maximum cover.
  function unprotect(uint256 amount, address receiver) external nonReentrant {
    _requireLifecycle(Lifecycle.Active);
    uint256 newSupply = totalSupply - amount;
    uint256 shareTarget = _shareTarget(newSupply);
    uint256 shares = remainingHolderShares - shareTarget;
    _burn(msg.sender, amount);
    remainingHolderShares = shareTarget;
    remainingCollateral -= amount;
    totalSellerReleased += amount;
    if (newSupply == 0) lifecycle = Lifecycle.Offered;
    IERC20Like(address(wrapper)).push(_validReceiver(receiver), shares);
    asset.push(seller, amount);
    emit Unprotected(msg.sender, receiver, amount, shares);
    emit CollateralReleased(amount, amount, 0);
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

  /// @notice Releases terminal cash and vault shares in kind without calling the strategy.
  function releaseCollateral() external nonReentrant {
    if (msg.sender != seller) revert NotSeller();
    Lifecycle state = lifecycle;
    if (state == Lifecycle.Defaulted && block.timestamp <= claimDeadline) revert ClaimWindowOpen();
    if (state != Lifecycle.Matured && state != Lifecycle.Defaulted) {
      revert WrongLifecycle(Lifecycle.Matured, state);
    }
    uint256 accountingAmount = remainingCollateral;
    uint256 cash = asset.balanceOf(address(this));
    uint256 vaultShares =
      address(collateralVault) == address(0) ? 0 : collateralVault.balanceOf(address(this));
    if (accountingAmount == 0 && cash == 0 && vaultShares == 0) revert ZeroAmount();
    remainingCollateral = 0;
    totalSellerReleased += accountingAmount;

    if (cash != 0) asset.push(seller, cash);
    if (vaultShares != 0) IERC20Like(address(collateralVault)).push(seller, vaultShares);
    emit CollateralReleased(accountingAmount, cash, vaultShares);
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

  function _restoreCash(uint256 requiredCash) private {
    uint256 cash = asset.balanceOf(address(this));
    if (cash >= requiredCash) return;
    uint256 required = requiredCash - cash;
    if (address(collateralVault) == address(0)) revert InsufficientCollateral(requiredCash, cash);

    uint256 sharesBefore = collateralVault.balanceOf(address(this));
    uint256 reportedShares = collateralVault.withdraw(required, address(this), address(this));
    uint256 burnedShares = sharesBefore - collateralVault.balanceOf(address(this));
    uint256 receivedAssets = asset.balanceOf(address(this)) - cash;
    if (receivedAssets != required || burnedShares != reportedShares) {
      revert VaultWithdrawalMismatch(reportedShares, burnedShares, receivedAssets);
    }
  }

  function _shareTarget(uint256 supply) private view returns (uint256) {
    if (supply == 0) return 0;
    if (supply == notional) return referenceShareBudget;
    return FullMath.mulDivUp(referenceShareBudget, supply, notional);
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

  function _mint(address to, uint256 amount) private {
    totalSupply += amount;
    balanceOf[to] += amount;
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
