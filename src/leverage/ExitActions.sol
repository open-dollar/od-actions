// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Registry.s.sol';
import {SafeCast} from '@openzeppelin/utils/math/SafeCast.sol';
import {BasicActions} from '@opendollar/contracts/proxies/actions/BasicActions.sol';
import {ODSafeManager} from '@opendollar/contracts/proxies/ODSafeManager.sol';
import {ICoinJoin} from '@opendollar/interfaces/utils/ICoinJoin.sol';
import {ISAFEEngine} from '@opendollar/interfaces/ISAFEEngine.sol';
import {Math, RAY} from '@opendollar/libraries/Math.sol';

contract ExitActions is BasicActions {
  using Math for uint256;
  using SafeCast for int256;

  /// @dev exits `_coinsToExit` system coins `_contract`
  function exitSystemCoinsToAccount(address _contract, address _coinJoin, uint256 _coinsToExit) external delegateCall {
    _exitSystemCoinsToAccount(_contract, _coinJoin, _coinsToExit);
  }

  /// @dev exits all system coins `_contract`
  function exitAllSystemCoinsToAccount(address _contract, address _coinJoin) external delegateCall {
    uint256 _coinsToExit = ICoinJoin(_coinJoin).safeEngine().coinBalance(address(this));
    _exitSystemCoinsToAccount(_contract, _coinJoin, _coinsToExit);
  }

  /// @dev generate debt to `_contract`
  function generateDebtToAccount(
    address _contract,
    address _manager,
    address _coinJoin,
    uint256 _safeId,
    uint256 _deltaWad
  ) external delegateCall {
    _generateDebtToAccount(_contract, _manager, _coinJoin, _safeId, _deltaWad);
  }

  /// @dev lock collateral and generate debt to `_contract`
  function lockTokenCollateralAndGenerateDebtToAccount(
    address _contract,
    address _manager,
    address _collateralJoin,
    address _coinJoin,
    uint256 _safe,
    uint256 _collateralAmount,
    uint256 _deltaWad
  ) external delegateCall {
    _lockTokenCollateralAndGenerateDebtToAccount(
      _contract, _manager, _collateralJoin, _coinJoin, _safe, _collateralAmount, _deltaWad
    );
  }

  /// @dev Exits system coins from the safeEngine to `_contract`
  function _exitSystemCoinsToAccount(address _contract, address _coinJoin, uint256 _coinsToExit) internal virtual {
    if (_coinsToExit == 0) return;

    ICoinJoin __coinJoin = ICoinJoin(_coinJoin);
    ISAFEEngine __safeEngine = __coinJoin.safeEngine();

    if (!__safeEngine.canModifySAFE(address(this), _coinJoin)) {
      __safeEngine.approveSAFEModification(_coinJoin);
    }

    // transfer all coins to _contract
    __coinJoin.exit(_contract, _coinsToExit / RAY);
  }

  /**
   * @notice Generates debt
   * @dev    Modifies the SAFE collateralization ratio, increasing the debt and sends the COIN amount to the user's address
   */
  function _generateDebtToAccount(
    address _contract,
    address _manager,
    address _coinJoin,
    uint256 _safeId,
    uint256 _deltaWad
  ) internal {
    address _safeEngine = ODSafeManager(_manager).safeEngine();
    ODSafeManager.SAFEData memory _safeInfo = ODSafeManager(_manager).safeData(_safeId);

    int256 deltaDebt = _getGeneratedDeltaDebt(_safeEngine, _safeInfo.collateralType, _safeInfo.safeHandler, _deltaWad);

    // Generates debt in the SAFE
    _modifySAFECollateralization(_manager, _safeId, 0, deltaDebt, false);

    // exits and transfers COIN amount to address
    _collectAndExitCoinsToAccount(_contract, _manager, _coinJoin, _safeId, _deltaWad);
  }

  /// @dev join collateral and exit an amount of COIN
  function _lockTokenCollateralAndGenerateDebtToAccount(
    address _contract,
    address _manager,
    address _collateralJoin,
    address _coinJoin,
    uint256 _safeId,
    uint256 _collateralAmount,
    uint256 _deltaWad
  ) internal {
    address _safeEngine = ODSafeManager(_manager).safeEngine();
    ODSafeManager.SAFEData memory _safeInfo = ODSafeManager(_manager).safeData(_safeId);

    // takes token amount from user's wallet and joins into the safeEngine
    _joinCollateral(_collateralJoin, _safeInfo.safeHandler, _collateralAmount);

    int256 deltaDebt = _getGeneratedDeltaDebt(_safeEngine, _safeInfo.collateralType, _safeInfo.safeHandler, _deltaWad);

    // locks token amount into the SAFE and generates debt
    _modifySAFECollateralization(_manager, _safeId, _collateralAmount.toInt(), deltaDebt, false);

    // exits and transfers COIN amount to address
    _collectAndExitCoinsToAccount(_contract, _manager, _coinJoin, _safeId, _deltaWad);
  }

  /// @dev transfer amount of COIN to proxy address and exit to `_contract` address
  function _collectAndExitCoinsToAccount(
    address _contract,
    address _manager,
    address _coinJoin,
    uint256 _safeId,
    uint256 _deltaWad
  ) internal {
    // moves the COIN amount to proxy's address
    _transferInternalCoins(_manager, _safeId, address(this), _deltaWad * RAY);
    // exits the COIN amount to the user's address
    _exitSystemCoinsToAccount(_contract, _coinJoin, _deltaWad * RAY);
  }
}
