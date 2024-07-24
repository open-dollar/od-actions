// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Registry.s.sol';
import {Strings} from '@openzeppelin/utils/Strings.sol';
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
  using Strings for uint256;

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

  IDenominatedOracle public wstethOracle;
  uint256 public wstethUsdPrice;

  IDenominatedOracle public arbOracle;
  uint256 public arbUsdPrice;

  function setUp() public virtual override {
    super.setUp();
    rethOracle = IDenominatedOracle(MAINNET_DENOMINATED_RETH_USD_ORACLE);
    (rethUsdPrice,) = rethOracle.getResultWithValidity();
    _setCTypePrice(RETH, rethUsdPrice);

    wstethOracle = IDenominatedOracle(MAINNET_DENOMINATED_WSTETH_USD_ORACLE);
    (wstethUsdPrice,) = wstethOracle.getResultWithValidity();
    _setCTypePrice(WSTETH, wstethUsdPrice);

    arbOracle = IDenominatedOracle(MAINNET_CHAINLINK_ARB_USD_RELAYER);
    (arbUsdPrice,) = arbOracle.getResultWithValidity();
    _setCTypePrice(ARB, arbUsdPrice);

    userProxy = _deployOrFind(USER);
    label(USER, 'USER-WALLET');
    label(userProxy, 'USER-PROXY');

    InitSellAdapter memory _init = InitSellAdapter(
      AugustusRegistry.ARBITRUM,
      PARASWAP_AUGUSTUS_SWAPPER,
      AAVE_POOL_ADDRESS_PROVIDER,
      address(vault721),
      address(oracleRelayer),
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
    IERC20Metadata(ARB_ADDR).approve(sellAdapterProxy, type(uint256).max);
    IERC20Metadata(RETH_ADDR).approve(sellAdapterProxy, type(uint256).max);
    IERC20Metadata(WSTETH_ADDR).approve(sellAdapterProxy, type(uint256).max);
    IERC20Metadata(OD_ADDR).approve(sellAdapterProxy, type(uint256).max);
    vm.stopPrank();
  }

  function _requestFlashLoanAndAssertValues(uint256 _initCapital, bytes32 _cType) internal {
    assertEq(collateral[_cType].balanceOf(sellAdapterAddr), 0);
    assertEq(systemCoin.balanceOf(sellAdapterAddr), 0);

    _requestFlashLoan(_initCapital, _cType);

    assertEq(collateral[_cType].balanceOf(sellAdapterAddr), 0);
    assertEq(systemCoin.balanceOf(sellAdapterAddr), 0);
  }

  /**
   * @dev maxLev = 1/(1-LTV)
   * example:
   * LTV = 66.7% = 0.667
   * maxLev = 1/(1 - 0.667) = 3
   */
  function _requestFlashLoan(uint256 _initCapital, bytes32 _cType) internal {
    _setupUserSafe(_cType);
    address _cTypeAddr = address(collateral[_cType]);
    deal(_cTypeAddr, USER, _initCapital);

    (uint256 _loanAmount, uint256 _leveragedDebt) = sellAdapter.getLeveragedDebt(_cType, _initCapital);

    /// @notice ParaSwap SDK call: get dstAmount from route
    uint256 _swapResult = _getDstAmountUserInput(OD_ADDR, _cTypeAddr, _leveragedDebt);

    uint256 _accumulator;
    while ((_loanAmount + PREMIUM) > _swapResult) {
      _accumulator += 3;
      (_loanAmount, _leveragedDebt) = sellAdapter.getLeveragedDebt(_cType, _initCapital, _accumulator);

      /// @notice ParaSwap SDK call: get dstAmount from route
      _swapResult = _getDstAmountUserInput(OD_ADDR, _cTypeAddr, _leveragedDebt);
    }
    emit log_named_uint('LOOP          ROUNDS', _accumulator / 3);

    /// @notice ParaSwap SDK call: get transaction
    (uint256 _dstAmount, IParaswapSellAdapter.SellParams memory _sellParams) =
      _getFullUserInputWithAmount(OD_ADDR, _cTypeAddr, _leveragedDebt);

    /// @notice USER approves sellAdapterProxy as handler of their safe
    vm.prank(userProxy);
    safeManager.allowSAFE(vaults[userProxy], sellAdapterProxy, true);

    /// @notice USER deposits initialCollateral in sellAdapterProxy and executes flashloan leverage
    vm.startPrank(USER);
    IERC20Metadata(_cTypeAddr).approve(sellAdapterAddr, _initCapital);
    sellAdapter.requestFlashloan(_sellParams, _initCapital, _loanAmount, _dstAmount, vaults[userProxy], _cType);
    vm.stopPrank();

    /// @notice log success values
    _logFinalValues(_initCapital, _cType);
  }

  function _setupUserSafe(bytes32 _cType) internal {
    _openSafe(userProxy, _cType);
    vm.prank(USER);
    collateral[_cType].approve(userProxy, type(uint256).max);
    userNFV = vault721.getNfvState(vaults[userProxy]);
  }

  function _logFinalValues(uint256 _deposit, bytes32 _cType) internal {
    (uint256 _c, uint256 _d) = _getSAFE(_cType, userNFV.safeHandler);
    emit log_named_bytes32('COLLATERAL      TYPE', _cType);
    if (_cType == RETH) {
      emit log_named_string('RETH   ORACLE  PRICE', _floatingPointWad(_readCTypePrice(RETH)));
    } else if (_cType == WSTETH) {
      emit log_named_string('WSTETH ORACLE  PRICE', _floatingPointWad(_readCTypePrice(WSTETH)));
    } else if (_cType == ARB) {
      emit log_named_string('ARB    ORACLE  PRICE', _floatingPointWad(_readCTypePrice(ARB)));
    }
    emit log_named_string('SAFETYRATION PERCENT', string.concat(sellAdapter.getSafetyRatio(_cType).toString(), '%'));
    emit log_named_string('--------------------', '');
    emit log_named_string('ORIGINAL        DEBT', '0');
    emit log_named_string('FINAL           DEBT', _floatingPointWad(_d));
    emit log_named_string('--------------------', '');
    emit log_named_string('ORIGINAL  COLLATERAL', _floatingPointWad(_deposit));
    emit log_named_string('FINAL     COLLATERAL', _floatingPointWad(_c));
    emit log_named_string('REMAINING COLLATERAL', _floatingPointWad(collateral[_cType].balanceOf(sellAdapterAddr)));
    emit log_named_string('--------------------', '');
    uint256 divRes = _c * 100 / _deposit;
    emit log_named_string('MULTIPLIER      RATE', _floatingPointWad((divRes) * 1e16, 1e16));
    emit log_named_string('LEVERAGE  PERCENTAGE', string.concat((divRes - 100).toString(), '%'));
  }
}

