// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.5;
pragma abicoder v2;

import {PARASWAP_AUGUSTUS_SWAPPER} from '@script/ParaswapRegistry.s.sol';
import {IParaswap} from 'src/leverage/interfaces/augustusV5/IParaswap.sol';

contract LeverageSwapper {
  IParaswap public constant paraswap = IParaswap(PARASWAP_AUGUSTUS_SWAPPER);
}
