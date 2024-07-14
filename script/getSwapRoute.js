const {constructSimpleSDK, SwapSide} = require('@paraswap/sdk');
const axios = require('axios');

const paraSwapMin = constructSimpleSDK({chainId: 42161, axios});

const args = process.argv.slice(2);

let FROM_TOKEN;
let FROM_DECIMALS;
let TO_TOKEN;
let TO_DECIMALS;
let SELL_AMOUNT;
let CALLER;

if (args.length) {
	FROM_TOKEN = args[0];
	FROM_DECIMALS = args[1];
	TO_TOKEN = args[2];
	TO_DECIMALS = args[3];
	SELL_AMOUNT = args[4];
	CALLER = args[5];
} else {
	FROM_TOKEN = "0x221A0f68770658C15B525d0F89F5da2baAB5f321";
	FROM_DECIMALS = "18";
	TO_TOKEN = "0xEC70Dcb4A1EFa46b8F2D97C310C9c4790ba5ffA8";
	TO_DECIMALS = "18";
	SELL_AMOUNT = "995173078713564046713";
	CALLER = "0x37c5B029f9c3691B3d47cb024f84E5E257aEb0BB";
}


async function getSwapRoute(_fromToken, _fromDecimals, _toToken, _toDecimals, _sellAmount, _caller, _num) {
	// console.log(`\n ROUTE \n`);

	const priceRoute = await paraSwapMin.swap.getRate({
		srcToken: _fromToken,
		srcDecimals: _fromDecimals,
		destToken: _toToken,
		destDecimals: _toDecimals,
		amount: _sellAmount,
		userAddress: _caller,
		side: SwapSide.SELL,
	});

	console.log(`\n${_num}\nSRC: ${priceRoute.srcUSD}\nDST: ${priceRoute.destUSD}\nDIF: ${priceRoute.srcUSD - priceRoute.destUSD}\n\n`);
	// console.log(JSON.stringify(priceRoute, null, 3));
	// console.log(`\n TRANSACTION \n`);

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

	// console.log(JSON.stringify(txParams, null, 3));

	// process.stdout.write(txParams.data);
}

getSwapRoute(FROM_TOKEN, FROM_DECIMALS, TO_TOKEN, TO_DECIMALS, "995173078713564046713", CALLER, "1");
getSwapRoute(FROM_TOKEN, FROM_DECIMALS, TO_TOKEN, TO_DECIMALS, "4975865393567820237063", CALLER, "2");
getSwapRoute(FROM_TOKEN, FROM_DECIMALS, TO_TOKEN, TO_DECIMALS, "9951730787135640477624", CALLER, "3");
getSwapRoute(FROM_TOKEN, FROM_DECIMALS, TO_TOKEN, TO_DECIMALS, "49758653935678202402106", CALLER, "4");
getSwapRoute(FROM_TOKEN, FROM_DECIMALS, TO_TOKEN, TO_DECIMALS, "99517307871356404804213", CALLER, "5");