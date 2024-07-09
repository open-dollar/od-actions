// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

interface IParaswapAugustus {
  function getTokenTransferProxy() external view returns (address _tokenTransferProxy);
}
