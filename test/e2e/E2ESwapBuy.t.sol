// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

import {RETH, WETH, WSTETH} from '@script/Registry.s.sol';
import {IERC20Detailed} from '@aave-core-v3/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol';
import {IPoolAddressesProvider} from '@aave-core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {IParaSwapAugustusRegistry} from '@aave-debt-swap/dependencies/paraswap/IParaSwapAugustusRegistry.sol';
import {AugustusRegistry} from '@aave-debt-swap/dependencies/paraswap/AugustusRegistry.sol';
import {AaveV3Arbitrum, AaveV3ArbitrumAssets} from '@aave-address-book/AaveV3Arbitrum.sol';
import {BaseTest} from '@aave-debt-swap-test/utils/BaseTest.sol';
import {ParaswapAdapter} from 'src/leverage/ParaswapAdapter.sol';

contract E2ESwapBuy is BaseTest {
  ParaswapAdapter public paraswapAdapter;
  mapping(bytes32 => address) public assets;

  event Bought(address indexed fromAsset, address indexed toAsset, uint256 amountSold, uint256 receivedAmount);

  function setUp() public virtual override {
    super.setUp();
    vm.createSelectFork(vm.rpcUrl('mainnet'));
    paraswapAdapter = new ParaswapAdapter(
      IPoolAddressesProvider(address(AaveV3Arbitrum.POOL_ADDRESSES_PROVIDER)),
      address(AaveV3Arbitrum.POOL),
      IParaSwapAugustusRegistry(AugustusRegistry.ARBITRUM)
    );

    assets[RETH] = AaveV3ArbitrumAssets.rETH_UNDERLYING;
    assets[WETH] = AaveV3ArbitrumAssets.WETH_UNDERLYING;
    assets[WSTETH] = AaveV3ArbitrumAssets.wstETH_UNDERLYING;
  }

  modifier buy(uint256 _amountToBuy) {
    _amountToBuy = bound(_amountToBuy, 1e15, 4000 ether);
    _;
  }

  // FUZZ TESTS
  function testFromRethToWeth(uint256 _amountToBuy, bool _swapAll) public buy(_amountToBuy) {
    _swapBuy(assets[RETH], assets[WETH], _amountToBuy, _swapAll);
  }

  // function testFromRethToWsteth(uint256 _amountToBuy, bool _swapAll) public buy(_amountToBuy) {
  //   _swapBuy(assets[RETH], assets[WSTETH], _amountToBuy, _swapAll);
  // }

  // function testFromWstethToWeth(uint256 _amountToBuy, bool _swapAll) public buy(_amountToBuy) {
  //   _swapBuy(assets[WSTETH], assets[WETH], _amountToBuy, _swapAll);
  // }

  // function testFromWstethToReth(uint256 _amountToBuy, bool _swapAll) public buy(_amountToBuy) {
  //   _swapBuy(assets[WSTETH], assets[RETH], _amountToBuy, _swapAll);
  // }

  // function testFromWethToReth(uint256 _amountToBuy, bool _swapAll) public buy(_amountToBuy) {
  //   _swapBuy(assets[WETH], assets[RETH], _amountToBuy, _swapAll);
  // }

  // function testFromWethToWsteth(uint256 _amountToBuy, bool _swapAll) public buy(_amountToBuy) {
  //   _swapBuy(assets[WETH], assets[WSTETH], _amountToBuy, _swapAll);
  // }

  // HELPER FUNCTION
  function _swapBuy(address _fromAsset, address _toAsset, uint256 _amountToBuy, bool _swapAll) internal {
    PsPResponse memory _psp = _fetchPSPRouteWithoutPspCacheUpdate({
      from: _fromAsset,
      to: _toAsset,
      amount: _amountToBuy,
      userAddress: user,
      sell: false,
      max: _swapAll
    });

    if (_swapAll) {
      _checkAmountInParaSwapCalldata({offset: _psp.offset, amount: _amountToBuy, swapCalldata: _psp.swapCalldata});
    }

    deal(_fromAsset, address(paraswapAdapter), _psp.srcAmount);

    uint256 beforeBalanceAdapter = IERC20Detailed(_fromAsset).balanceOf(address(paraswapAdapter));

    vm.expectEmit(true, true, false, false, address(paraswapAdapter));
    emit Bought(_fromAsset, _toAsset, _psp.srcAmount, _psp.destAmount);

    paraswapAdapter.buyOnParaSwap({
      toAmountOffset: _psp.offset,
      paraswapData: abi.encode(_psp.swapCalldata, _psp.augustus),
      assetToSwapFrom: IERC20Detailed(_fromAsset),
      assetToSwapTo: IERC20Detailed(_toAsset),
      maxAmountToSwap: _psp.srcAmount,
      amountToReceive: _amountToBuy
    });

    uint256 afterBalanceAdapter = IERC20Detailed(_fromAsset).balanceOf(address(paraswapAdapter));

    assertGe(_psp.srcAmount, beforeBalanceAdapter - afterBalanceAdapter, 'OVER-CONSUMED');
    assertGt(_psp.destAmount, 0, 'ZERO-DST-AMOUNT');
    assertGe(IERC20Detailed(_toAsset).balanceOf(address(paraswapAdapter)), _amountToBuy, 'RECEIVED BELOW QUOTE');
  }
}
