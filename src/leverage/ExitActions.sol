// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Registry.s.sol';
import {BasicActions} from '@opendollar/contracts/proxies/actions/BasicActions.sol';
import {ODSafeManager} from '@opendollar/contracts/proxies/ODSafeManager.sol';
import {ICoinJoin} from '@opendollar/interfaces/utils/ICoinJoin.sol';
import {ISAFEEngine} from '@opendollar/interfaces/ISAFEEngine.sol';
import {Math, RAY} from '@opendollar/libraries/Math.sol';

contract ExitActions is BasicActions {
  /// @dev exits `_coinsToExit` system coins `_contract`
  function exitSystemCoinsToAccount(address _contract, address _coinJoin, uint256 _coinsToExit) external delegateCall {
    _exitSystemCoinsToAccount(_contract, _coinJoin, _coinsToExit);
  }

  /// @dev exits all system coins `_contract`
  function exitAllSystemCoinsToAccount(address _contract, address _coinJoin) external delegateCall {
    uint256 _coinsToExit = ICoinJoin(_coinJoin).safeEngine().coinBalance(address(this));
    _exitSystemCoinsToAccount(_contract, _coinJoin, _coinsToExit);
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
}
