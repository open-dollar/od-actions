// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

interface IParaswapSellAdapter {
  struct SellParams {
    uint256 offset;
    bytes swapCalldata;
    address fromToken;
    address toToken;
    uint256 sellAmount;
  }

  /**
   * @dev Emitted after a sell of an asset is made
   * @param fromAsset The address of the asset sold
   * @param toAsset The address of the asset received in exchange
   * @param fromAmount The amount of asset sold
   * @param receivedAmount The amount received from the sell
   */
  event Swapped(address indexed fromAsset, address indexed toAsset, uint256 fromAmount, uint256 receivedAmount);

  function sellOnParaSwap(SellParams memory _sellParams) external returns (uint256 _amountReceived);
  function deposit(address _asset, uint256 _amount) external;
  function deposit(address _onBehalfOf, address _asset, uint256 _amount) external;
}
