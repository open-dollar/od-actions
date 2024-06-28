require('dotenv').config();
const {constructSimpleSDK, SwapSide} = require('@paraswap/sdk');
const axios = require('axios');
const { ethers } = require("ethers");

const paraSwapMin = constructSimpleSDK({chainId: 42161, axios});

const pk = process.env.PRIV_KEY;
const provider = new ethers.providers.AlchemyProvider("arbitrum", process.env.ALCHEMY_URL);

const args = process.argv.slice(2);

const FROM_TOKEN = args[0];
const FROM_DECIMALS = args[1];
const TO_TOKEN = args[2];
const TO_DECIMALS = args[3];
const SELL_AMOUNT = args[4];

async function findSwapRoute(_fromToken, _fromDecimals, _toToken, _toDecimals, _sellAmount) {
	const signer = new ethers.Wallet(pk, provider);
	const senderAddress = signer.address;

	const priceRoute = await paraSwapMin.swap.getRate({
		srcToken: _fromToken,
		srcDecimals: _fromDecimals,
		destToken: _toToken,
		destDecimals: _toDecimals,
		amount: _sellAmount,
		userAddress: senderAddress,
		side: SwapSide.SELL,
	});

	const txParams = await paraSwapMin.swap.buildTx(
		{
			srcToken: priceRoute.srcToken,
			destToken: priceRoute.destToken,
			srcAmount: priceRoute.srcAmount,
			destAmount: priceRoute.destAmount,
			priceRoute,
			userAddress: senderAddress
		}     
	);

	process.stdout.write(txParams.data);
}

findSwapRoute(FROM_TOKEN, FROM_DECIMALS, TO_TOKEN, TO_DECIMALS, SELL_AMOUNT);