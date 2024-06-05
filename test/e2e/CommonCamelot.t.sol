// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import 'forge-std/Test.sol';
// import {CAMELOT_FACTORY, CAMELOT_OD_WETH_POOL} from '@script/Registry.s.sol';
import {IAlgebraFactory} from '@algebra-core/interfaces/IAlgebraFactory.sol';
import {IAlgebraPool} from '@algebra-core/interfaces/IAlgebraPool.sol';

contract CommonCamelot is Test {
  IAlgebraFactory public camelotFactory;
  IAlgebraPool public camelotPool;

  function setUp() public virtual {
    camelotFactory = IAlgebraFactory(CAMELOT_FACTORY);
    camelotPool = IAlgebraPool(camelotFactory.poolByPair(OD, WETH));
  }
}

contract CommonCamelotTest is CommonCamelot {
  function testCamelotPool() public {
    assertEq(address(camelotPool), CAMELOT_OD_WETH_POOL);
  }
}
