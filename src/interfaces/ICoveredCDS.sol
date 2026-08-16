// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { MarketState } from "v2-protocol/libraries/MarketState.sol";

interface IERC20Like {
  function balanceOf(address account) external view returns (uint256);
  function transfer(address to, uint256 amount) external returns (bool);
  function transferFrom(address from, address to, uint256 amount) external returns (bool);
  function approve(address spender, uint256 amount) external returns (bool);
  function decimals() external view returns (uint8);
}

interface IWildcatMarketLike is IERC20Like {
  function asset() external view returns (address);
  function scaledBalanceOf(address account) external view returns (uint256);
  function delinquencyFeeBips() external view returns (uint256);
  function delinquencyGracePeriod() external view returns (uint256);
  function updateState() external;
  function currentState() external view returns (MarketState memory);
}

interface IWildcatWrapperLike is IERC20Like {
  function asset() external view returns (address);
  function deposit(uint256 assets, address receiver) external returns (uint256 shares);
}

interface IWildcatArchControllerLike {
  function isRegisteredMarket(address market) external view returns (bool);
}

interface IWildcatWrapperFactoryLike {
  function wrapperForMarket(address market) external view returns (address);
}
