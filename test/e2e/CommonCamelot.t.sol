// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Registry.s.sol';
import {Math} from '@opendollar/libraries/Math.sol';

contract CommonCamelot {
  function setUp() public virtual {}

  function _getPool() internal returns (address _pool) {
    return address(0);
  }
}
