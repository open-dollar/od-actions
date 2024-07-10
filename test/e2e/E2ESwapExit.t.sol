// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Registry.s.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {IVault721} from '@opendollar/interfaces/proxies/IVault721.sol';
import {IDenominatedOracle} from '@opendollar/interfaces/oracles/IDenominatedOracle.sol';
import {AugustusRegistry} from '@aave-debt-swap/dependencies/paraswap/AugustusRegistry.sol';
import {ParaswapSellAdapter, IParaswapSellAdapter} from 'src/leverage/ParaswapSellAdapter.sol';
import {CommonTest} from 'test/e2e/common/CommonTest.t.sol';
import {Math} from '@opendollar/libraries/Math.sol';

contract E2ESwapExit is CommonTest {
  using Math for uint256;

  uint256 public constant MAX_SLIPPAGE_PERCENT = 0.3e4;
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
    _setCTypePrice(RETH, rethUsdPrice);

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

  /// @dev example of locking collateral at same time of leveraging
  function testRequestFlashloan0() public {
    uint256 _initCapital = 0.1 ether;

    /// @notice locked 30% collateral independently from capital allocated to leverage (swap loss?)
    uint256 _additionalCapital = _initCapital * 30 / 100;

    _testRequestFlashLoan(_initCapital, _additionalCapital);
  }

  function testRequestFlashloan1() public {
    uint256 _initCapital = 0.5 ether;

    /// @notice locked 35% collateral independently from capital allocated to leverage (swap loss?)
    uint256 _additionalCapital = _initCapital * 35 / 100;

    _testRequestFlashLoan(_initCapital, _additionalCapital);
  }

  function testRequestFlashloan2() public {
    uint256 _initCapital = 1 ether;

    /// @notice locked 45% collateral independently from capital allocated to leverage (swap loss?)
    uint256 _additionalCapital = _initCapital * 45 / 100;

    _testRequestFlashLoan(_initCapital, _additionalCapital);
  }

  function testRequestFlashloan3() public {
    uint256 _initCapital = 5 ether;

    /// @notice locked 55% collateral independently from capital allocated to leverage (swap loss?)
    uint256 _additionalCapital = _initCapital * 55 / 100;

    _testRequestFlashLoan(_initCapital, _additionalCapital);
  }

  function testRequestFlashloan4() public {
    uint256 _initCapital = 10 ether;

    /// @notice locked 55% collateral independently from capital allocated to leverage (swap loss?)
    uint256 _additionalCapital = _initCapital * 60 / 100;

    _testRequestFlashLoan(_initCapital, _additionalCapital);
  }

  function testMath() public {
    // intial reth
    uint256 initialCollateral = 0.5 ether;

    // 100 / 1.35% = 74
    uint256 _percentMaxDebt = uint256(10_000) / uint256(135);
    emit log_named_uint('_percentMaxDebt     ', _percentMaxDebt);

    // 100 - 74 = 26
    uint256 _percentMakeUp = 100 - _percentMaxDebt;
    emit log_named_uint('_percentMakeUp  ', _percentMakeUp);

    uint256 _maxCollateral = initialCollateral * 100 / _percentMakeUp;
    emit log_named_uint('_maxCollateral  ', _maxCollateral);

    uint256 _maxTotalLoan = _maxCollateral - initialCollateral;
    emit log_named_uint('_maxTotalLoan   ', _maxTotalLoan);

    uint256 _maxLoan = _maxTotalLoan - (PREMIUM + MAX_SLIPPAGE_PERCENT);
    emit log_named_uint('_maxLoan        ', _maxLoan);
  }

  // Helper Functions
  function _calculateMaxLeverage(uint256 _initialCollateral, uint256 _safetyRatio) public returns (uint256) {
    emit log_named_uint('_currentRethPrice   ', rethUsdPrice);

    uint256 _percentMaxDebt = uint256(10_000) / _safetyRatio;
    uint256 _percentMakeUp = 100 - _percentMaxDebt;

    uint256 _maxCollateral = _initialCollateral * 100 / _percentMakeUp;
    emit log_named_uint('_maxCollateral      ', _maxCollateral);

    uint256 _maxTotalLoan = _maxCollateral - _initialCollateral;
    emit log_named_uint('_maxTotalLoan       ', _maxTotalLoan);

    return _maxTotalLoan;
  }

  function _testRequestFlashLoan(uint256 _initCapital, uint256 _additionalCapital) internal {
    uint256 _deposit = _initCapital + _additionalCapital;
    deal(RETH_ADDR, USER, _deposit);

    uint256 _maxLoan = _calculateMaxLeverage(_initCapital, 135);
    uint256 _sellAmount = _maxLoan.wmul(rethUsdPrice);
    emit log_named_uint('DEBT SELL     AMOUNT', _sellAmount);

    (uint256 _dstAmount, IParaswapSellAdapter.SellParams memory _sellParams) =
      _getFullUserInputWithAmount(OD_ADDR, RETH_ADDR, _sellAmount);

    vm.prank(userProxy);
    safeManager.allowSAFE(vaults[userProxy], sellAdapterProxy, true);

    vm.startPrank(USER);
    IERC20Metadata(RETH_ADDR).approve(SELL_ADAPTER, _deposit);
    sellAdapter.deposit(RETH_ADDR, _deposit);
    sellAdapter.requestFlashloan(_sellParams, _initCapital, _maxLoan, _dstAmount, vaults[userProxy], RETH);
    vm.stopPrank();

    _logFinalValues(_deposit);
  }

  function _logFinalValues(uint256 _deposit) internal {
    (uint256 _c, uint256 _d) = _getSAFE(RETH, userNFV.safeHandler);
    emit log_named_uint('ORIGINAL DEBT       ', 0);
    emit log_named_uint('FINAL DEBT          ', _d);
    emit log_named_uint('--------------------', 0);
    emit log_named_uint('ORIGINAL COLLATERAL ', _deposit);
    emit log_named_uint('FINAL COLLATERAL    ', _c);
    emit log_named_uint('LEVERAGE PERCENTAGE ', _c * 100 / _deposit);
  }
}
