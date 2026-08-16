// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { MarketState } from "v2-protocol/libraries/MarketState.sol";

import { Scaffold } from "../src/Scaffold.sol";

contract ScaffoldTest is Test {
  Scaffold internal scaffold;

  function setUp() public {
    scaffold = new Scaffold();
  }

  function testPinnedCompilerAndDependencySurface() public view {
    MarketState memory state;
    state.timeDelinquent = uint32(90 days);

    assertEq(scaffold.STATUS(), "research-scaffold");
    assertEq(scaffold.V2_PROTOCOL_COMMIT(), bytes20(hex"c7be4039f8f383a9dda4e45f63331c17d63f9ed9"));
    assertEq(state.timeDelinquent, 90 days);
  }
}
