// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

interface IParaswapSellAdapter {
  /**
   * @dev emitted after a sell of an asset is made
   * @param _fromAsset address of the asset sold
   * @param _toAsset address of the asset received in exchange
   * @param _fromAmount amount of asset sold
   * @param _receivedAmount amount received from the sell
   */
  event Swapped(address indexed _fromAsset, address indexed _toAsset, uint256 _fromAmount, uint256 _receivedAmount);

  error InvalidAugustus();
  error InsufficientBalance();
  error OffsetOutOfRange();
  error OverSell();
  error UnderBuy();

  struct SellParams {
    uint256 offset;
    bytes swapCalldata;
    address fromToken;
    address toToken;
    uint256 sellAmount;
  }

  function sellOnParaSwap(SellParams memory _sellParams) external returns (uint256 _amountReceived);
  function deposit(address _asset, uint256 _amount) external;
  function deposit(address _onBehalfOf, address _asset, uint256 _amount) external;
}
