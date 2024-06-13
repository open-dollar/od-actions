// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Common, TKN} from '@opendollar/test/e2e/Common.t.sol';
import {Math, RAY, RAD, WAD} from '@opendollar/libraries/Math.sol';
import {ODProxy} from '@opendollar/contracts/proxies/ODProxy.sol';
import {ERC20ForTest} from '@opendollar/test/mocks/ERC20ForTest.sol';
import {IVault721} from '@opendollar/interfaces/proxies/IVault721.sol';
import {ISAFEEngine} from '@opendollar/interfaces/ISAFEEngine.sol';
import {IOracleRelayer} from '@opendollar/interfaces/IOracleRelayer.sol';
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

  function _depositCollateralAndGenDebt(
    bytes32 _cType,
    uint256 _safeId,
    uint256 _collatAmount,
    uint256 _deltaWad,
    address _proxy
  ) internal {
    vm.startPrank(ODProxy(_proxy).OWNER());
    bytes memory _payload = abi.encodeWithSelector(
      basicActions.lockTokenCollateralAndGenerateDebt.selector,
      address(safeManager),
      address(collateralJoin[_cType]),
      address(coinJoin),
      _safeId,
      _collatAmount,
      _deltaWad
    );
    ODProxy(_proxy).execute(address(basicActions), _payload);
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
}
