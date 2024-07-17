// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ISAFEEngine} from '@opendollar/interfaces/ISAFEEngine.sol';
import {IVault721} from '@opendollar/interfaces/proxies/IVault721.sol';
import {IODSafeManager} from '@opendollar/interfaces/proxies/IODSafeManager.sol';
import {Math, RAY} from '@opendollar/libraries/Math.sol';

contract LeverageCalculator {
  using Math for uint256;

  IVault721 public immutable VAULT721;
  ISAFEEngine public immutable SAFEENGINE;

  constructor(address _vault721) {
    VAULT721 = IVault721(_vault721);
    SAFEENGINE = ISAFEEngine(IODSafeManager(VAULT721.safeManager()).safeEngine());
  }

  function calculateMaxSafetyDebt(uint256 _safeId) public view returns (uint256 _maxSafetyDebt) {
    (bytes32 _cType, address _safeHandler) = getNFVIds(_safeId);
    (uint256 _collateral,) = getNFVLockedAndDebt(_cType, _safeHandler);
    (uint256 _accumulatedRate, uint256 _safetyPrice) = getCData(_cType);

    _maxSafetyDebt = _collateral.wmul(_safetyPrice).wdiv(_accumulatedRate);
  }

  /// @dev calculate max single-swap leverage based on initial locked collateral
  function calculateSingleLeverage(uint256 _safeId) public view returns (uint256 _leverage) {
    (bytes32 _cType, address _safeHandler) = getNFVIds(_safeId);
    (uint256 _collateral, uint256 _debt) = getNFVLockedAndDebt(_cType, _safeHandler);
    (uint256 _accumulatedRate, uint256 _safetyPrice) = getCData(_cType);

    uint256 _maxSafetyDebt = _collateral.wmul(_safetyPrice).wdiv(_accumulatedRate);

    if (_maxSafetyDebt > _debt) {
      _leverage = _maxSafetyDebt - _debt;
    }
  }

  /// @dev calculate max loop-swap leverage based on initial locked collateral
  function calculateMultipleLeverage(uint256 _safeId) external view returns (uint256 _leverage) {
    uint256 _accumulator;
    uint256 _debtIterator;

    _debtIterator = calculateSingleLeverage(_safeId);

    while (_debtIterator > 200 ether) {
      _accumulator += _debtIterator;
      // TODO: recalculate collateral or execute leverage swap
      _debtIterator = calculateSingleLeverage(_safeId);
    }

    return _leverage;
  }

  /// @dev calculate max flashloan leverage based on initial locked collateral
  function calculateFlashLeverage(uint256 _safeId) external pure returns (uint256 _leverage) {
    // TODO: calculate max leverage
    return _safeId;
  }

  /// @return _internalDebt internal account of COIN for an account (internal)
  function getCoinBalance(address _proxy) public view returns (uint256 _internalDebt) {
    _internalDebt = SAFEENGINE.coinBalance(_proxy) / RAY;
  }

  /// @dev get cType and safe handler of NFV
  function getNFVIds(uint256 _safeId) public view returns (bytes32 _cType, address _safeHandler) {
    IVault721.NFVState memory _nftState = VAULT721.getNfvState(_safeId);
    _cType = _nftState.cType;
    _safeHandler = _nftState.safeHandler;
  }

  /// @dev get locked collateral and generated debt
  function getNFVLockedAndDebt(
    bytes32 _cType,
    address _safeHandler
  ) public view returns (uint256 _collateral, uint256 _debt) {
    ISAFEEngine.SAFE memory _safeData = SAFEENGINE.safes(_cType, _safeHandler);
    _collateral = _safeData.lockedCollateral;
    _debt = _safeData.generatedDebt;
  }

  /// @dev get accumulated rate and safety price for a cType
  function getCData(bytes32 _cType) public view returns (uint256 _accumulatedRate, uint256 _safetyPrice) {
    ISAFEEngine.SAFEEngineCollateralData memory _safeEngCData = SAFEENGINE.cData(_cType);
    _accumulatedRate = _safeEngCData.accumulatedRate;
    _safetyPrice = _safeEngCData.safetyPrice;
  }
}
