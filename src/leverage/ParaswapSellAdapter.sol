// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {FlashLoanSimpleReceiverBase} from '@aave-core-v3/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol';
import {IPoolAddressesProvider} from '@aave-core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
import {PercentageMath} from '@aave-core-v3/contracts/protocol/libraries/math/PercentageMath.sol';
import {IParaSwapAugustusRegistry} from '@aave-debt-swap/dependencies/paraswap/IParaSwapAugustusRegistry.sol';
import {ODProxy} from '@opendollar/contracts/proxies/ODProxy.sol';
import {Modifiable} from '@opendollar/contracts/utils/Modifiable.sol';
import {Authorizable} from '@opendollar/contracts/utils/Authorizable.sol';
import {
  ISAFEEngine,
  IODSafeManager,
  ICollateralJoinFactory,
  ICollateralJoin,
  IOracleRelayer,
  IVault721
} from '@opendollar/libraries/OpenDollarV1Arbitrum.sol';
import {Assertions} from '@opendollar/libraries/Assertions.sol';
import {Encoding} from '@opendollar/libraries/Encoding.sol';
import {Math} from '@opendollar/libraries/Math.sol';
import {IParaswapSellAdapter, InitSellAdapter} from 'src/leverage/interfaces/IParaswapSellAdapter.sol';
import {IParaswapAugustus} from 'src/leverage/interfaces/IParaswapAugustus.sol';
import {IExitActions} from 'src/leverage/interfaces/IExitActions.sol';

