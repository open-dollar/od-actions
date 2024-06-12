// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {BasicActions} from '@opendollar/contracts/proxies/actions/BasicActions.sol';
import {ODSafeManager} from '@opendollar/contracts/proxies/ODSafeManager.sol';
import {Math} from '@opendollar/libraries/Math.sol';
import {IExampleActions} from 'src/example/IExampleActions.sol';

/**
 * @dev example contract for creating new actions contracts
 * For all basic proxy-actions functions, inherit BasicActions
 * For minimum proxy-actions functions, inherit CommonActions
 */
contract ExampleActions is BasicActions, IExampleActions {
  using Math for uint256;

  /**
   * @dev example function that combines the logic of:
   * `BasicActions.openSAFE` and `BasicActions.lockTokenCollateral`
   */

  /// @inheritdoc IExampleActions
  function openSAFEAndLockCollateral(
    address _manager,
    address _usr,
    address _collateralJoin,
    bytes32 _cType,
    uint256 _deltaWad
  ) external delegateCall returns (uint256 _safeId) {
    // opens safe and mints NFV (nonfungible vault)
    _safeId = _openSAFE(_manager, _cType, _usr);
    // gets safe data
    ODSafeManager.SAFEData memory _safeInfo = ODSafeManager(_manager).safeData(_safeId);
    // takes token amount from user's wallet and joins into the safeEngine
    _joinCollateral(_collateralJoin, _safeInfo.safeHandler, _deltaWad);
    // locks token amount in the safe
    _modifySAFECollateralization(_manager, _safeId, _deltaWad.toInt(), 0, false);
  }
}
