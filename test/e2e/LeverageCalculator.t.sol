// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {MintableERC20} from '@opendollar/contracts/for-test/MintableERC20.sol';
import {RAY} from '@opendollar/libraries/Math.sol';
import {TKN} from '@opendollar/test/e2e/Common.t.sol';
import {ExitActions} from 'src/leverage/ExitActions.sol';
import {LeverageCalculator} from 'src/leverage/LeverageCalculator.sol';
import {CommonTest} from 'test/CommonTest.t.sol';

contract E2ELeverageCalculator is CommonTest {
  function testLockCollateral() public {
    _lockCollateral(TKN, vaults[aliceProxy], DEPOSIT, aliceProxy);
    (uint256 _collateral,) = leverageCalculator.getNFVLockedAndDebt(TKN, aliceNFV.safeHandler);
    assertEq(_collateral, DEPOSIT);
  }

  /// @notice exited coins transfered to proxy
  function testLockAndGenerateDebtToProxy() public {
    _lockCollateral(TKN, vaults[aliceProxy], DEPOSIT, aliceProxy);
    _genDebtToProxy(vaults[aliceProxy], MINT, aliceProxy);
    (, uint256 _debt) = leverageCalculator.getNFVLockedAndDebt(TKN, aliceNFV.safeHandler);
    assertEq(_debt, MINT);
    uint256 _internalDebt = leverageCalculator.getCoinBalance(aliceProxy);
    assertEq(_internalDebt, 0);
  }

  /// @notice internal coins are available to proxy
  function testLockAndGenerateInternalDebt() public {
    _lockCollateral(TKN, vaults[aliceProxy], DEPOSIT, aliceProxy);
    _genInternalDebt(vaults[aliceProxy], MINT, aliceProxy);
    (, uint256 _debt) = leverageCalculator.getNFVLockedAndDebt(TKN, aliceNFV.safeHandler);
    assertEq(_debt, MINT);
    uint256 _internalDebt = leverageCalculator.getCoinBalance(aliceProxy);
    assertEq(_internalDebt, _debt);
  }

  /// @notice 1/2 internal coins were exited to proxy
  function testLockAndGenerateInternalDebtAndPartialExitToProxy() public {
    _lockCollateral(TKN, vaults[aliceProxy], DEPOSIT, aliceProxy);
    _genInternalDebt(vaults[aliceProxy], MINT, aliceProxy);
    assertEq(systemCoin.balanceOf(aliceProxy), 0);

    _exitCoinToAccount(aliceProxy, aliceProxy, MINT / 2);
    (, uint256 _debt) = leverageCalculator.getNFVLockedAndDebt(TKN, aliceNFV.safeHandler);
    assertEq(_debt, MINT);

    uint256 _internalDebt = leverageCalculator.getCoinBalance(aliceProxy);
    assertEq(_internalDebt, _debt / 2);
    assertEq(systemCoin.balanceOf(aliceProxy), MINT / 2);
  }
}
