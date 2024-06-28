// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import '@script/Registry.s.sol';
import {IERC20Detailed} from '@aave-core-v3/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol';
import {ParaswapSellAdapter, IParaswapSellAdapter} from 'src/leverage/ParaswapSellAdapter.sol';
// import {AaveV3Arbitrum, AaveV3ArbitrumAssets, IPool} from 'aave-address-book/AaveV3Arbitrum.sol';
import {AugustusRegistry} from '@aave-debt-swap/dependencies/paraswap/AugustusRegistry.sol';
// import {IParaSwapAugustusRegistry} from '@aave-debt-swap/dependencies/paraswap/IParaSwapAugustusRegistry.sol';

contract E2ESwapSell is Test {
  address public constant user = 0xA0313248556DeA42fd17B345817Dd5DC5674c1E1;
  uint256 public constant SELL_AMOUNT = 1_000_000_000_000_000;

  IParaswapSellAdapter.SellParams public sellParams;

  IParaswapSellAdapter public sellAdapter;
  bytes public res;

  function setUp() public virtual {
    vm.createSelectFork(vm.rpcUrl('mainnet'));
    sellAdapter = new ParaswapSellAdapter(AugustusRegistry.ARBITRUM);

    _getSwapRoute();
  }

  function _getSwapRoute() internal {
    string[] memory inputs = new string[](2);
    inputs[0] = 'node';
    inputs[1] = './script/findSwapRoute.js';

    res = vm.ffi(inputs);
  }

  function testSwap() public {
    emit log_named_uint('user   ', IERC20Detailed(RETH_ADDR).balanceOf(user));
    emit log_named_uint('this   ', IERC20Detailed(RETH_ADDR).balanceOf(address(this)));
    emit log_named_uint('adapter', IERC20Detailed(RETH_ADDR).balanceOf(address(sellAdapter)));
    emit log_named_uint('sell   ', SELL_AMOUNT);

    vm.startPrank(user);
    _supply(address(sellAdapter), RETH_ADDR, SELL_AMOUNT + 1);

    sellAdapter.sellOnParaSwap(
      0, res, IERC20Detailed(RETH_ADDR), IERC20Detailed(WETH_ADDR), SELL_AMOUNT, 1_109_159_391_158_019
    );
    vm.stopPrank();
  }

  function _supply(address _adapter, address _asset, uint256 _amount) internal {
    deal(_asset, user, _amount);
    IERC20Detailed(_asset).approve(address(_adapter), _amount);
    IParaswapSellAdapter(_adapter).deposit(RETH_ADDR, SELL_AMOUNT);
  }

  // function _borrow(address _adapter, address _asset, uint256 _amount) internal {
  //   _adapter.borrow(_asset, _amount, 2, 0, user);
  // }

  // function _withdraw(address _adapter, address _asset, uint256 _amount) internal {
  //   _adapter.withdraw(_asset, _amount, user);
  // }
}
