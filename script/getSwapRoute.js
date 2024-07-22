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


async function getSwapRoute(_fromToken, _fromDecimals, _toToken, _toDecimals, _sellAmount, _caller) {
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

	// console.log(`\n${_num}\nSRC: ${priceRoute.srcUSD}\nDST: ${priceRoute.destUSD}\nDIF: ${(priceRoute.srcUSD - priceRoute.destUSD).toFixed(2)}`);
	// console.log(`\nSRC: ${priceRoute.srcAmount}\nDST: ${priceRoute.destAmount}\n\n`);
	// console.log(JSON.stringify(priceRoute, null, 3));
	// console.log(`\n TRANSACTION \n`);

	process.stdout.write(priceRoute.destAmount);
}

getSwapRoute(FROM_TOKEN, FROM_DECIMALS, TO_TOKEN, TO_DECIMALS, SELL_AMOUNT, CALLER);

// // init 2 ether
// getSwapRoute(FROM_TOKEN, FROM_DECIMALS, TO_TOKEN, TO_DECIMALS, "18154557608573679626873", CALLER, "1");
// // init 4 ether
// getSwapRoute(FROM_TOKEN, FROM_DECIMALS, TO_TOKEN, TO_DECIMALS, "36309115217147359253746", CALLER, "2");
// // init 5 ether
// getSwapRoute(FROM_TOKEN, FROM_DECIMALS, TO_TOKEN, TO_DECIMALS, "45386394021434199067186", CALLER, "3");
// // init 6 ether
// getSwapRoute(FROM_TOKEN, FROM_DECIMALS, TO_TOKEN, TO_DECIMALS, "54463672825721038880622", CALLER, "4");
// // init 8 ether
// getSwapRoute(FROM_TOKEN, FROM_DECIMALS, TO_TOKEN, TO_DECIMALS, "72618230434294718507496", CALLER, "5");