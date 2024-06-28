// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

import {PercentageMath} from '@aave-core-v3/contracts/protocol/libraries/math/PercentageMath.sol';
import {SafeERC20} from '@aave-core-v3/contracts/dependencies/openzeppelin/contracts/SafeERC20.sol';
import {IERC20Detailed} from '@aave-core-v3/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol';
import {IPriceOracleGetter} from '@aave-core-v3/contracts/interfaces/IPriceOracleGetter.sol';
// import {IPoolAddressesProvider} from '@aave-core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
// import {DataTypes} from '@aave-core-v3/contracts/protocol/libraries/types/DataTypes.sol';
import {IParaSwapAugustusRegistry} from '@aave-debt-swap/dependencies/paraswap/IParaSwapAugustusRegistry.sol';
// import {BaseParaSwapAdapter} from '@aave-debt-swap/base/BaseParaSwapAdapter.sol';
// import {BaseParaSwapSellAdapter} from '@aave-debt-swap/base/BaseParaSwapSellAdapter.sol';

interface IParaswapSellAdapter {
  struct SellParams {
    uint256 offset;
    bytes paraswapData;
    address fromToken;
    address toToken;
    uint256 sellAmount;
    uint256 minReceiveAmount;
  }

  /**
   * @dev Emitted after a sell of an asset is made
   * @param fromAsset The address of the asset sold
   * @param toAsset The address of the asset received in exchange
   * @param fromAmount The amount of asset sold
   * @param receivedAmount The amount received from the sell
   */
  event Swapped(address indexed fromAsset, address indexed toAsset, uint256 fromAmount, uint256 receivedAmount);

  // function sellOnParaSwap(SellParams memory _sellParams) external returns (uint256 _amountReceived);
  function sellOnParaSwap(
    uint256 _offset,
    bytes calldata _swapCalldata,
    IERC20Detailed _fromToken,
    IERC20Detailed _toToken,
    uint256 _sellAmount,
    uint256 _minReceiveAmount
  ) external returns (uint256 _amountReceived);

  function deposit(address _asset, uint256 _amount) external;

  function deposit(address _onBehalfOf, address _asset, uint256 _amount) external;
}

interface IParaSwapAugustus {
  function getTokenTransferProxy() external view returns (address);
}

