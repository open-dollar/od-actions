// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Common} from '@opendollar/test/e2e/Common.t.sol';
import {Math} from '@opendollar/libraries/Math.sol';
import {ODProxy} from '@opendollar/contracts/proxies/ODProxy.sol';
import {ISAFEEngine} from '@opendollar/interfaces/ISAFEEngine.sol';
import {ExitActions} from 'src/leverage/ExitActions.sol';

contract CommonTest is Common {
  using Math for uint256;

  address public aliceProxy;
  address public bobProxy;
  address public deployerProxy;

  ExitActions public exitActions;

  mapping(address proxy => uint256 safeId) public vaults;

  function _deployOrFind(address _owner) internal returns (address) {
    address proxy = vault721.getProxy(_owner);
    if (proxy == address(0)) {
      return address(vault721.build(_owner));
    } else {
      return proxy;
    }
  }

  function _openSafe(address _proxy, bytes32 _cType) internal {
    vm.prank(_proxy);
    vaults[_proxy] = safeManager.openSAFE(_cType, _proxy);
  }

  function _lockCollateral(bytes32 _cType, uint256 _safeId, uint256 _deltaWad, address _proxy) internal {
    vm.startPrank(ODProxy(_proxy).OWNER());
    bytes memory _payload = abi.encodeWithSelector(
      exitActions.lockTokenCollateral.selector,
      address(safeManager),
      address(collateralJoin[_cType]),
      _safeId,
      _deltaWad
    );
    ODProxy(_proxy).execute(address(exitActions), _payload);
    vm.stopPrank();
  }

  function _genDebtToAccount(address _contract, uint256 _safeId, uint256 _deltaWad, address _proxy) internal {
    vm.startPrank(ODProxy(_proxy).OWNER());
    bytes memory _payload = abi.encodeWithSelector(
      exitActions.generateDebtToAccount.selector, _contract, address(safeManager), address(coinJoin), _safeId, _deltaWad
    );
    ODProxy(_proxy).execute(address(exitActions), _payload);
  }

  function _genDebtToProxy(uint256 _safeId, uint256 _deltaWad, address _proxy) internal {
    vm.startPrank(ODProxy(_proxy).OWNER());
    bytes memory _payload = abi.encodeWithSelector(
      exitActions.generateDebtToProxy.selector, address(safeManager), address(coinJoin), _safeId, _deltaWad
    );
    ODProxy(_proxy).execute(address(exitActions), _payload);
  }

  function _genInternalDebt(uint256 _safeId, uint256 _deltaWad, address _proxy) internal {
    vm.startPrank(ODProxy(_proxy).OWNER());
    bytes memory _payload =
      abi.encodeWithSelector(exitActions.generateInternalDebt.selector, address(safeManager), _safeId, _deltaWad);
    ODProxy(_proxy).execute(address(exitActions), _payload);
  }

  function _depositCollateralAndGenDebt(
    bytes32 _cType,
    uint256 _safeId,
    uint256 _collatAmount,
    uint256 _deltaWad,
    address _proxy
  ) internal {
    vm.startPrank(ODProxy(_proxy).OWNER());
    bytes memory _payload = abi.encodeWithSelector(
      exitActions.lockTokenCollateralAndGenerateDebt.selector,
      address(safeManager),
      address(collateralJoin[_cType]),
      address(coinJoin),
      _safeId,
      _collatAmount,
      _deltaWad
    );
    ODProxy(_proxy).execute(address(exitActions), _payload);
    vm.stopPrank();
  }

  function _depositCollateralAndGenDebtToAccount(
    address _account,
    bytes32 _cType,
    uint256 _safeId,
    uint256 _collatAmount,
    uint256 _deltaWad,
    address _proxy
  ) internal {
    vm.startPrank(ODProxy(_proxy).OWNER());
    bytes memory _payload = abi.encodeWithSelector(
      exitActions.lockTokenCollateralAndGenerateDebtToAccount.selector,
      _account,
      address(safeManager),
      address(collateralJoin[_cType]),
      address(coinJoin),
      _safeId,
      _collatAmount,
      _deltaWad
    );
    ODProxy(_proxy).execute(address(exitActions), _payload);
    vm.stopPrank();
  }

  function _exitCoin(address _proxy, uint256 _amount) internal {
    vm.startPrank(ODProxy(_proxy).OWNER());
    bytes memory _payload = abi.encodeWithSelector(exitActions.exitSystemCoins.selector, address(coinJoin), _amount);
    ODProxy(_proxy).execute(address(exitActions), _payload);
    vm.stopPrank();
  }

  function _exitAllCoin(address _proxy) internal {
    vm.startPrank(ODProxy(_proxy).OWNER());
    bytes memory _payload = abi.encodeWithSelector(exitActions.exitAllSystemCoins.selector, address(coinJoin));
    ODProxy(_proxy).execute(address(exitActions), _payload);
    vm.stopPrank();
  }

  function _exitCoinToAccount(address _proxy, address _contract, uint256 _amount) internal {
    vm.startPrank(ODProxy(_proxy).OWNER());
    bytes memory _payload =
      abi.encodeWithSelector(exitActions.exitSystemCoinsToAccount.selector, _contract, address(coinJoin), _amount);
    ODProxy(_proxy).execute(address(exitActions), _payload);
    vm.stopPrank();
  }

  function _exitAllCoinToAccount(address _proxy, address _contract) internal {
    vm.startPrank(ODProxy(_proxy).OWNER());
    bytes memory _payload =
      abi.encodeWithSelector(exitActions.exitAllSystemCoinsToAccount.selector, _contract, address(coinJoin));
    ODProxy(_proxy).execute(address(exitActions), _payload);
    vm.stopPrank();
  }

  function _getSAFE(bytes32 _cType, address _safe) internal view returns (uint256 _collateral, uint256 _debt) {
    ISAFEEngine.SAFE memory _safeData = safeEngine.safes(_cType, _safe);
    _collateral = _safeData.lockedCollateral;
    _debt = _safeData.generatedDebt;
  }
}
