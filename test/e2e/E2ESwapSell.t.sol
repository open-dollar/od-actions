// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Registry.s.sol';
import {AugustusRegistry} from '@aave-debt-swap/dependencies/paraswap/AugustusRegistry.sol';
import {ParaswapSellAdapter, IParaswapSellAdapter} from 'src/leverage/ParaswapSellAdapter.sol';
import {BaseTest} from 'test/e2e/common/BaseTest.t.sol';
import {BytesLib} from 'src/library/BytesLib.sol';

contract E2ESwapSell is BaseTest {
  IParaswapSellAdapter public sellAdapter;

  function setUp() public virtual {
    vm.createSelectFork(vm.rpcUrl('mainnet'));
    sellAdapter =
      new ParaswapSellAdapter(AugustusRegistry.ARBITRUM, PARASWAP_AUGUSTUS_SWAPPER, AAVE_POOL_ADDRESS_PROVIDER);
  }

  function testSwapRethToWeth() public {
    deal(RETH_ADDR, USER, SELL_AMOUNT);
    bytes memory _res = _getSwapRoute(RETH_ADDR, 18, WETH_ADDR, 18, SELL_AMOUNT, USER);

    IParaswapSellAdapter.SellParams memory _sellParams =
      IParaswapSellAdapter.SellParams(0, _res, RETH_ADDR, WETH_ADDR, SELL_AMOUNT);

    vm.startPrank(USER);
    _supply(address(sellAdapter), RETH_ADDR, SELL_AMOUNT);

    sellAdapter.sellOnParaSwap(_sellParams);
    vm.stopPrank();
  }
}
