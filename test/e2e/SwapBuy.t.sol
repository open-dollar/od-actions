// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {Test} from 'lib/forge-std/src/Test.sol';
import {BaseParaSwapBuyAdapter} from '@aave-debt-swap/base/BaseParaSwapBuyAdapter.sol';

contract SwapBuy is Test {
  function setUp() public virtual {
    vm.createSelectFork(vm.rpcUrl('mainnet'));
  }
}
