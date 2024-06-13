// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Registry.s.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {MintableERC20} from '@opendollar/contracts/for-test/MintableERC20.sol';
import {IVault721} from '@opendollar/interfaces/proxies/IVault721.sol';
import {RAY} from '@opendollar/libraries/Math.sol';
import {TKN} from '@opendollar/test/e2e/Common.t.sol';
import {ExitActions} from 'src/leverage/ExitActions.sol';
import {CommonTest} from 'test/CommonTest.t.sol';

contract E2ECoinExit is CommonTest {
  uint256 public constant DEPOSIT = 10_000 ether;
  uint256 public constant MINT = DEPOSIT * 2 / 3;

  address public arbitraryContract = address(0x1234abcd);
  address public token;
  IVault721.NFVState public aliceNFV;

  function setUp() public virtual override {
    super.setUp();
    exitActions = new ExitActions();
    token = address(collateral[TKN]);

    aliceProxy = _deployOrFind(alice);
    _openSafe(aliceProxy, TKN);

    MintableERC20(token).mint(alice, DEPOSIT);

    vm.prank(alice);
    IERC20(token).approve(aliceProxy, type(uint256).max);

    aliceNFV = vault721.getNfvState(vaults[aliceProxy]);
  }

  function testLockCollateral() public {
    (uint256 _c1, uint256 _d1) = _getSAFE(TKN, aliceNFV.safeHandler);
    assertEq(_c1, 0);
    assertEq(_d1, 0);
    _lockCollateral(TKN, vaults[aliceProxy], DEPOSIT, aliceProxy);
    (uint256 _c2, uint256 _d2) = _getSAFE(TKN, aliceNFV.safeHandler);
    assertEq(_c2, DEPOSIT);
    assertEq(_d2, 0);
  }

  function testLockCollateralAndGebDebtToAccount() public {
    _lockCollateral(TKN, vaults[aliceProxy], DEPOSIT, aliceProxy);
    _genDebtToAccount(arbitraryContract, vaults[aliceProxy], MINT, aliceProxy);
    (uint256 _c, uint256 _d) = _getSAFE(TKN, aliceNFV.safeHandler);
    assertEq(_c, DEPOSIT);
    assertEq(_d, MINT);
    assertEq(systemCoin.balanceOf(arbitraryContract), MINT);
    assertEq(systemCoin.balanceOf(alice), 0);
  }

  function testLockCollateralAndGebDebtToProxy() public {
    _lockCollateral(TKN, vaults[aliceProxy], DEPOSIT, aliceProxy);
    _genDebtToProxy(vaults[aliceProxy], MINT, aliceProxy);
    (uint256 _c, uint256 _d) = _getSAFE(TKN, aliceNFV.safeHandler);
    assertEq(_c, DEPOSIT);
    assertEq(_d, MINT);
    assertEq(systemCoin.balanceOf(aliceProxy), MINT);
    assertEq(systemCoin.balanceOf(alice), 0);
  }

  function testLockCollateralAndGebInternalDebt() public {
    _lockCollateral(TKN, vaults[aliceProxy], DEPOSIT, aliceProxy);
    _genInternalDebt(vaults[aliceProxy], MINT, aliceProxy);
    (uint256 _c, uint256 _d) = _getSAFE(TKN, aliceNFV.safeHandler);
    assertEq(_c, DEPOSIT);
    assertEq(_d, MINT);
    assertEq(systemCoin.balanceOf(aliceProxy), 0);
    assertEq(systemCoin.balanceOf(alice), 0);
  }

  function testLockCollateralAndGebInternalDebtAndExitToUser() public {
    _lockCollateral(TKN, vaults[aliceProxy], DEPOSIT, aliceProxy);
    _genInternalDebt(vaults[aliceProxy], MINT, aliceProxy);
    (uint256 _c, uint256 _d) = _getSAFE(TKN, aliceNFV.safeHandler);
    assertEq(_c, DEPOSIT);
    assertEq(_d, MINT);
    assertEq(systemCoin.balanceOf(aliceProxy), 0);
    assertEq(systemCoin.balanceOf(alice), 0);

    /// @notice when using basicActions.exitSystemCoins, COIN amount must be in RAY
    _exitCoin(aliceProxy, MINT / 2 * RAY);
    assertEq(systemCoin.balanceOf(alice), MINT / 2);
  }

  function testLockCollateralAndGebInternalDebtAndExitAllToUser() public {
    _lockCollateral(TKN, vaults[aliceProxy], DEPOSIT, aliceProxy);
    _genInternalDebt(vaults[aliceProxy], MINT, aliceProxy);

    assertEq(systemCoin.balanceOf(alice), 0);
    _exitAllCoin(aliceProxy);
    assertEq(systemCoin.balanceOf(alice), MINT);
  }

  function testLockCollateralAndGebInternalDebtAndExitToAccount() public {
    _lockCollateral(TKN, vaults[aliceProxy], DEPOSIT, aliceProxy);
    _genInternalDebt(vaults[aliceProxy], MINT, aliceProxy);

    _exitCoinToAccount(aliceProxy, arbitraryContract, MINT / 2);
    assertEq(systemCoin.balanceOf(arbitraryContract), MINT / 2);
  }

  function testLockCollateralAndGebInternalDebtAndExitAllToAccount() public {
    _lockCollateral(TKN, vaults[aliceProxy], DEPOSIT, aliceProxy);
    _genInternalDebt(vaults[aliceProxy], MINT, aliceProxy);

    _exitAllCoinToAccount(aliceProxy, arbitraryContract);
    assertEq(systemCoin.balanceOf(arbitraryContract), MINT);
  }

  function testDepositCollateralAndGenDebtToAccount() public {
    _depositCollateralAndGenDebtToAccount(arbitraryContract, TKN, vaults[aliceProxy], DEPOSIT, MINT, aliceProxy);

    assertEq(systemCoin.balanceOf(arbitraryContract), MINT);
    assertEq(systemCoin.balanceOf(alice), 0);
  }
}
