// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import 'forge-std/Test.sol';
import '@script/Registry.s.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {IParaswapSellAdapter} from 'src/leverage/ParaswapSellAdapter.sol';

contract BaseTest is Test {
  function _supplyAndDeposit(address _adapter, address _asset, uint256 _amount) internal {
    deal(_asset, msg.sender, _amount);
    IERC20Metadata(_asset).approve(address(_adapter), _amount);
    IParaswapSellAdapter(_adapter).deposit(_asset, _amount);
  }

  function _getSingleUserInput(
    address _tokenA,
    address _tokenB
  ) internal returns (IParaswapSellAdapter.SellParams memory _sellParams) {
    deal(_tokenA, USER, SELL_AMOUNT);
    bytes memory _result = _getSwapRoute(_tokenA, 18, _tokenB, 18, SELL_AMOUNT, USER);
    _sellParams = IParaswapSellAdapter.SellParams(0, _result, _tokenA, _tokenB, SELL_AMOUNT);
  }

  function _getFullUserInput(
    address _tokenA,
    address _tokenB
  ) internal returns (uint256 _dstAmount, IParaswapSellAdapter.SellParams memory _sellParams) {
    (_dstAmount, _sellParams) = _getFullUserInputWithAmount(_tokenA, _tokenB, SELL_AMOUNT);
  }

  function _getFullUserInputWithAmount(
    address _tokenA,
    address _tokenB,
    uint256 _amount
  ) internal returns (uint256 _dstAmount, IParaswapSellAdapter.SellParams memory _sellParams) {
    deal(_tokenA, USER, _amount);
    _dstAmount = uint256(bytes32(_getDstAmount(_tokenA, 18, _tokenB, 18, _amount, USER)));
    bytes memory _result = _getSwapRoute(_tokenA, 18, _tokenB, 18, _amount, USER);
    _sellParams = IParaswapSellAdapter.SellParams(0, _result, _tokenA, _tokenB, _amount);
  }

  function _getDstAmount(
    address _fromToken,
    uint256 _fromDecimals,
    address _toToken,
    uint256 _toDecimals,
    uint256 _sellAmount,
    address _caller
  ) internal returns (bytes memory _result) {
    string[] memory inputs = new string[](8);
    inputs[0] = 'node';
    inputs[1] = './script/getDstAmount.js';
    inputs[2] = vm.toString(_fromToken);
    inputs[3] = vm.toString(_fromDecimals);
    inputs[4] = vm.toString(_toToken);
    inputs[5] = vm.toString(_toDecimals);
    inputs[6] = vm.toString(_sellAmount);
    inputs[7] = vm.toString(_caller);

    _result = vm.ffi(inputs);
  }

  function _getSwapRoute(
    address _fromToken,
    uint256 _fromDecimals,
    address _toToken,
    uint256 _toDecimals,
    uint256 _sellAmount,
    address _caller
  ) internal returns (bytes memory _result) {
    string[] memory inputs = new string[](8);
    inputs[0] = 'node';
    inputs[1] = './script/getSwapRoute.js';
    inputs[2] = vm.toString(_fromToken);
    inputs[3] = vm.toString(_fromDecimals);
    inputs[4] = vm.toString(_toToken);
    inputs[5] = vm.toString(_toDecimals);
    inputs[6] = vm.toString(_sellAmount);
    inputs[7] = vm.toString(_caller);

    _result = vm.ffi(inputs);
  }
}

// function _borrow(address _adapter, address _asset, uint256 _amount) internal {
//   _adapter.borrow(_asset, _amount, 2, 0, USER);
// }

// function _withdraw(address _adapter, address _asset, uint256 _amount) internal {
//   _adapter.withdraw(_asset, _amount, USER);
// }
