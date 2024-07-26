// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBasicActions} from '@opendollar/interfaces/proxies/actions/IBasicActions.sol';

interface IExitActions is IBasicActions {
  /// @dev exits `_coinsToExit` system coins `_contract`
  function exitSystemCoinsToAccount(address _contract, address _coinJoin, uint256 _coinsToExit) external;

  /// @dev exits all system coins `_contract`
  function exitAllSystemCoinsToAccount(address _contract, address _coinJoin) external;

  /// @dev generate debt to `_contract`
  function generateDebtToAccount(
    address _contract,
    address _manager,
    address _coinJoin,
    uint256 _safeId,
    uint256 _deltaWad
  ) external;

  /// @dev generate debt to user proxy
  function generateDebtToProxy(address _manager, address _coinJoin, uint256 _safeId, uint256 _deltaWad) external;

  /// @dev generate debt without exit
  function generateInternalDebt(address _manager, uint256 _safeId, uint256 _deltaWad) external;

  /// @dev lock collateral and generate debt to `_contract`
  function lockTokenCollateralAndGenerateDebtToAccount(
    address _contract,
    address _manager,
    address _collateralJoin,
    address _coinJoin,
    uint256 _safe,
    uint256 _collateralAmount,
    uint256 _deltaWad
  ) external;
}