contract E2ESwapExitARB is E2ESwapExit {
  function testRequestFlashloan0() public {
    _requestFlashLoanAndAssertValues(0.00001 ether, ARB);
  }

  function testRequestFlashloan1() public {
    _requestFlashLoanAndAssertValues(0.1 ether, ARB);
  }

  function testRequestFlashloan2() public {
    _requestFlashLoanAndAssertValues(2 ether, ARB);
  }

  function testRequestFlashloan3() public {
    _requestFlashLoanAndAssertValues(4 ether, ARB);
  }

  function testRequestFlashloan4() public {
    _requestFlashLoanAndAssertValues(8 ether, ARB);
  }

  function testRequestFlashloan5() public {
    _requestFlashLoanAndAssertValues(16 ether, ARB);
  }
}

contract E2ESwapExitRETH is E2ESwapExit {
  function testRequestFlashloan0() public {
    _requestFlashLoanAndAssertValues(0.00001 ether, RETH);
  }

  function testRequestFlashloan1() public {
    _requestFlashLoanAndAssertValues(0.1 ether, RETH);
  }

  function testRequestFlashloan2() public {
    _requestFlashLoanAndAssertValues(2 ether, RETH);
  }

  function testRequestFlashloan3() public {
    _requestFlashLoanAndAssertValues(4 ether, RETH);
  }

  function testRequestFlashloan4() public {
    _requestFlashLoanAndAssertValues(8 ether, RETH);
  }

  function testRequestFlashloan5() public {
    _requestFlashLoanAndAssertValues(16 ether, RETH);
  }
}

contract E2ESwapExitWSTETH is E2ESwapExit {
  function testRequestFlashloan0() public {
    _requestFlashLoanAndAssertValues(0.00001 ether, WSTETH);
  }

  function testRequestFlashloan1() public {
    _requestFlashLoanAndAssertValues(0.1 ether, WSTETH);
  }

  function testRequestFlashloan2() public {
    _requestFlashLoanAndAssertValues(2 ether, WSTETH);
  }

  function testRequestFlashloan3() public {
    _requestFlashLoanAndAssertValues(4 ether, WSTETH);
  }

  function testRequestFlashloan4() public {
    _requestFlashLoanAndAssertValues(8 ether, WSTETH);
  }

  function testRequestFlashloan5() public {
    _requestFlashLoanAndAssertValues(16 ether, WSTETH);
  }
}
