// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Strings} from '@openzeppelin/utils/Strings.sol';
import {Math} from '@opendollar/libraries/Math.sol';
import {ODProxy} from '@opendollar/contracts/proxies/ODProxy.sol';
import {IVault721} from '@opendollar/interfaces/proxies/IVault721.sol';
import {ISAFEEngine} from '@opendollar/interfaces/ISAFEEngine.sol';
import {Common, TKN} from '@opendollar/test/e2e/Common.t.sol';
import {DelayedOracleForTest} from '@opendollar/test/mocks/DelayedOracleForTest.sol';
import {ExitActions} from 'src/leverage/ExitActions.sol';
import {BaseTest} from 'test/e2e/common/BaseTest.t.sol';

contract CommonTest is Common, BaseTest {
  using Math for uint256;
  using Strings for uint256;

  uint256 public constant DEPOSIT = 10_000 ether;
  uint256 public constant MINT = DEPOSIT * 2 / 3;

  address public token;

  address public aliceProxy;
  address public bobProxy;
  address public deployerProxy;

  IVault721.NFVState public aliceNFV;

  ExitActions public exitActions;

  function setUp() public virtual override {
    _isCastTokens = true;
    super.setUp();
    exitActions = new ExitActions();
    token = address(collateral[TKN]);
  }

  function _setCTypePrice(bytes32 _cType, uint256 _price) internal {
    DelayedOracleForTest(address(delayedOracle[_cType])).setPriceAndValidity(_price, true);
    oracleRelayer.updateCollateralPrice(_cType);
  }

  function _readCTypePrice(bytes32 _cType) internal view returns (uint256 _price) {
    _price = delayedOracle[_cType].read();
  }

  function _deployOrFind(address _owner) internal returns (address _proxy) {
    _proxy = vault721.getProxy(_owner);
    if (_proxy == address(0)) {
      return address(vault721.build(_owner));
    } else {
      return _proxy;
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
    vm.stopPrank();
  }

  function _genDebtToProxy(uint256 _safeId, uint256 _deltaWad, address _proxy) internal {
    vm.startPrank(ODProxy(_proxy).OWNER());
    bytes memory _payload = abi.encodeWithSelector(
      exitActions.generateDebtToProxy.selector, address(safeManager), address(coinJoin), _safeId, _deltaWad
    );
    ODProxy(_proxy).execute(address(exitActions), _payload);
    vm.stopPrank();
  }

  function _genInternalDebt(uint256 _safeId, uint256 _deltaWad, address _proxy) internal {
    vm.startPrank(ODProxy(_proxy).OWNER());
    bytes memory _payload =
      abi.encodeWithSelector(exitActions.generateInternalDebt.selector, address(safeManager), _safeId, _deltaWad);
    ODProxy(_proxy).execute(address(exitActions), _payload);
    vm.stopPrank();
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

  function _floatingPointWad(uint256 _num) internal pure returns (string memory _formatNum) {
    uint256 _left = _num / 1e18;
    uint256 _expLeft = _left * 1e18;
    uint256 _right = _num - _expLeft;

    return string.concat(_left.toString(), '.', _right.toString());
  }

  function _floatingPointWad(uint256 _num, uint256 _decimalDivider) internal pure returns (string memory _formatNum) {
    uint256 _left = _num / 1e18;
    uint256 _expLeft = _left * 1e18;
    uint256 _expRight = _num - _expLeft;
    uint256 _right;
    if (_decimalDivider > 0 && _decimalDivider < 1e18 + 1) _right = _expRight / _decimalDivider;
    else _right = _expRight;

    return string.concat(_left.toString(), '.', _right.toString());
  }
}
