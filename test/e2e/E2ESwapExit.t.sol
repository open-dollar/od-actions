// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Registry.s.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {IVault721} from '@opendollar/interfaces/proxies/IVault721.sol';
import {AugustusRegistry} from '@aave-debt-swap/dependencies/paraswap/AugustusRegistry.sol';
import {ParaswapSellAdapter, IParaswapSellAdapter} from 'src/leverage/ParaswapSellAdapter.sol';
import {CommonTest} from 'test/e2e/common/CommonTest.t.sol';

contract E2ESwapExit is CommonTest {
  uint256 public constant PREMIUM = 500_000_000_000;
  uint256 public constant INTEREST_RATE_MODE = 0;
  uint16 public constant REF_CODE = 0;
  address public SELL_ADAPTER;

  address public userProxy;
  address public sellAdapterProxy;

  IParaswapSellAdapter public sellAdapter;
  IVault721.NFVState public userNFV;

  function setUp() public virtual override {
    super.setUp();
    userProxy = _deployOrFind(USER);
    _openSafe(userProxy, RETH);

    vm.prank(USER);
    IERC20(RETH_ADDR).approve(userProxy, type(uint256).max);

    userNFV = vault721.getNfvState(vaults[userProxy]);

    sellAdapter = new ParaswapSellAdapter(
      AugustusRegistry.ARBITRUM,
      PARASWAP_AUGUSTUS_SWAPPER,
      AAVE_POOL_ADDRESS_PROVIDER,
      address(vault721),
      address(exitActions),
      address(collateralJoinFactory),
      address(coinJoin)
    );

    SELL_ADAPTER = address(sellAdapter);

    sellAdapterProxy = _deployOrFind(SELL_ADAPTER);

    vm.prank(SELL_ADAPTER);
    IERC20(RETH_ADDR).approve(sellAdapterProxy, type(uint256).max);
  }

  function testRequestFlashloan() public {
    uint256 _sellAmount = 1400 ether;

    // from OD to RETH
    (uint256 _dstAmount, IParaswapSellAdapter.SellParams memory _sellParams) =
      _getFullUserInputWithAmount(OD_ADDR, RETH_ADDR, _sellAmount);

    deal(RETH_ADDR, USER, PREMIUM);

    vm.prank(userProxy);
    safeManager.allowSAFE(vaults[userProxy], sellAdapterProxy, true);

    vm.startPrank(USER);
    IERC20(RETH_ADDR).approve(SELL_ADAPTER, PREMIUM);
    sellAdapter.deposit(RETH_ADDR, PREMIUM);

    assertEq(IERC20(RETH_ADDR).balanceOf(SELL_ADAPTER), PREMIUM);
    assertEq(IERC20(OD_ADDR).balanceOf(SELL_ADAPTER), 0);

    sellAdapter.requestFlashloan(_sellParams, _dstAmount, vaults[userProxy], RETH);
    // assertEq(IERC20(RETH_ADDR).balanceOf(SELL_ADAPTER), 0);

    vm.stopPrank();
  }

  /**
   * @dev lock collateral in USER safe from sellAdapterProxy
   * and mint debt from USER safe to sellAdapterProxy
   */
  // function testLockCollateralFromHandler() public {
  //   deal(RETH_ADDR, SELL_ADAPTER, SELL_AMOUNT);

  //   (uint256 _initCollateral,) = _getSAFE(RETH, userNFV.safeHandler);
  //   assertEq(_initCollateral, 0);

  //   vm.prank(SELL_ADAPTER);
  //   _lockCollateral(RETH, vaults[userProxy], SELL_AMOUNT, sellAdapterProxy);

  //   (uint256 _newCollateral,) = _getSAFE(RETH, userNFV.safeHandler);
  //   assertEq(_newCollateral, SELL_AMOUNT);

  //   assertEq(systemCoin.balanceOf(SELL_ADAPTER), 0);
  //   vm.prank(SELL_ADAPTER);
  //   _genDebtToAccount(SELL_ADAPTER, vaults[userProxy], SELL_AMOUNT * 2 / 3, sellAdapterProxy);
  //   assertEq(systemCoin.balanceOf(SELL_ADAPTER), SELL_AMOUNT * 2 / 3);
  // }
}
