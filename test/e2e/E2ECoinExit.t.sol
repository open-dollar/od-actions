// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Registry.s.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {TKN, WSTETH} from '@opendollar/test/e2e/Common.t.sol';
import {MintableERC20} from '@opendollar/contracts/for-test/MintableERC20.sol';
import {ExitActions} from 'src/leverage/ExitActions.sol';
import {CommonTest} from 'test/CommonTest.t.sol';

contract E2ECoinExit is CommonTest {
  uint256 public constant DEPOSIT = 10_000 ether;
  uint256 public constant MINT = DEPOSIT * 2 / 3;

  address public arbitraryContract;
  address public token;

  function setUp() public virtual override {
    super.setUp();
    exitActions = new ExitActions();
    token = address(collateral[TKN]);

    aliceProxy = _deployOrFind(alice);
    _openSafe(aliceProxy, TKN);

    MintableERC20(token).mint(alice, DEPOSIT);

    vm.startPrank(alice);
    IERC20(token).approve(aliceProxy, type(uint256).max);
    _depositCollateralAndGenDebt(TKN, vaults[aliceProxy], DEPOSIT, MINT, aliceProxy);

    vm.stopPrank();
  }

  function testExitCoinToUser() public {
    uint256 _exitAmount = MINT / 2;
    _exitCoin(aliceProxy, _exitAmount);
    assertNotEq(systemCoin.balanceOf(alice), _exitAmount);
  }
}
