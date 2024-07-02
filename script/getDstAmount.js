const {constructSimpleSDK, SwapSide} = require('@paraswap/sdk');
const axios = require('axios');
const ethers = require('ethers');

const paraSwapMin = constructSimpleSDK({chainId: 42161, axios});

const args = process.argv.slice(2);

const FROM_TOKEN = args[0];
const FROM_DECIMALS = args[1];
const TO_TOKEN = args[2];
const TO_DECIMALS = args[3];
const SELL_AMOUNT = args[4];
const CALLER = args[5];

async function getDstRoute(_fromToken, _fromDecimals, _toToken, _toDecimals, _sellAmount, _caller) {
	const _priceRoute = await paraSwapMin.swap.getRate({
		srcToken: _fromToken,
		srcDecimals: _fromDecimals,
		destToken: _toToken,
		destDecimals: _toDecimals,
		amount: _sellAmount,
		userAddress: _caller,
		side: SwapSide.SELL,
	});

	const dstAmount = ethers.utils.defaultAbiCoder.encode(["(uint256)"],[[_priceRoute.destAmount]]);

	process.stdout.write(dstAmount);
}

getDstRoute(FROM_TOKEN, FROM_DECIMALS, TO_TOKEN, TO_DECIMALS, SELL_AMOUNT, CALLER);