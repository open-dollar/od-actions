// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.6;
pragma abicoder v2;

import 'lib/forge-std/src/Test.sol';

contract Tester is Test {
  function testTrue() public {
    assertTrue(true);
  }
}
