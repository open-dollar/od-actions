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

  address reth;
  address wsteth;
  address userProxy;

  IParaswapSellAdapter public sellAdapter;
  IVault721.NFVState public userNFV;

  function setUp() public virtual override {
    super.setUp();

    reth = address(collateral[RETH]);
    wsteth = address(collateral[WSTETH]);

    userProxy = _deployOrFind(USER);
    _openSafe(userProxy, RETH);

    vm.prank(USER);
    IERC20(token).approve(userProxy, type(uint256).max);

    userNFV = vault721.getNfvState(vaults[userProxy]);

    sellAdapter =
      new ParaswapSellAdapter(AugustusRegistry.ARBITRUM, PARASWAP_AUGUSTUS_SWAPPER, AAVE_POOL_ADDRESS_PROVIDER);
  }

  function testRequestFlashloan() public {
    vm.startPrank(USER);
    _supply(address(sellAdapter), RETH_ADDR, PREMIUM);

    assertEq(IERC20(RETH_ADDR).balanceOf(address(sellAdapter)), PREMIUM);

    sellAdapter.requestFlashloan(RETH_ADDR, SELL_AMOUNT);
    assertEq(IERC20(RETH_ADDR).balanceOf(address(sellAdapter)), 0);

    vm.stopPrank;
  }
}
