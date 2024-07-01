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

  address userProxy;
  address sellAdapterProxy;

  IParaswapSellAdapter public sellAdapter;
  IVault721.NFVState public userNFV;

  function setUp() public virtual override {
    super.setUp();
    userProxy = _deployOrFind(USER);
    _openSafe(userProxy, RETH);

    vm.prank(USER);
    IERC20(RETH_ADDR).approve(userProxy, type(uint256).max);

    userNFV = vault721.getNfvState(vaults[userProxy]);

    sellAdapter =
      new ParaswapSellAdapter(AugustusRegistry.ARBITRUM, PARASWAP_AUGUSTUS_SWAPPER, AAVE_POOL_ADDRESS_PROVIDER);

    SELL_ADAPTER = address(sellAdapter);

    sellAdapterProxy = _deployOrFind(SELL_ADAPTER);

    vm.prank(SELL_ADAPTER);
    IERC20(RETH_ADDR).approve(sellAdapterProxy, type(uint256).max);

    vm.prank(userProxy);
    safeManager.allowSAFE(vaults[userProxy], sellAdapterProxy, true);
  }

  function testRequestFlashloan() public {
    deal(WETH_ADDR, USER, PREMIUM);
    bytes memory _res = abi.encodePacked(bytes32(0x0));

    IParaswapSellAdapter.SellParams memory _sellParams =
      IParaswapSellAdapter.SellParams(0, _res, RETH_ADDR, WETH_ADDR, SELL_AMOUNT);

    vm.startPrank(USER);
    _supply(SELL_ADAPTER, WETH_ADDR, PREMIUM);

    assertEq(IERC20(WETH_ADDR).balanceOf(SELL_ADAPTER), PREMIUM);

    sellAdapter.requestFlashloan(_sellParams);
    assertEq(IERC20(WETH_ADDR).balanceOf(SELL_ADAPTER), 0);

    vm.stopPrank;
  }

  /**
   * @dev lock collateral in USER safe from sellAdapterProxy
   * and mint debt from USER safe to sellAdapterProxy
   */
  function testLockCollateralFromHandler() public {
    deal(RETH_ADDR, SELL_ADAPTER, SELL_AMOUNT);

    (uint256 _initCollateral,) = _getSAFE(RETH, userNFV.safeHandler);
    assertEq(_initCollateral, 0);

    vm.prank(SELL_ADAPTER);
    _lockCollateral(RETH, vaults[userProxy], SELL_AMOUNT, sellAdapterProxy);

    (uint256 _newCollateral,) = _getSAFE(RETH, userNFV.safeHandler);
    assertEq(_newCollateral, SELL_AMOUNT);

    assertEq(systemCoin.balanceOf(SELL_ADAPTER), 0);
    vm.prank(SELL_ADAPTER);
    _genDebtToAccount(SELL_ADAPTER, vaults[userProxy], SELL_AMOUNT * 2 / 3, sellAdapterProxy);
    assertEq(systemCoin.balanceOf(SELL_ADAPTER), SELL_AMOUNT * 2 / 3);
  }
}
