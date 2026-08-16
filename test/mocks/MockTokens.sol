// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { MarketState } from "v2-protocol/libraries/MarketState.sol";

contract MockERC20 {
  string public name;
  string public symbol;
  uint8 public immutable decimals;
  uint256 public totalSupply;
  uint256 public feeBips;
  address public callbackTarget;
  bytes public callbackData;
  bool public callbackEnabled;
  bool public lastCallbackSuccess;

  mapping(address => uint256) public balanceOf;
  mapping(address => mapping(address => uint256)) public allowance;

  constructor(string memory name_, string memory symbol_, uint8 decimals_) {
    name = name_;
    symbol = symbol_;
    decimals = decimals_;
  }

  function mint(address to, uint256 amount) external {
    totalSupply += amount;
    balanceOf[to] += amount;
  }

  function burn(address from, uint256 amount) external {
    balanceOf[from] -= amount;
    totalSupply -= amount;
  }

  function setFeeBips(uint256 feeBips_) external {
    feeBips = feeBips_;
  }

  function setCallback(address target, bytes calldata data, bool enabled) external {
    callbackTarget = target;
    callbackData = data;
    callbackEnabled = enabled;
  }

  function approve(address spender, uint256 amount) external returns (bool) {
    allowance[msg.sender][spender] = amount;
    return true;
  }

  function transfer(address to, uint256 amount) external virtual returns (bool) {
    _transfer(msg.sender, to, amount);
    return true;
  }

  function transferFrom(address from, address to, uint256 amount) external virtual returns (bool) {
    uint256 allowed = allowance[from][msg.sender];
    if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;
    _transfer(from, to, amount);
    return true;
  }

  function _transfer(address from, address to, uint256 amount) internal {
    balanceOf[from] -= amount;
    uint256 fee = (amount * feeBips) / 10_000;
    balanceOf[to] += amount - fee;
    totalSupply -= fee;
    if (callbackEnabled && msg.sender == callbackTarget) {
      (lastCallbackSuccess,) = callbackTarget.call(callbackData);
    }
  }
}

contract MockMarket is MockERC20 {
  address public immutable asset;
  uint256 public delinquencyFeeBips = 500;
  uint256 public delinquencyGracePeriod = 2 weeks;
  uint256 public scaleNumerator = 1;
  uint256 public scaleDenominator = 1;
  MarketState internal _state;

  constructor(address asset_) MockERC20("Wildcat Market", "wmUSD", 6) {
    asset = asset_;
  }

  function setDelinquencyFeeBips(uint256 value) external {
    delinquencyFeeBips = value;
  }

  function setGracePeriod(uint256 value) external {
    delinquencyGracePeriod = value;
  }

  function setScaleRatio(uint256 numerator, uint256 denominator) external {
    scaleNumerator = numerator;
    scaleDenominator = denominator;
  }

  function scaledBalanceOf(address account) external view returns (uint256) {
    return (balanceOf[account] * scaleNumerator) / scaleDenominator;
  }

  function setTimeDelinquent(uint32 value) external {
    _state.timeDelinquent = value;
  }

  function setClosed(bool value) external {
    _state.isClosed = value;
  }

  function updateState() external { }

  function currentState() external view returns (MarketState memory) {
    return _state;
  }
}

contract MockWrapper is MockERC20 {
  MockMarket public immutable marketToken;
  address public immutable asset;
  uint256 public shareNumerator = 1;
  uint256 public shareDenominator = 1;
  bool public misreport;

  constructor(address market_) MockERC20("Wrapped Market", "vwmUSD", 6) {
    marketToken = MockMarket(market_);
    asset = market_;
  }

  function setShareRatio(uint256 numerator, uint256 denominator) external {
    shareNumerator = numerator;
    shareDenominator = denominator;
    marketToken.setScaleRatio(numerator, denominator);
  }

  function setMisreport(bool value) external {
    misreport = value;
  }

  function previewDeposit(uint256 assets) external view returns (uint256 shares) {
    return (assets * shareNumerator) / shareDenominator;
  }

  function previewWithdraw(uint256 assets) external view returns (uint256 shares) {
    return (assets * shareNumerator + shareDenominator - 1) / shareDenominator;
  }

  function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
    marketToken.transferFrom(msg.sender, address(this), assets);
    shares = (assets * shareNumerator) / shareDenominator;
    totalSupply += shares;
    balanceOf[receiver] += shares;
    return misreport ? shares + 1 : shares;
  }
}

contract MockVault is MockERC20 {
  MockERC20 public immutable assetToken;
  address public immutable asset;
  uint256 public withdrawLimit = type(uint256).max;
  uint256 public assetNumerator = 1;
  uint256 public shareDenominator = 1;

  constructor(address asset_) MockERC20("Mock Collateral Vault", "vcUSD", 6) {
    assetToken = MockERC20(asset_);
    asset = asset_;
  }

  function setWithdrawLimit(uint256 limit) external {
    withdrawLimit = limit;
  }

  function setRate(uint256 numerator, uint256 denominator) external {
    assetNumerator = numerator;
    shareDenominator = denominator;
  }

  function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
    assetToken.transferFrom(msg.sender, address(this), assets);
    shares = (assets * shareDenominator) / assetNumerator;
    totalSupply += shares;
    balanceOf[receiver] += shares;
    _callback();
  }

  function withdraw(uint256 assets, address receiver, address owner)
    external
    returns (uint256 shares)
  {
    if (assets > withdrawLimit) revert("WITHDRAW_LIMIT");
    shares = (assets * shareDenominator + assetNumerator - 1) / assetNumerator;
    if (msg.sender != owner) {
      uint256 allowed = allowance[owner][msg.sender];
      if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
    }
    balanceOf[owner] -= shares;
    totalSupply -= shares;
    assetToken.transfer(receiver, assets);
    _callback();
  }

  function _callback() private {
    if (callbackEnabled) {
      (lastCallbackSuccess,) = callbackTarget.call(callbackData);
    }
  }
}

contract MockArchController {
  mapping(address => bool) public isRegisteredMarket;

  function setRegistered(address market, bool registered) external {
    isRegisteredMarket[market] = registered;
  }
}

contract MockWrapperFactory {
  mapping(address => address) public wrapperForMarket;

  function setWrapper(address market, address wrapper) external {
    wrapperForMarket[market] = wrapper;
  }
}
