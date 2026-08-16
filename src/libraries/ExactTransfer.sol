// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC20Like } from "../interfaces/ICoveredCDS.sol";

library ExactTransfer {
  error TransferFailed(address token);
  error InexactTransfer(address token, uint256 expected, uint256 debited, uint256 credited);

  function pull(IERC20Like token, address from, address to, uint256 amount) internal {
    uint256 fromBefore = token.balanceOf(from);
    uint256 toBefore = token.balanceOf(to);
    _call(address(token), abi.encodeCall(token.transferFrom, (from, to, amount)));
    uint256 fromAfter = token.balanceOf(from);
    uint256 toAfter = token.balanceOf(to);
    uint256 debited = fromBefore >= fromAfter ? fromBefore - fromAfter : type(uint256).max;
    uint256 credited = toAfter >= toBefore ? toAfter - toBefore : type(uint256).max;
    if (debited != amount || credited != amount) {
      revert InexactTransfer(address(token), amount, debited, credited);
    }
  }

  function push(IERC20Like token, address to, uint256 amount) internal {
    address from = address(this);
    uint256 fromBefore = token.balanceOf(from);
    uint256 toBefore = token.balanceOf(to);
    _call(address(token), abi.encodeCall(token.transfer, (to, amount)));
    uint256 fromAfter = token.balanceOf(from);
    uint256 toAfter = token.balanceOf(to);
    uint256 debited = fromBefore >= fromAfter ? fromBefore - fromAfter : type(uint256).max;
    uint256 credited = toAfter >= toBefore ? toAfter - toBefore : type(uint256).max;
    if (debited != amount || credited != amount) {
      revert InexactTransfer(address(token), amount, debited, credited);
    }
  }

  function setApproval(IERC20Like token, address spender, uint256 amount) internal {
    _call(address(token), abi.encodeCall(token.approve, (spender, amount)));
  }

  function _call(address token, bytes memory data) private {
    (bool ok, bytes memory result) = token.call(data);
    if (!ok || (result.length != 0 && !abi.decode(result, (bool)))) revert TransferFailed(token);
  }
}
