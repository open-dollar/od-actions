// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import '@script/Registry.s.sol';
import {IERC20Detailed} from '@aave-core-v3/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol';
import {ParaswapSellAdapter, IParaswapSellAdapter} from 'src/leverage/ParaswapSellAdapter.sol';
import {AugustusRegistry} from '@aave-debt-swap/dependencies/paraswap/AugustusRegistry.sol';
import {BytesLib} from 'src/library/BytesLib.sol';

contract E2ESwapSell is Test {
  address public constant user = 0xA0313248556DeA42fd17B345817Dd5DC5674c1E1;
  address public constant AUGUSTUS = 0xDEF171Fe48CF0115B1d80b88dc8eAB59176FEe57;
  uint256 public constant SELL_AMOUNT = 1_000_000_000_000_000;

  IParaswapSellAdapter public sellAdapter;

  function setUp() public virtual {
    vm.createSelectFork(vm.rpcUrl('mainnet'));
    sellAdapter = new ParaswapSellAdapter(AugustusRegistry.ARBITRUM, AUGUSTUS);
  }

  /**
   * @dev test limited due to current real funds and approvals on arb-mainnet dev-wallet
   * since the transaction order creation depends on checking balances and approvals from
   * `findSwapRoute.js` script that makes actual route request from ParaSwap SDK
   */
  function testSwapRethToWeth() public {
    bytes memory _res = _getSwapRoute(RETH_ADDR, 18, WETH_ADDR, 18, SELL_AMOUNT);

    IParaswapSellAdapter.SellParams memory _sellParams =
      IParaswapSellAdapter.SellParams(0, _res, RETH_ADDR, WETH_ADDR, SELL_AMOUNT);

    vm.startPrank(user);
    _supply(address(sellAdapter), RETH_ADDR, SELL_AMOUNT);

    sellAdapter.sellOnParaSwap(_sellParams);
    vm.stopPrank();
  }

  function _supply(address _adapter, address _asset, uint256 _amount) internal {
    deal(_asset, user, _amount);
    IERC20Detailed(_asset).approve(address(_adapter), _amount);
    IParaswapSellAdapter(_adapter).deposit(RETH_ADDR, SELL_AMOUNT);
  }

  function _getSwapRoute(
    address _fromToken,
    uint256 _fromDecimals,
    address _toToken,
    uint256 _toDecimals,
    uint256 _sellAmount
  ) internal returns (bytes memory _result) {
    string[] memory inputs = new string[](7);
    inputs[0] = 'node';
    inputs[1] = './script/findSwapRoute.js';
    inputs[2] = vm.toString(_fromToken);
    inputs[3] = vm.toString(_fromDecimals);
    inputs[4] = vm.toString(_toToken);
    inputs[5] = vm.toString(_toDecimals);
    inputs[6] = vm.toString(_sellAmount);

    _result = vm.ffi(inputs);
  }

  // function _borrow(address _adapter, address _asset, uint256 _amount) internal {
  //   _adapter.borrow(_asset, _amount, 2, 0, user);
  // }

  // function _withdraw(address _adapter, address _asset, uint256 _amount) internal {
  //   _adapter.withdraw(_asset, _amount, user);
  // }
}
