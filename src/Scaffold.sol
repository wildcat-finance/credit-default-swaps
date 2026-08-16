// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice Build marker for the research-only repository scaffold.
contract Scaffold {
  string public constant STATUS = "research-scaffold";
  bytes20 public constant V2_PROTOCOL_COMMIT =
    bytes20(hex"c7be4039f8f383a9dda4e45f63331c17d63f9ed9");
}
