// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Registry.s.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {IVault721} from '@opendollar/interfaces/proxies/IVault721.sol';
import {IDenominatedOracle} from '@opendollar/interfaces/oracles/IDenominatedOracle.sol';
import {DelayedOracleForTest} from '@opendollar/test/mocks/DelayedOracleForTest.sol';
import {AugustusRegistry} from '@aave-debt-swap/dependencies/paraswap/AugustusRegistry.sol';
import {ParaswapSellAdapter, IParaswapSellAdapter} from 'src/leverage/ParaswapSellAdapter.sol';
import {CommonTest} from 'test/e2e/common/CommonTest.t.sol';
import {Math} from '@opendollar/libraries/Math.sol';

contract E2ESwapExit is CommonTest {
  using Math for uint256;

  uint256 public constant PREMIUM = 500_000_000_000;
  uint256 public constant INTEREST_RATE_MODE = 0;
  uint16 public constant REF_CODE = 0;
  address public SELL_ADAPTER;

  address public userProxy;
  address public sellAdapterProxy;

  IParaswapSellAdapter public sellAdapter;
  IVault721.NFVState public userNFV;

  IDenominatedOracle public rethOracle;
  uint256 rethUsdPrice;

  function setUp() public virtual override {
    super.setUp();
    rethOracle = IDenominatedOracle(MAINNET_DENOMINATED_RETH_USD_ORACLE);
    (rethUsdPrice,) = rethOracle.getResultWithValidity();
    setCTypePrice(RETH, rethUsdPrice);

    userProxy = _deployOrFind(USER);
    label(USER, 'USER-WALLET');
    label(userProxy, 'USER-PROXY');
    _openSafe(userProxy, RETH);

    vm.prank(USER);
    IERC20Metadata(RETH_ADDR).approve(userProxy, type(uint256).max);

    userNFV = vault721.getNfvState(vaults[userProxy]);

    sellAdapter = new ParaswapSellAdapter(
      address(systemCoin),
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
    label(SELL_ADAPTER, 'SELL-ADAPTER-CONTRACT');
    label(sellAdapterProxy, 'SELL-ADAPTER-PROXY');

    vm.startPrank(SELL_ADAPTER);
    IERC20Metadata(RETH_ADDR).approve(sellAdapterProxy, type(uint256).max);
    IERC20Metadata(OD_ADDR).approve(sellAdapterProxy, type(uint256).max);
    vm.stopPrank();
  }

  /**
   * todo: test with initial deposit of collateral
   * initial deposit + loan to overcome the over-collateralization "loss"
   * in being able to returning to loan in full + premium
   */
  function testRequestFlashloan() public {
    assertEq(readCTypePrice(RETH), rethUsdPrice);
    uint256 _collateralLoan = 1 ether;
    uint256 _sellAmount = (_collateralLoan.wmul(rethUsdPrice) - PREMIUM) * 2 / 3;
    emit log_named_uint('DEBT SELL     AMOUNT', _sellAmount);

    (uint256 _dstAmount, IParaswapSellAdapter.SellParams memory _sellParams) =
      _getFullUserInputWithAmount(OD_ADDR, RETH_ADDR, _sellAmount);

    // todo: lock initial capital in safe
    uint256 _initCapital = _collateralLoan / 2;
    deal(RETH_ADDR, USER, _initCapital);

    vm.prank(userProxy);
    safeManager.allowSAFE(vaults[userProxy], sellAdapterProxy, true);

    vm.startPrank(USER);
    IERC20Metadata(RETH_ADDR).approve(SELL_ADAPTER, _initCapital);
    sellAdapter.deposit(RETH_ADDR, _initCapital);

    // assertEq(IERC20Metadata(RETH_ADDR).balanceOf(SELL_ADAPTER), _initCapital);
    // assertEq(IERC20Metadata(OD_ADDR).balanceOf(SELL_ADAPTER), 0);

    sellAdapter.requestFlashloan(_sellParams, _collateralLoan, _dstAmount, vaults[userProxy], RETH);
    // assertEq(IERC20Metadata(RETH_ADDR).balanceOf(SELL_ADAPTER), 0);

    vm.stopPrank();
  }

  function setCTypePrice(bytes32 _cType, uint256 _price) public {
    DelayedOracleForTest(address(delayedOracle[_cType])).setPriceAndValidity(_price, true);
    oracleRelayer.updateCollateralPrice(_cType);
  }

  function readCTypePrice(bytes32 _cType) public returns (uint256 _price) {
    _price = delayedOracle[_cType].read();
  }
}
