// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import 'forge-std/Test.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {IParaswapSellAdapter} from 'src/leverage/ParaswapSellAdapter.sol';

contract Utils is Test {
  event FlashLoan(
    address indexed target,
    address initiator,
    address indexed asset,
    uint256 amount,
    uint256 interestRateMode,
    uint256 premium,
    uint16 indexed referralCode
  );

  function _supply(address _adapter, address _asset, uint256 _amount) internal {
    deal(_asset, msg.sender, _amount);
    IERC20Metadata(_asset).approve(address(_adapter), _amount);
    IParaswapSellAdapter(_adapter).deposit(_asset, _amount);
  }
}

// function _borrow(address _adapter, address _asset, uint256 _amount) internal {
//   _adapter.borrow(_asset, _amount, 2, 0, USER);
// }

// function _withdraw(address _adapter, address _asset, uint256 _amount) internal {
//   _adapter.withdraw(_asset, _amount, USER);
// }
