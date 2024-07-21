// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Registry.s.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {ISAFEEngine} from '@opendollar/interfaces/ISAFEEngine.sol';
import {IVault721} from '@opendollar/interfaces/proxies/IVault721.sol';
import {IDenominatedOracle} from '@opendollar/interfaces/oracles/IDenominatedOracle.sol';
import {AugustusRegistry} from '@aave-debt-swap/dependencies/paraswap/AugustusRegistry.sol';
import {ParaswapSellAdapter, IParaswapSellAdapter, InitSellAdapter} from 'src/leverage/ParaswapSellAdapter.sol';
import {CommonTest} from 'test/e2e/common/CommonTest.t.sol';
import {Math, WAD} from '@opendollar/libraries/Math.sol';

contract E2ESwapExit is CommonTest {
  using Math for uint256;

  uint256 public constant MAX_SLIPPAGE_PERCENT = 0.3e4;
  uint256 public constant PREMIUM = 500_000_000_000;
  uint256 public constant INTEREST_RATE_MODE = 0;
  uint16 public constant REF_CODE = 0;
  uint256 public constant PERCENT = 135;

  IVault721.NFVState public userNFV;
  address public userProxy;

  IParaswapSellAdapter public sellAdapter;
  address public sellAdapterAddr;
  address public sellAdapterProxy;

  IDenominatedOracle public rethOracle;
  uint256 public rethUsdPrice;

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

    InitSellAdapter memory _init = InitSellAdapter(
      AugustusRegistry.ARBITRUM,
      PARASWAP_AUGUSTUS_SWAPPER,
      AAVE_POOL_ADDRESS_PROVIDER,
      address(vault721),
      address(exitActions),
      address(collateralJoinFactory),
      address(coinJoin)
    );

    sellAdapter = new ParaswapSellAdapter(_init);

    sellAdapterAddr = address(sellAdapter);

    sellAdapterProxy = _deployOrFind(sellAdapterAddr);
    label(sellAdapterAddr, 'SELL-ADAPTER-CONTRACT');
    label(sellAdapterProxy, 'SELL-ADAPTER-PROXY');

    vm.startPrank(sellAdapterAddr);
    IERC20Metadata(RETH_ADDR).approve(sellAdapterProxy, type(uint256).max);
    IERC20Metadata(OD_ADDR).approve(sellAdapterProxy, type(uint256).max);
    vm.stopPrank();
  }

  function testRequestFlashloan0() public {
    uint256 _initCapital = 0.00001 ether;
    _testRequestFlashLoan(_initCapital, PERCENT);
  }

  function testRequestFlashloan1() public {
    uint256 _initCapital = 1 ether;
    _testRequestFlashLoan(_initCapital, PERCENT);
  }

  function testRequestFlashloan2() public {
    uint256 _initCapital = 2 ether;
    _testRequestFlashLoan(_initCapital, PERCENT);
  }

  function testRequestFlashloan3() public {
    uint256 _initCapital = 4 ether;
    _testRequestFlashLoan(_initCapital, PERCENT);
  }

  function testRequestFlashloan4() public {
    uint256 _initCapital = 8 ether;
    _testRequestFlashLoan(_initCapital, PERCENT);
  }

  function testRequestFlashloan5() public {
    uint256 _initCapital = 9 ether;
    _testRequestFlashLoan(_initCapital, PERCENT);
  }

  /**
   * @notice hitting swap limits
   * revert not interpreting correctly
   */
  // function testRequestFlashloan6() public {
  //   uint256 _initCapital = 10 ether;
  //   vm.expectRevert();
  //   _testRequestFlashLoan(_initCapital, PERCENT);
  // }

  function testRequestFlashloan7() public {
    uint256 _initCapital = 10 ether;

    _testRequestFlashLoan(_initCapital, PERCENT + 5);
  }

  function testRequestFlashloan8() public {
    uint256 _initCapital = 10 ether;

    _testRequestFlashLoan(_initCapital, PERCENT + 10);
  }

  /**
   * @dev MaxLev = 1/(1-LTV)
   * Example:
   * LTV = 66.7% = 0.667
   * MaxLev = 1/(1 - 0.667) = 3
   */
  function _testRequestFlashLoan(uint256 _initCapital, uint256 _percent) internal {
    deal(RETH_ADDR, USER, _initCapital);

    // uint256 _multiplier = 10_000 / (100 - (100 - (_percent - 100)));
    uint256 _multiplier = 10_000 / (100 - (10_000 / _percent));
    emit log_named_uint('LTV', _multiplier);

    ISAFEEngine.SAFEEngineCollateralData memory _safeEngCData = safeEngine.cData(RETH);
    uint256 _accumulatedRate = _safeEngCData.accumulatedRate;
    uint256 _safetyPrice = _safeEngCData.safetyPrice;

    uint256 _loanAmount = (_initCapital * _multiplier / 100) - _initCapital;
    uint256 _leveragedDebt = _initCapital.wmul(_safetyPrice).wdiv(_accumulatedRate) * _multiplier / 100;

    (uint256 _dstAmount, IParaswapSellAdapter.SellParams memory _sellParams) =
      _getFullUserInputWithAmount(OD_ADDR, RETH_ADDR, _leveragedDebt);

    vm.prank(userProxy);
    safeManager.allowSAFE(vaults[userProxy], sellAdapterProxy, true);

    vm.startPrank(USER);
    IERC20Metadata(RETH_ADDR).approve(sellAdapterAddr, _initCapital);
    sellAdapter.deposit(RETH_ADDR, _initCapital);
    sellAdapter.requestFlashloan(_sellParams, _initCapital, _loanAmount, _dstAmount, vaults[userProxy], RETH);
    vm.stopPrank();

    _logFinalValues(_initCapital);
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