contract ParaswapSellAdapter is IParaswapSellAdapter {
  using SafeERC20 for IERC20Detailed;
  using PercentageMath for uint256;

  // uint256 public constant MAX_SLIPPAGE_PERCENT = 0.3e4; // 30.00%

  IParaSwapAugustusRegistry public immutable AUGUSTUS_REGISTRY;
  // IPriceOracleGetter public immutable ORACLE;

  mapping(address => mapping(address => uint256)) internal _deposits;

  /**
   * @param _augustusRegistry address of Paraswap AugustusRegistry
   */
  constructor(address _augustusRegistry) {
    AUGUSTUS_REGISTRY = IParaSwapAugustusRegistry(_augustusRegistry);
  }

  // function sellOnParaSwap(SellParams memory _sellParams) external returns (uint256 _amountReceived) {
  //   _amountReceived = _sellOnParaSwap(
  //     _sellParams.offset,
  //     _sellParams.paraswapData,
  //     IERC20Detailed(_sellParams.fromToken),
  //     IERC20Detailed(_sellParams.toToken),
  //     _sellParams.sellAmount,
  //     _sellParams.minReceiveAmount
  //   );
  // }

  function sellOnParaSwap(
    uint256 _offset,
    bytes memory _swapCalldata,
    IERC20Detailed _fromToken,
    IERC20Detailed _toToken,
    uint256 _sellAmount,
    uint256 _minReceiveAmount
  ) external returns (uint256 _amountReceived) {
    _amountReceived = _sellOnParaSwap(
      _offset, _swapCalldata, IERC20Detailed(_fromToken), IERC20Detailed(_toToken), _sellAmount, _minReceiveAmount
    );
  }

  /**
   * @dev Swaps a token for another using ParaSwap (exact in)
   * @dev In case the swap input is less than the designated amount to sell, the excess remains in the contract
   * @param _offset Offset of fromAmount in Augustus calldata if it should be overwritten, otherwise 0
   * @param _swapCalldata Data for Paraswap Adapter
   * @param _fromToken The address of the asset to swap from
   * @param _toToken The address of the asset to swap to
   * @param _sellAmount The amount of asset to swap from
   * @param _minReceiveAmount The minimum amount to receive
   * @return _amountReceived The amount of asset bought
   */
  function _sellOnParaSwap(
    uint256 _offset,
    bytes memory _swapCalldata,
    IERC20Detailed _fromToken,
    IERC20Detailed _toToken,
    uint256 _sellAmount,
    uint256 _minReceiveAmount
  ) internal returns (uint256 _amountReceived) {
    // (bytes memory _swapCalldata, IParaSwapAugustus augustus) = abi.decode(paraswapData, (bytes, IParaSwapAugustus));
    IParaSwapAugustus augustus = IParaSwapAugustus(0xDEF171Fe48CF0115B1d80b88dc8eAB59176FEe57);
    require(AUGUSTUS_REGISTRY.isValidAugustus(address(augustus)), 'INVALID_AUGUSTUS');

    // {
    //   uint256 fromAssetDecimals = _getDecimals(_fromToken);
    //   uint256 toAssetDecimals = _getDecimals(_toToken);

    //   uint256 fromAssetPrice = _getPrice(address(_fromToken));
    //   uint256 toAssetPrice = _getPrice(address(_toToken));

    //   uint256 expectedMinAmountOut = (
    //     (_sellAmount * (fromAssetPrice * (10 ** toAssetDecimals))) / (toAssetPrice * (10 ** fromAssetDecimals))
    //   ).percentMul(PercentageMath.PERCENTAGE_FACTOR - MAX_SLIPPAGE_PERCENT);

    //   // Sanity check for `_minReceiveAmount` to ensure it is within slippage bounds
    //   require(expectedMinAmountOut <= _minReceiveAmount, '_minReceiveAmount exceeds max slippage');
    // }

    uint256 _initBalFromToken = _fromToken.balanceOf(address(this));
    require(_initBalFromToken >= _sellAmount, 'INSUFFICIENT_BALANCE_BEFORE_SWAP');

    uint256 _initBalToToken = _toToken.balanceOf(address(this));

    address tokenTransferProxy = augustus.getTokenTransferProxy();
    _fromToken.safeApprove(tokenTransferProxy, _sellAmount);

    if (_offset != 0) {
      // Ensure 256 bit (32 bytes) _offset value is within bounds of the
      // calldata, not overlapping with the first 4 bytes (function selector).
      require(_offset >= 4 && _offset <= _swapCalldata.length - 32, 'FROM_AMOUNT_OFFSET_OUT_OF_RANGE');
      // Overwrite the fromAmount with the correct amount for the swap.
      // In memory, _swapCalldata consists of a 256 bit length field, followed by
      // the actual bytes data, that is why 32 is added to the byte offset.
      assembly {
        mstore(add(_swapCalldata, add(_offset, 32)), _sellAmount)
      }
    }
    (bool success,) = address(augustus).call(_swapCalldata);
    if (!success) {
      // Copy revert reason from call
      assembly {
        returndatacopy(0, 0, returndatasize())
        revert(0, returndatasize())
      }
    }

    // amount provided should be equal (or less) than `_sellAmount`
    uint256 _amountSold = _initBalFromToken - _fromToken.balanceOf(address(this));
    require(_sellAmount <= _amountSold, 'WRONG_BALANCE_AFTER_SWAP');

    // amount received should be more than or equal `_minReceiveAmount`
    _amountReceived = _toToken.balanceOf(address(this)) - _initBalToToken;
    require(_amountReceived >= _minReceiveAmount, 'INSUFFICIENT_AMOUNT_RECEIVED');

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
