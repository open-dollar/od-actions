// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

// Open Dollar
address constant OD_ADDR = 0x221A0f68770658C15B525d0F89F5da2baAB5f321;
address constant VAULT721 = 0x0005AFE00fF7E7FF83667bFe4F2996720BAf0B36;

// Open Dollar Pool Pair
bytes32 constant WETH = bytes32('WETH');
address constant WETH_ADDR = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

// Open Dollar Protocol Collateral
bytes32 constant WSTETH = bytes32('WSTETH');
address constant WSTETH_ADDR = 0x5979D7b546E38E414F7E9822514be443A4800529;
bytes32 constant RETH = bytes32('RETH');
address constant RETH_ADDR = 0xEC70Dcb4A1EFa46b8F2D97C310C9c4790ba5ffA8;
bytes32 constant ARB = bytes32('ARB');
address constant ARB_ADDR = 0x912CE59144191C1204E64559FE8253a0e49E6548;

// Aave
address constant AAVE_POOL_ADDRESS_PROVIDER = 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb;

// ParaSwap Limit Order Contract (Sol 0.8.1)
address constant PARASWAP_AUGUSTUS_RFQ = 0x0927FD43a7a87E3E8b81Df2c44B03C4756849F6D;

// ParaSwap On-Chain Aggregator (Sol 0.7.5)
address constant PARASWAP_AUGUSTUS_SWAPPER = 0xDEF171Fe48CF0115B1d80b88dc8eAB59176FEe57;

// Test Vars
address constant USER = 0x37c5B029f9c3691B3d47cb024f84E5E257aEb0BB;
uint256 constant SELL_AMOUNT = 1 ether;

// Token Kekkac256 Hashes for Aave
bytes32 constant RETH_HASH = bytes32(keccak256('RETH'));
bytes32 constant WETH_HASH = bytes32(keccak256('WETH'));
bytes32 constant WSTETH_HASH = bytes32(keccak256('WSTETH'));
bytes32 constant AAVE_RETH_HASH = bytes32(keccak256('AAVE_RETH'));
bytes32 constant AAVE_WETH_HASH = bytes32(keccak256('AAVE_WETH'));
bytes32 constant AAVE_WSTETH_HASH = bytes32(keccak256('AAVE_WSTETH'));

// Oracle Relayers
address constant MAINNET_CHAINLINK_ETH_USD_RELAYER = 0x3e6C1621f674da311E57646007fBfAd857084383;
address constant MAINNET_DENOMINATED_WSTETH_USD_ORACLE = 0xD0cf1FfFF3FB90c87210D76DFBc3AcfFd02D6B12;
address constant MAINNET_DENOMINATED_RETH_USD_ORACLE = 0x2b6b76D9854E9A7189c2F1b496c10043b373e453;
address constant MAINNET_CHAINLINK_ARB_USD_RELAYER = 0x2635f731BB6981E72F92A781578952450759F762;
