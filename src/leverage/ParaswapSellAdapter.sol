// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

import {PercentageMath} from '@aave-core-v3/contracts/protocol/libraries/math/PercentageMath.sol';
import {SafeERC20} from '@aave-core-v3/contracts/dependencies/openzeppelin/contracts/SafeERC20.sol';
import {IERC20Detailed} from '@aave-core-v3/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol';
import {IParaSwapAugustusRegistry} from '@aave-debt-swap/dependencies/paraswap/IParaSwapAugustusRegistry.sol';
import {IParaswapSellAdapter} from 'src/leverage/interfaces/IParaswapSellAdapter.sol';
import {IParaswapAugustus} from 'src/leverage/interfaces/IParaswapAugustus.sol';
import {BytesLib} from 'src/library/BytesLib.sol';

contract ParaswapSellAdapter is IParaswapSellAdapter {
  using SafeERC20 for IERC20Detailed;
  using PercentageMath for uint256;

  // uint256 public constant MAX_SLIPPAGE_PERCENT = 0.3e4; // 30.00%

  IParaSwapAugustusRegistry public immutable AUGUSTUS_REGISTRY;

  IParaswapAugustus public augustus;

  mapping(address => mapping(address => uint256)) internal _deposits;

  /**
   * @param _augustusRegistry address of Paraswap AugustusRegistry
   */
  constructor(address _augustusRegistry, address _augustus) {
    AUGUSTUS_REGISTRY = IParaSwapAugustusRegistry(_augustusRegistry);
    augustus = IParaswapAugustus(_augustus);
  }

  /**
   * @dev swaps token for another using ParaSwap (exact in)
   * @param _sellParams IParaswapSellAdapter.SellParams
   */
  function sellOnParaSwap(SellParams memory _sellParams) external returns (uint256 _amountReceived) {
    _amountReceived = _sellOnParaSwap(
      _sellParams.offset,
      _sellParams.swapCalldata,
      IERC20Detailed(_sellParams.fromToken),
      IERC20Detailed(_sellParams.toToken),
      _sellParams.sellAmount
    );
  }

  /**
   * @param _offset offset of fromAmount in Augustus calldata if it should be overwritten, otherwise 0
   * @param _swapCalldata data for Paraswap adapter
   * @param _fromToken address of the asset to swap from
   * @param _toToken address of the asset to swap to
   * @param _sellAmount amount of asset to swap from
   * @return _amountReceived amount of asset bought
   */
  function _sellOnParaSwap(
    uint256 _offset,
    bytes memory _swapCalldata,
    IERC20Detailed _fromToken,
    IERC20Detailed _toToken,
    uint256 _sellAmount
  ) internal returns (uint256 _amountReceived) {
    if (!AUGUSTUS_REGISTRY.isValidAugustus(address(augustus))) revert InvalidAugustus();

    uint256 _minReceiveAmount = uint256(bytes32(BytesLib.slice(_swapCalldata, 0xa4, 0x20)));

    uint256 _initBalFromToken = _fromToken.balanceOf(address(this));
    require(_initBalFromToken >= _sellAmount, 'INSUFFICIENT_BALANCE_BEFORE_SWAP');

    uint256 _initBalToToken = _toToken.balanceOf(address(this));

    address tokenTransferProxy = augustus.getTokenTransferProxy();
    _fromToken.safeApprove(tokenTransferProxy, _sellAmount);

    if (_offset != 0) {
      // ensure 1 slot _offset is within bounds of calldata, not overlapping with function selector
      require(_offset >= 4 && _offset <= _swapCalldata.length - 32, 'FROM_AMOUNT_OFFSET_OUT_OF_RANGE');
      // overwrite the fromAmount with the correct amount for the swap
      assembly {
        mstore(add(_swapCalldata, add(_offset, 32)), _sellAmount)
      }
    }
    (bool success,) = address(augustus).call(_swapCalldata);
    if (!success) {
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

  function deposit(address _asset, uint256 _amount) external {
    _deposit(msg.sender, _asset, _amount);
  }

  function deposit(address _onBehalfOf, address _asset, uint256 _amount) external {
    _deposit(_onBehalfOf, _asset, _amount);
  }

  function _deposit(address _account, address _asset, uint256 _amount) internal {
    IERC20Detailed(_asset).transferFrom(_account, address(this), _amount);
    _deposits[_account][_asset] = _amount;
  }

  // /**
  //  * @dev Get the price of the asset from the oracle
  //  * @param asset The address of the asset
  //  * @return The price of the asset, based on the oracle denomination units
  //  */
  // function _getPrice(address asset) internal view returns (uint256) {
  //   return ORACLE.getAssetPrice(asset);
  // }

  // /**
  //  * @dev Get the decimals of an asset
  //  * @param asset The address of the asset
  //  * @return number of decimals of the asset
  //  */
  // function _getDecimals(IERC20Detailed asset) internal view returns (uint8) {
  //   uint8 decimals = asset.decimals();
  //   // Ensure 10**decimals won't overflow a uint256
  //   require(decimals <= 77, 'TOO_MANY_DECIMALS_ON_TOKEN');
  //   return decimals;
  // }
}
