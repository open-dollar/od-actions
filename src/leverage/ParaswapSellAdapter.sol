// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {FlashLoanSimpleReceiverBase} from '@aave-core-v3/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol';
import {IPoolAddressesProvider} from '@aave-core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
// import {PercentageMath} from '@aave-core-v3/contracts/protocol/libraries/math/PercentageMath.sol';
import {IParaSwapAugustusRegistry} from '@aave-debt-swap/dependencies/paraswap/IParaSwapAugustusRegistry.sol';
import {IParaswapSellAdapter} from 'src/leverage/interfaces/IParaswapSellAdapter.sol';
import {IParaswapAugustus} from 'src/leverage/interfaces/IParaswapAugustus.sol';
import {BytesLib} from 'src/library/BytesLib.sol';

/**
 * TODO:
 * - add access control
 * - add modifiable contract for var updates
 * - add withdraw function
 * - enforce max slippage rate
 */
contract ParaswapSellAdapter is FlashLoanSimpleReceiverBase, IParaswapSellAdapter {
  // using PercentageMath for uint256;
  // uint256 public constant MAX_SLIPPAGE_PERCENT = 0.3e4; // 30.00%

  IParaSwapAugustusRegistry public immutable AUGUSTUS_REGISTRY;

  IParaswapAugustus public augustus;

  mapping(address => mapping(address => uint256)) internal _deposits;

  /**
   * @param _augustusRegistry address of Paraswap AugustusRegistry
   * @param _augustusSwapper address of Paraswap AugustusSwapper
   * @param _poolProvider address of Aave PoolAddressProvider
   */
  constructor(
    address _augustusRegistry,
    address _augustusSwapper,
    address _poolProvider
  ) FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_poolProvider)) {
    AUGUSTUS_REGISTRY = IParaSwapAugustusRegistry(_augustusRegistry);
    augustus = IParaswapAugustus(_augustusSwapper);
  }

  /// @dev deposit asset for msg.sender
  function deposit(address _asset, uint256 _amount) external {
    _deposit(msg.sender, _asset, _amount);
  }

  /// @dev deposit asset for account
  function deposit(address _onBehalfOf, address _asset, uint256 _amount) external {
    _deposit(_onBehalfOf, _asset, _amount);
  }

  /// @dev exact-in sell swap on ParaSwap
  function sellOnParaSwap(SellParams memory _sellParams) external returns (uint256 _amountReceived) {
    _amountReceived = _sellOnParaSwap(
      _sellParams.offset,
      _sellParams.swapCalldata,
      IERC20Metadata(_sellParams.fromToken),
      IERC20Metadata(_sellParams.toToken),
      _sellParams.sellAmount
    );
  }

  /// @dev request to borrow asset on Aave
  function requestFlashloan(address _asset, uint256 _amount) external {
    POOL.flashLoanSimple({receiverAddress: address(this), asset: _asset, amount: _amount, params: '', referralCode: 0});
  }

  /// @dev flashloan callback from Aave
  function executeOperation(
    address asset,
    uint256 amount,
    uint256 premium,
    address initiator,
    bytes calldata params
  ) external override returns (bool) {
    // add logic here

    uint256 _payBack = amount + premium;
    IERC20(asset).approve(address(POOL), _payBack);

    return true;
  }

  /// @dev transfer asset to this contract to use in flashloan-swap
  function _deposit(address _account, address _asset, uint256 _amount) internal {
    IERC20Metadata(_asset).transferFrom(_account, address(this), _amount);
    _deposits[_account][_asset] = _amount;
  }

  /// @dev takes ParaSwap transaction data and executes sell swap
  function _sellOnParaSwap(
    uint256 _offset,
    bytes memory _swapCalldata,
    IERC20Metadata _fromToken,
    IERC20Metadata _toToken,
    uint256 _sellAmount
  ) internal returns (uint256 _amountReceived) {
    if (!AUGUSTUS_REGISTRY.isValidAugustus(address(augustus))) revert InvalidAugustus();
    uint256 _minReceiveAmount = uint256(bytes32(BytesLib.slice(_swapCalldata, 0xa4, 0x20)));

    uint256 _initBalFromToken = _fromToken.balanceOf(address(this));
    if (_initBalFromToken < _sellAmount) revert InsufficientBalance();
    uint256 _initBalToToken = _toToken.balanceOf(address(this));

    address _tokenTransferProxy = augustus.getTokenTransferProxy();
    _fromToken.approve(_tokenTransferProxy, _sellAmount);

    if (_offset != 0) {
      // ensure 1 slot _offset is within bounds of calldata, not overlapping with function selector
      if (_offset < 4 && _offset > _swapCalldata.length - 32) revert OffsetOutOfRange();
      // overwrite the fromAmount with the correct amount for the swap
      assembly {
        mstore(add(_swapCalldata, add(_offset, 32)), _sellAmount)
      }
    }
    (bool _ok,) = address(augustus).call(_swapCalldata);
    if (!_ok) {
      assembly {
        returndatacopy(0, 0, returndatasize())
        revert(0, returndatasize())
      }
    }
    uint256 _amountSold = _initBalFromToken - _fromToken.balanceOf(address(this));
    if (_sellAmount > _amountSold) revert OverSell();

    _amountReceived = _toToken.balanceOf(address(this)) - _initBalToToken;
    if (_amountReceived < _minReceiveAmount) revert UnderBuy();
    emit Swapped(address(_fromToken), address(_toToken), _amountSold, _amountReceived);
  }
}