contract ParaswapSellAdapter is FlashLoanSimpleReceiverBase, IParaswapSellAdapter, Modifiable {
  using PercentageMath for uint256;
  using Math for uint256;
  using Assertions for address;
  using Encoding for bytes;

  uint256 public constant MAX_SLIPPAGE_PERCENT = 0.03e4; // 3%

  IParaSwapAugustusRegistry public immutable AUGUSTUS_REGISTRY;
  ODProxy public immutable PS_ADAPTER_ODPROXY;

  IParaswapAugustus public augustus;

  IODSafeManager public safeManager;
  IOracleRelayer public oracleRelayer;
  ICollateralJoinFactory public collateralJoinFactory;
  IExitActions public exitActions;
  address public coinJoin;

  constructor(InitSellAdapter memory _initSellAdapter)
    FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_initSellAdapter.poolProvider))
    Authorizable(msg.sender)
  {
    AUGUSTUS_REGISTRY = IParaSwapAugustusRegistry(_initSellAdapter.augustusRegistry);
    augustus = IParaswapAugustus(_initSellAdapter.augustusSwapper);
    IVault721 _v721 = IVault721(_initSellAdapter.vault721);
    safeManager = IODSafeManager(_v721.safeManager());
    oracleRelayer = IOracleRelayer(_initSellAdapter.oracleRelayer);
    exitActions = IExitActions(_initSellAdapter.exitActions);
    collateralJoinFactory = ICollateralJoinFactory(_initSellAdapter.collateralJoinFactory);
    coinJoin = _initSellAdapter.coinJoin;
    PS_ADAPTER_ODPROXY = ODProxy(_v721.build(address(this)));
  }

  /// @dev get accumulated rate and safety price for a cType
  function getCData(bytes32 _cType) external view returns (uint256 _accumulatedRate, uint256 _safetyPrice) {
    (_accumulatedRate, _safetyPrice) = _getCData(_cType);
  }

  /// @dev get max collateral loan and max leveraged debt
  function getLeveragedDebt(
    bytes32 _cType,
    uint256 _initCapital
  ) external view returns (uint256 _cTypeLoanAmount, uint256 _leveragedDebt) {
    (_cTypeLoanAmount, _leveragedDebt) = _getLeveragedDebt(_cType, _initCapital, 0);
  }

  /// @dev get collateral loan and leveraged debt with percentage buffer
  function getLeveragedDebt(
    bytes32 _cType,
    uint256 _initCapital,
    uint256 _percentageBuffer
  ) external view returns (uint256 _cTypeLoanAmount, uint256 _leveragedDebt) {
    (_cTypeLoanAmount, _leveragedDebt) = _getLeveragedDebt(_cType, _initCapital, _percentageBuffer);
  }

  /// @dev approve address(this) as safeHandler and request to borrow asset on Aave
  function requestFlashloan(
    SellParams memory _sellParams,
    uint256 _initCollateral,
    uint256 _collateralLoan,
    uint256 _minDstAmount,
    uint256 _safeId,
    bytes32 _cType
  ) external {
    address _collateralJoin = collateralJoinFactory.collateralJoins(_cType);

    // transfer initial collateral deposit
    ICollateralJoin(_collateralJoin).collateral().transferFrom(msg.sender, address(this), _initCollateral);

    // deposit collateral, generate debt
    bytes memory _payload = abi.encodeWithSelector(
      exitActions.lockTokenCollateralAndGenerateDebtToAccount.selector,
      address(this),
      address(safeManager),
      _collateralJoin,
      coinJoin,
      _safeId,
      _initCollateral + _collateralLoan,
      _sellParams.sellAmount
    );

    // borrow collateral
    POOL.flashLoanSimple({
      receiverAddress: address(this),
      asset: address(_sellParams.toToken),
      amount: _collateralLoan,
      params: abi.encode(_minDstAmount, _safeId, _collateralJoin, _sellParams, _payload),
      referralCode: uint16(block.number)
    });
  }

  /// @dev flashloan callback from Aave
  function executeOperation(
    address asset,
    uint256 amount,
    uint256 premium,
    address, /* initiator */
    bytes calldata params
  ) external override returns (bool) {
    (
      uint256 _minDstAmount,
      uint256 _safeId,
      address _collateralJoin,
      SellParams memory _sellParams,
      bytes memory _payload
    ) = abi.decode(params, (uint256, uint256, address, SellParams, bytes));

    if (asset != _sellParams.toToken) revert WrongAsset();
    IERC20Metadata _toToken = IERC20Metadata(_sellParams.toToken);
    IERC20Metadata _fromToken = IERC20Metadata(_sellParams.fromToken);

    {
      uint256 _beforebalance = _fromToken.balanceOf(address(this));
      uint256 _sellAmount = _sellParams.sellAmount;

      _executeFromProxy(_payload);

      if (_sellAmount != _fromToken.balanceOf(address(this)) - _beforebalance) revert IncorrectAmount();
      // swap debt to collateral
      _sellOnParaSwap(_sellParams.offset, _sellParams.swapCalldata, _fromToken, _toToken, _sellAmount, _minDstAmount);
    }

    uint256 _payBack = amount + premium;
    uint256 _remainder = _toToken.balanceOf(address(this)) - _payBack;
    if (_remainder > 0) {
      bytes memory _returnPayload = abi.encodeWithSelector(
        exitActions.lockTokenCollateral.selector, address(safeManager), _collateralJoin, _safeId, _remainder
      );
      _executeFromProxy(_returnPayload);
    }

    IERC20Metadata(asset).approve(address(POOL), _payBack);
    return true;
  }

  /// @dev get safetyRatio as fixed-point percent
  function getSafetyRatio(bytes32 _cType) public view returns (uint256 _safetyCRatio) {
    IOracleRelayer.OracleRelayerCollateralParams memory _cParams = oracleRelayer.cParams(_cType);
    _safetyCRatio = _cParams.safetyCRatio / 1e25;
  }

  /// @dev get accumulated rate and safety price for a cType from the SAFEEngine
  function _getCData(bytes32 _cType) internal view returns (uint256 _accumulatedRate, uint256 _safetyPrice) {
    ISAFEEngine.SAFEEngineCollateralData memory _safeEngCData = ISAFEEngine(safeManager.safeEngine()).cData(_cType);
    _accumulatedRate = _safeEngCData.accumulatedRate;
    _safetyPrice = _safeEngCData.safetyPrice;
  }

  /// @dev calculate collateral loan amount and leveraged debt
  function _getLeveragedDebt(
    bytes32 _cType,
    uint256 _initCapital,
    uint256 _percentageBuffer
  ) internal view returns (uint256 _cTypeLoanAmount, uint256 _leveragedDebt) {
    (uint256 _accumulatedRate, uint256 _safetyPrice) = _getCData(_cType);

    uint256 _percent = getSafetyRatio(_cType) + _percentageBuffer;
    uint256 _multiplier = 10_000 / (105 - (10_000 / (_percent)));

    _cTypeLoanAmount = (_initCapital * _multiplier / 100) - _initCapital;
    _leveragedDebt = _initCapital.wmul(_safetyPrice).wdiv(_accumulatedRate) * _multiplier / 100;
  }

  /// @dev execute payload with delegate call via proxy for address(this)
  function _executeFromProxy(bytes memory _payload) internal {
    PS_ADAPTER_ODPROXY.execute(address(exitActions), _payload);
  }

  /// @dev takes ParaSwap transaction data and executes sell swap
  function _sellOnParaSwap(
    uint256 _offset,
    bytes memory _swapCalldata,
    IERC20Metadata _fromToken,
    IERC20Metadata _toToken,
    uint256 _sellAmount,
    uint256 _minDstAmount
  ) internal returns (uint256 _amountReceived) {
    if (!AUGUSTUS_REGISTRY.isValidAugustus(address(augustus))) revert InvalidAugustus();
    if (_minDstAmount == 0) revert ZeroValue();

    uint256 _initBalFromToken = _fromToken.balanceOf(address(this));
    if (_initBalFromToken < _sellAmount) revert InsufficientBalance();
    uint256 _initBalToToken = _toToken.balanceOf(address(this));

    address _tokenTransferProxy = augustus.getTokenTransferProxy();
    _fromToken.approve(_tokenTransferProxy, _sellAmount);

    if (_offset != 0) {
      // ensure 1 slot _offset is within bounds of calldata, not overlapping with function selector
      if (_offset < 4 && _offset > _swapCalldata.length - 32) revert OffsetOutOfRange();
      // overwrite the fromAmount with the correct amount for the swap
      assembly {
        mstore(add(_swapCalldata, add(_offset, 32)), _sellAmount)
      }
    }
    (bool _ok,) = address(augustus).call(_swapCalldata);
    if (!_ok) {
      assembly {
        returndatacopy(0, 0, returndatasize())
        revert(0, returndatasize())
      }
    }
    uint256 _amountSold = _initBalFromToken - _fromToken.balanceOf(address(this));
    if (_sellAmount < _amountSold) revert OverSell();

    _amountReceived = _toToken.balanceOf(address(this)) - _initBalToToken;
    uint256 _amountAccepted = _minDstAmount - _minDstAmount.percentMul(MAX_SLIPPAGE_PERCENT);
    if (_amountReceived < _amountAccepted) revert UnderBuy();
    emit Swapped(address(_fromToken), address(_toToken), _amountSold, _amountReceived);
  }

  /// @notice overridden function from Modifiable to modify parameters
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    address _addr = _data.toAddress();

    if (_param == 'augustus') {
      augustus = IParaswapAugustus(_addr.assertNonNull());
    } else if (_param == 'safeManager') {
      safeManager = IODSafeManager(_addr.assertNonNull());
    } else if (_param == 'oracleRelayer') {
      oracleRelayer = IOracleRelayer(_addr.assertNonNull());
    } else if (_param == 'collateralJoinFactory') {
      collateralJoinFactory = ICollateralJoinFactory(_addr.assertNonNull());
    } else if (_param == 'exitActions') {
      exitActions = IExitActions(_addr.assertNonNull());
    } else if (_param == 'coinJoin') {
      coinJoin = _addr.assertNonNull();
    } else {
      revert UnrecognizedParam();
    }
  }
}
