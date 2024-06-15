// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {MintableERC20} from '@opendollar/contracts/for-test/MintableERC20.sol';
import {TKN} from '@opendollar/test/e2e/Common.t.sol';
import {CommonTest} from 'test/CommonTest.t.sol';

contract E2ELeverageCalculator is CommonTest {
  address public constant LEVERAGE_HANDLER = address(0x1111);
  address public leverageHandlerProxy;

  function setUp() public virtual override {
    super.setUp();
    MintableERC20(token).mint(address(this), DEPOSIT);

    leverageHandlerProxy = _deployOrFind(LEVERAGE_HANDLER);

    vm.prank(LEVERAGE_HANDLER);
    IERC20(token).approve(leverageHandlerProxy, type(uint256).max);

    vm.prank(aliceProxy);
    safeManager.allowSAFE(vaults[aliceProxy], leverageHandlerProxy, true);
  }

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

  function testCalcSingleSwap() public {
    _lockCollateral(TKN, vaults[aliceProxy], DEPOSIT, aliceProxy);
    uint256 _leverageAmount = leverageCalculator.calculateSingleLeverage(vaults[aliceProxy]);
    _genDebtToAccount(LEVERAGE_HANDLER, vaults[aliceProxy], _leverageAmount, aliceProxy);
    assertEq(systemCoin.balanceOf(LEVERAGE_HANDLER), _leverageAmount);

    vm.prank(LEVERAGE_HANDLER);
    _swapIn(LEVERAGE_HANDLER, _leverageAmount);
    _swapOut(LEVERAGE_HANDLER);

    assertEq(systemCoin.balanceOf(LEVERAGE_HANDLER), 0);
    assertEq(IERC20(token).balanceOf(LEVERAGE_HANDLER), _leverageAmount);

    vm.prank(LEVERAGE_HANDLER);
    _lockCollateral(TKN, vaults[aliceProxy], _leverageAmount, leverageHandlerProxy);
  }

  /// SIMULATION FUNCTIONS
  mapping(address => uint256) swapIn;

  /**
   * @dev to simulate swaps in tests
   */
  function _swapIn(address _sender, uint256 _amount) internal {
    require(systemCoin.transfer(address(this), _amount), 'SwapInFail');
    swapIn[_sender] = _amount;
  }

  function _swapOut(address _receiver) internal {
    IERC20(token).transfer(_receiver, swapIn[_receiver]);
  }
}
