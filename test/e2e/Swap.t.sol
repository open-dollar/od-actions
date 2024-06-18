// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {MintableERC20} from '@opendollar/contracts/for-test/MintableERC20.sol';
import {TKN} from '@opendollar/test/e2e/Common.t.sol';
import {CommonTest} from 'test/CommonTest.t.sol';
import {IAugustusRFQ} from 'src/leverage/interfaces/IAugustusRFQ.sol';

contract E2ELeverageCalculator is CommonTest {
  IAugustusRFQ public constant augustusRfq = IAugustusRFQ(0x0927FD43a7a87E3E8b81Df2c44B03C4756849F6D);

  function setUp() public virtual override {
    super.setUp();
  }

  function testAugustRFGsetup() public {
    assertEq(augustusRfq.FILLED_ORDER(), 1);
    assertEq(augustusRfq.UNFILLED_ORDER(), 0);
    assertEq(
      augustusRfq.RFQ_LIMIT_NFT_ORDER_TYPEHASH(), 0xba5673374f195ea076b91318b714c4f3d0887a650164f117b9a64de6237587fb
    );
    assertEq(augustusRfq.RFQ_LIMIT_ORDER_TYPEHASH(), 0x95afddf5e4bb9f692716b7fdff640e6b8a0d2869597405c6e9d35857ed19a150);
  }

  function testNativeSwap() public {}
}
