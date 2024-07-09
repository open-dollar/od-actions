// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import 'forge-std/Test.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {FlashLoanSimpleReceiverBase} from '@aave-core-v3/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol';
import {IPoolAddressesProvider} from '@aave-core-v3/contracts/interfaces/IPoolAddressesProvider.sol';
// import {PercentageMath} from '@aave-core-v3/contracts/protocol/libraries/math/PercentageMath.sol';
import {IParaSwapAugustusRegistry} from '@aave-debt-swap/dependencies/paraswap/IParaSwapAugustusRegistry.sol';
import {ODProxy} from '@opendollar/contracts/proxies/ODProxy.sol';
import {IODSafeManager} from '@opendollar/interfaces/proxies/IODSafeManager.sol';
import {ICollateralJoinFactory} from '@opendollar/interfaces/factories/ICollateralJoinFactory.sol';
import {IVault721} from '@opendollar/interfaces/proxies/IVault721.sol';
import {ISAFEEngine} from '@opendollar/interfaces/ISAFEEngine.sol';
import {IParaswapSellAdapter} from 'src/leverage/interfaces/IParaswapSellAdapter.sol';
import {IParaswapAugustus} from 'src/leverage/interfaces/IParaswapAugustus.sol';
import {ExitActions} from 'src/leverage/ExitActions.sol';

/**
 * TODO:
 * - add access control
 * - add modifiable contract for var updates
 * - add withdraw function
 * - enforce max slippage rate
 */
contract ParaswapSellAdapter is FlashLoanSimpleReceiverBase, IParaswapSellAdapter, Test {
  // using PercentageMath for uint256;
  // uint256 public constant MAX_SLIPPAGE_PERCENT = 0.3e4; // 30.00%
  uint256 public constant PREMIUM = 500_000_000_000;

  IParaSwapAugustusRegistry public immutable AUGUSTUS_REGISTRY;
  ODProxy public immutable PS_ADAPTER_ODPROXY;
  IERC20Metadata public immutable OPEN_DOLLAR;

  IParaswapAugustus public augustus;

  IODSafeManager public safeManager;
  ICollateralJoinFactory public collateralJoinFactory;
  // todo make interface for this
  ExitActions public exitActions;
  address public coinJoin;

  mapping(address => mapping(address => uint256)) internal _deposits;

  /**
   * @param _augustusRegistry address of Paraswap AugustusRegistry
   * @param _augustusSwapper address of Paraswap AugustusSwapper
   * @param _poolProvider address of Aave PoolAddressProvider
   * @param _vault721 address of OpenDollar Vault721
   * @param _exitActions address of OpenDollar ExitActions
   * @param _collateralJoinFactory address of OpenDollar CollateralJoinFactory
   * @param _coinJoin address of OpenDollar CoinJoin
   */
  constructor(
    address _systemCoin,
    address _augustusRegistry,
    address _augustusSwapper,
    address _poolProvider,
    address _vault721,
    address _exitActions,
    address _collateralJoinFactory,
    address _coinJoin
  ) FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_poolProvider)) {
    OPEN_DOLLAR = IERC20Metadata(_systemCoin);
    AUGUSTUS_REGISTRY = IParaSwapAugustusRegistry(_augustusRegistry);
    augustus = IParaswapAugustus(_augustusSwapper);
    IVault721 _v721 = IVault721(_vault721);
    safeManager = IODSafeManager(_v721.safeManager());
    exitActions = ExitActions(_exitActions);
    collateralJoinFactory = ICollateralJoinFactory(_collateralJoinFactory);
    coinJoin = _coinJoin;
    PS_ADAPTER_ODPROXY = ODProxy(_v721.build(address(this)));
  }

  /// @dev deposit asset for msg.sender
  function deposit(address _asset, uint256 _amount) external {
    _deposit(msg.sender, _asset, _amount);
  }

  /// @dev deposit asset for account
  function deposit(address _onBehalfOf, address _asset, uint256 _amount) external {
    _deposit(_onBehalfOf, _asset, _amount);
  }

  /// @dev exact-in sell swap on ParaSwap
  function sellOnParaSwap(
    SellParams memory _sellParams,
    uint256 _minDstAmount
  ) external returns (uint256 _amountReceived) {
    _amountReceived = _sellOnParaSwap(
      _sellParams.offset,
      _sellParams.swapCalldata,
      IERC20Metadata(_sellParams.fromToken),
      IERC20Metadata(_sellParams.toToken),
      _sellParams.sellAmount,
      _minDstAmount
    );
  }

  /// @dev approve address(this) as safeHandler and request to borrow asset on Aave
  function requestFlashloan(
    SellParams memory _sellParams,
    uint256 _collateralLoan,
    uint256 _minDstAmount,
    uint256 _safeId,
    bytes32 _cType
  ) external {
    // deposit collateral, generate debt
    bytes memory _payload = abi.encodeWithSelector(
      exitActions.lockTokenCollateralAndGenerateDebtToAccount.selector,
      address(this),
      address(safeManager),
      address(collateralJoinFactory.collateralJoins(_cType)),
      coinJoin,
      _safeId,
      _collateralLoan - PREMIUM,
      _sellParams.sellAmount
    );

    // borrow collateral
    POOL.flashLoanSimple({
      receiverAddress: address(this),
      asset: address(_sellParams.toToken),
      amount: _collateralLoan,
      params: abi.encode(_minDstAmount, _sellParams, _payload),
      referralCode: uint16(block.number)
    });
  }

  /// @dev flashloan callback from Aave
  function executeOperation(
    address asset,
    uint256 amount,
    uint256 premium,
    address initiator,
    bytes calldata params
  ) external override returns (bool) {
    (uint256 _minDstAmount, SellParams memory _sellParams, bytes memory _payload) =
      abi.decode(params, (uint256, SellParams, bytes));

    emit log_named_uint('RETH BAL AQUIRE LOAN', IERC20Metadata(_sellParams.toToken).balanceOf(address(this)));

    uint256 _beforebalance = IERC20Metadata(_sellParams.fromToken).balanceOf(address(this));
    uint256 _sellAmount = _sellParams.sellAmount;

    _executeFromProxy(_payload);

    // todo add error msg
    // if (_sellAmount != OD.balanceOf(address(this)) - _beforebalance) revert();

    // swap debt to collateral
    _sellOnParaSwap(
      _sellParams.offset,
      _sellParams.swapCalldata,
      IERC20Metadata(_sellParams.fromToken),
      IERC20Metadata(_sellParams.toToken),
      _sellAmount,
      _minDstAmount
    );
    emit log_named_uint('RETH BAL POST   SWAP', IERC20Metadata(_sellParams.toToken).balanceOf(address(this)));

    uint256 _payBack = amount + premium;
    IERC20Metadata(asset).approve(address(POOL), _payBack);

    return true;
  }

  function _executeFromProxy(bytes memory _payload) internal {
    PS_ADAPTER_ODPROXY.execute(address(exitActions), _payload);
  }

  /// @dev transfer asset to this contract to use in flashloan-swap
  function _deposit(address _account, address _asset, uint256 _amount) internal {
    IERC20Metadata(_asset).transferFrom(_account, address(this), _amount);
    _deposits[_account][_asset] = _amount;
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
    if (_sellAmount > _amountSold) revert OverSell();

    _amountReceived = _toToken.balanceOf(address(this)) - _initBalToToken;
    if (_amountReceived < _minDstAmount) revert UnderBuy();
    emit Swapped(address(_fromToken), address(_toToken), _amountSold, _amountReceived);
  }
}
