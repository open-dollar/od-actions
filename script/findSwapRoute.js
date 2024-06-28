require('dotenv').config();
const {constructSimpleSDK, SwapSide} = require('@paraswap/sdk');
const axios = require('axios');
const { ethers } = require("ethers");

const paraSwapMin = constructSimpleSDK({chainId: 42161, axios});

const reth = "0xEC70Dcb4A1EFa46b8F2D97C310C9c4790ba5ffA8";
const weth = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";
const decimals = "18";
const amount = "1000000000000000";

const pk = process.env.PRIV_KEY;
const provider = new ethers.providers.AlchemyProvider("arbitrum", process.env.ALCHEMY_URL);

async function findSwapRoute() {
	const signer = new ethers.Wallet(pk, provider);
	const senderAddress = signer.address;

	const priceRoute = await paraSwapMin.swap.getRate({
		srcToken: reth,
		srcDecimals: decimals,
		destToken: weth,
		destDecimals: decimals,
		amount: amount,
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

findSwapRoute();