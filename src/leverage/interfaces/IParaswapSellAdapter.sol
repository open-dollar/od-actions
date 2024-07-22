// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IPoolAddressesProvider} from '@aave-core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {IPool} from '@aave-core-v3/contracts/interfaces/IPool.sol';

/**
 * _augustusRegistry address of Paraswap AugustusRegistry
 * _augustusSwapper address of Paraswap AugustusSwapper
 * _poolProvider address of Aave PoolAddressProvider
 * _vault721 address of OpenDollar Vault721
 * _exitActions address of OpenDollar ExitActions
 * _collateralJoinFactory address of OpenDollar CollateralJoinFactory
 * _coinJoin address of OpenDollar CoinJoin
 */
struct InitSellAdapter {
  address augustusRegistry;
  address augustusSwapper;
  address poolProvider;
  address vault721;
  address oracleRelayer;
  address exitActions;
  address collateralJoinFactory;
  address coinJoin;
}

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
  error IncorrectAmount();
  error OffsetOutOfRange();
  error OverSell();
  error UnderBuy();
  error ZeroValue();

  /**
   * @param _offset offset of fromAmount in Augustus calldata if it should be overwritten, otherwise 0
   * @param _swapCalldata data for Paraswap adapter
   * @param _fromToken address of the asset to swap from
   * @param _toToken address of the asset to swap to
   * @param _sellAmount amount of asset to swap from
   */
  struct SellParams {
    uint256 offset;
    bytes swapCalldata;
    address fromToken;
    address toToken;
    uint256 sellAmount;
  }

  /**
   * @param _sellParams IParaswapSellAdapter.SellParams
   * @param _minDstAmount for sell/swap
   * @return _amountReceived amount of asset bought
   */
  function sellOnParaSwap(
    SellParams memory _sellParams,
    uint256 _minDstAmount
  ) external returns (uint256 _amountReceived);

  /**
   * @param _sellParams IParaswapSellAdapter.SellParams
   * @param _minDstAmount accepted for sell/swap
   * @param _safeId OpenDollar NFV/CDP
   * @param _cType collateral type of OpenDollar NFV/CDP
   */
  function requestFlashloan(
    SellParams memory _sellParams,
    uint256 _initCollateral,
    uint256 _collateralLoan,
    uint256 _minDstAmount,
    uint256 _safeId,
    bytes32 _cType
  ) external;

  /**
   * @param _cType collateral type of OpenDollar NFV/CDP
   */
  function getCData(bytes32 _cType) external view returns (uint256 _accumulatedRate, uint256 _safetyPrice);

  /**
   * @param _cType collateral type of OpenDollar NFV/CDP
   */
  function getSafetyRatio(bytes32 _cType) external returns (uint256 _safetyCRatio);

  /**
   * @param _cType collateral type of OpenDollar NFV/CDP
   * @param _initCapital initial collateral deposit
   */
  function getLeveragedDebt(
    bytes32 _cType,
    uint256 _initCapital
  ) external returns (uint256 _cTypeLoanAmount, uint256 _leveragedDebt);

  /**
   * @param _cType collateral type of OpenDollar NFV/CDP
   * @param _initCapital initial collateral deposit
   * @param _percentageBuffer percentage above cType safetyRatio
   */
  function getLeveragedDebt(
    bytes32 _cType,
    uint256 _initCapital,
    uint256 _percentageBuffer
  ) external returns (uint256 _cTypeLoanAmount, uint256 _leveragedDebt);

  /**
   * @param _asset token
   * @param _amount to deposit
   */
  function deposit(address _asset, uint256 _amount) external;

  /**
   * @param _onBehalfOf account to receive balance
   * @param _asset token
   * @param _amount to deposit
   */
  function deposit(address _onBehalfOf, address _asset, uint256 _amount) external;
}
