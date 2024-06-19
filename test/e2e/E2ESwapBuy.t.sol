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
  mapping(bytes32 => address) internal _assets;

  event Bought(address indexed fromAsset, address indexed toAsset, uint256 amountSold, uint256 receivedAmount);

  function setUp() public virtual override {
    super.setUp();
    vm.createSelectFork(vm.rpcUrl('mainnet'));
    paraswapAdapter = new ParaswapAdapter(
      IPoolAddressesProvider(address(AaveV3Arbitrum.POOL_ADDRESSES_PROVIDER)),
      address(AaveV3Arbitrum.POOL),
      IParaSwapAugustusRegistry(AugustusRegistry.ARBITRUM)
    );

    _assets[RETH] = AaveV3ArbitrumAssets.rETH_UNDERLYING;
    _assets[WETH] = AaveV3ArbitrumAssets.WETH_UNDERLYING;
    _assets[WSTETH] = AaveV3ArbitrumAssets.wstETH_UNDERLYING;
  }

  modifier buy(uint256 _amountToBuy) {
    _amountToBuy = bound(amountToBuy, 1e15, 4000 ether);
    _;
  }

  // static-tests
  function fromRethToWeth(uint256 _amountToBuy, bool _swapAll) public buy(_amountToBuy) {
    address assetToSwapFrom = _assets[fromAssetIndex];
    address assetToSwapTo = _assets[toAssetIndex];
  }

  function fromRethToWsteth(uint256 _amountToBuy, bool _swapAll) public buy(_amountToBuy) {}

  function fromWstethToWeth(uint256 _amountToBuy, bool _swapAll) public buy(_amountToBuy) {}

  function fromWstethToReth(uint256 _amountToBuy, bool _swapAll) public buy(_amountToBuy) {}

  function fromWethToReth(uint256 _amountToBuy, bool _swapAll) public buy(_amountToBuy) {}

  function fromWethToWsteth(uint256 _amountToBuy, bool _swapAll) public buy(_amountToBuy) {}

  // fuzz-test
}
