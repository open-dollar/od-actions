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
    IParaswapSellAdapter.SellParams memory _sellParams = _getSingleUserInput(RETH_ADDR, WETH_ADDR);

    vm.startPrank(USER);
    _supplyAndDeposit(address(sellAdapter), RETH_ADDR, SELL_AMOUNT);
    sellAdapter.sellOnParaSwap(_sellParams);
    vm.stopPrank();
  }

  function testSwapWethToReth() public {
    IParaswapSellAdapter.SellParams memory _sellParams = _getSingleUserInput(WETH_ADDR, RETH_ADDR);

    vm.startPrank(USER);
    _supplyAndDeposit(address(sellAdapter), WETH_ADDR, SELL_AMOUNT);
    sellAdapter.sellOnParaSwap(_sellParams);
    vm.stopPrank();
  }

  function testSwapWstethToWeth() public {
    IParaswapSellAdapter.SellParams memory _sellParams = _getSingleUserInput(WSTETH_ADDR, WETH_ADDR);

    vm.startPrank(USER);
    _supplyAndDeposit(address(sellAdapter), WSTETH_ADDR, SELL_AMOUNT);
    sellAdapter.sellOnParaSwap(_sellParams);
    vm.stopPrank();
  }

  function testSwapWethToWsteth() public {
    IParaswapSellAdapter.SellParams memory _sellParams = _getSingleUserInput(WETH_ADDR, WSTETH_ADDR);

    vm.startPrank(USER);
    _supplyAndDeposit(address(sellAdapter), WETH_ADDR, SELL_AMOUNT);
    sellAdapter.sellOnParaSwap(_sellParams);
    vm.stopPrank();
  }

  function testSwapWstethToReth() public {
    IParaswapSellAdapter.SellParams memory _sellParams = _getSingleUserInput(WSTETH_ADDR, RETH_ADDR);

    vm.startPrank(USER);
    _supplyAndDeposit(address(sellAdapter), WSTETH_ADDR, SELL_AMOUNT);
    sellAdapter.sellOnParaSwap(_sellParams);
    vm.stopPrank();
  }

  function testSwapRethToWsteth() public {
    IParaswapSellAdapter.SellParams memory _sellParams = _getSingleUserInput(RETH_ADDR, WSTETH_ADDR);

    vm.startPrank(USER);
    _supplyAndDeposit(address(sellAdapter), RETH_ADDR, SELL_AMOUNT);
    sellAdapter.sellOnParaSwap(_sellParams);
    vm.stopPrank();
  }
}
