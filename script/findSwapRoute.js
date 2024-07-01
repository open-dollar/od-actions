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

// const FROM_TOKEN = "0xEC70Dcb4A1EFa46b8F2D97C310C9c4790ba5ffA8";
// const FROM_DECIMALS = "18";
// const TO_TOKEN = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";
// const TO_DECIMALS = "18";
// const SELL_AMOUNT = "1000000000000000000";
// const CALLER = "0x37c5B029f9c3691B3d47cb024f84E5E257aEb0BB";

async function findSwapRoute(_fromToken, _fromDecimals, _toToken, _toDecimals, _sellAmount, _caller) {
	const priceRoute = await paraSwapMin.swap.getRate({
		srcToken: _fromToken,
		srcDecimals: _fromDecimals,
		destToken: _toToken,
		destDecimals: _toDecimals,
		amount: _sellAmount,
		userAddress: _caller,
		side: SwapSide.SELL,
	});

	const txParams = await paraSwapMin.swap.buildTx(
		{
			srcToken: priceRoute.srcToken,
			destToken: priceRoute.destToken,
			srcAmount: priceRoute.srcAmount,
			destAmount: priceRoute.destAmount,
			priceRoute,
			userAddress: _caller,
			ignoreChecks: true
		}     
	);

	process.stdout.write(txParams.data);
}

findSwapRoute(FROM_TOKEN, FROM_DECIMALS, TO_TOKEN, TO_DECIMALS, SELL_AMOUNT, CALLER);