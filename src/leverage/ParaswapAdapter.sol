// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {IERC20Detailed} from '@aave-core-v3/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol';
import {IPoolAddressesProvider} from '@aave-core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {IParaSwapAugustusRegistry} from '@aave-debt-swap/dependencies/paraswap/IParaSwapAugustusRegistry.sol';
import {BaseParaSwapAdapter} from '@aave-debt-swap/base/BaseParaSwapAdapter.sol';
import {BaseParaSwapBuyAdapter} from '@aave-debt-swap/base/BaseParaSwapBuyAdapter.sol';

/**
 * @dev TODO: add access control
 */
contract ParaswapAdapter is BaseParaSwapBuyAdapter {
  /**
   * @param _addressesProvider The address of the Aave PoolAddressesProvider contract
   * @param _pool The address of the Aave Pool contract
   * @param _augustusRegistry The address of the Paraswap AugustusRegistry contract
   */
  constructor(
    IPoolAddressesProvider _addressesProvider,
    address _pool,
    IParaSwapAugustusRegistry _augustusRegistry
  ) BaseParaSwapBuyAdapter(_addressesProvider, _pool, _augustusRegistry) {}

  /**
   * @dev Swaps a token for another using ParaSwap (exact out)
   * @dev In case the swap output is higher than the designated amount to buy, the excess remains in the contract
   * @param toAmountOffset Offset of toAmount in Augustus calldata if it should be overwritten, otherwise 0
   * @param paraswapData Data for Paraswap Adapter
   * @param assetToSwapFrom The address of the asset to swap from
   * @param assetToSwapTo The address of the asset to swap to
   * @param maxAmountToSwap The maximum amount of asset to swap from
   * @param amountToReceive The amount of asset to receive
   * @return amountSold The amount of asset sold
   */
  function buyOnParaSwap(
    uint256 toAmountOffset,
    bytes memory paraswapData,
    IERC20Detailed assetToSwapFrom,
    IERC20Detailed assetToSwapTo,
    uint256 maxAmountToSwap,
    uint256 amountToReceive
  ) external returns (uint256 amountSold) {
    return
      _buyOnParaSwap(toAmountOffset, paraswapData, assetToSwapFrom, assetToSwapTo, maxAmountToSwap, amountToReceive);
  }

  /// @inheritdoc BaseParaSwapAdapter
  function _getReserveData(address asset) internal view virtual override returns (address, address, address) {}

  /// @inheritdoc BaseParaSwapAdapter
  function _supply(address asset, uint256 amount, address to, uint16 referralCode) internal virtual override {}
}
