// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBasicActions} from '@opendollar/interfaces/proxies/actions/IBasicActions.sol';

interface IExampleActions is IBasicActions {
  // --- Methods ---

  /**
   * @notice Opens a brand new SAFE and locks a collateral token amount
   * @param  _manager Address of the ODSafeManager contract
   * @param  _usr Address of the SAFE owner (ODProxy)
   * @param  _collateralJoin Address of the CollateralJoin contract
   * @param  _cType Bytes32 representing the collateral type
   * @param  _deltaWad Amount of collateral to collateralize [wad]
   * @return _safeId Id of the created SAFE
   */
  function openSAFEAndLockCollateral(
    address _manager,
    address _usr,
    address _collateralJoin,
    bytes32 _cType,
    uint256 _deltaWad
  ) external returns (uint256 _safeId);
}
