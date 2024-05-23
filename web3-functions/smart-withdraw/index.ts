import {
    Web3Function,
    Web3FunctionContext,
} from "@gelatonetwork/web3-functions-sdk";
import { ethers, BigNumber, Contract } from "ethers";
import ky from "ky"; // we recommend using ky as axios doesn't support fetch by default
import { GithubRawData, SignedRiskData, SmartWithdrawMarketParameters, SmartWithdrawParameters, smartWithdrawABI } from "./interfaces";
import { Interface } from "ethers/lib/utils";

Web3Function.onRun(async (context: Web3FunctionContext) => {
    const { userArgs, multiChainProvider } = context;
    const parametersUrl = userArgs.parametersUrl.toString();
    if (!parametersUrl) {
        throw new Error(`Cannot get parameters url from userArgs: ${userArgs.parametersUrl}`);
    }

    // console.log("parametersUrl:", userArgs.parametersUrl);

    const provider = multiChainProvider.default();

    // console.log(`Reading parameters from ${parametersUrl}`);
    const parameters: SmartWithdrawParameters = await ky.get(parametersUrl).json();
    validateParameters(parameters);

    console.log(`PARAMETERS: Max gas price: ${BigNumber.from(parameters.maxGasPriceWei)
        .div(BigNumber.from(10 ** 9))
        .toString()} GWei | Enabled: ${parameters.enabled}. Markets: ${parameters.markets.length}`)

    if (!parameters.enabled) {
        return {
            canExec: false,
            message: `Bot not enabled`,
        };
    }
    
    if (
        context.gelatoArgs.gasPrice.gt(BigNumber.from(parameters.maxGasPriceWei))
    ) {
        return {
            canExec: false,
            message: `Gas price too high: ${context.gelatoArgs.gasPrice.toString()} > ${parameters.maxGasPriceWei
                }`,
        };
    }

    const callData: { to: string, data: string }[] = [];
    let canExec = false;

    const contract = new ethers.Contract(parameters.smartWithdrawContract, smartWithdrawABI, provider);
    const smartWithdrawInterface = new Interface(smartWithdrawABI);
    for (const market of parameters.markets) {
        // get risk data from github
        // ex url: https://raw.githubusercontent.com/LaTribuWeb3/risk-data-repo/main/mainnet/latest/wstETH_WETH_in_quote 
        // >> using in_quote version to have the wstETH liquidity in WETH
        const riskDataForMarket = `${parameters.riskDataBasePath}/${market.base}_${market.quote}_in_quote`;
        const ghData: GithubRawData[] = await ky.get(riskDataForMarket).json();
        const selectedData = ghData.find(_ => _.liquidationBonus == market.liquidationBonus);
        if (!selectedData) {
            console.warn(`Cannot find risk data for ${market.base}/${market.quote} and liquidation bonus ${market.liquidationBonus}`);
            continue;
        }

        const signedRiskData: SignedRiskData = {
            riskData: selectedData.riskData,
            v: selectedData.v,
            r: selectedData.r,
            s: selectedData.s,
        }
        // console.log(`${market.index} ${market.base} ${market.quote}:`, signedRiskData);

        const keeperCheckResponse = await contract.keeperCheck(parameters.vaultAddress, market.index, signedRiskData);

        console.log(`[MARKET ${market.index}] | [${market.base}/${market.quote}] withdraw needed: ${keeperCheckResponse[0]}. Recommended ltv ${keeperCheckResponse[1] / 1e16}%`);
        if (keeperCheckResponse[0]) {
            canExec = true;
            callData.push({
                to: parameters.smartWithdrawContract,
                data: smartWithdrawInterface.encodeFunctionData("keeperCall", [parameters.vaultAddress, market.index, signedRiskData]),
            });
        }
    }

    if (canExec) {
        return {
            canExec: true,
            callData: callData,
            message: `Execution ready`
        };
    } else {
        return {
            canExec: false, // Explicitly type as false
            message: `Nothing to execute`
        };
    }
});

function validateParameters(parameters: SmartWithdrawParameters) {
    if (!parameters.maxGasPriceWei || Number.isNaN(parameters.maxGasPriceWei)) {
        throw new Error(`Cannot read param maxGasPriceWei: ${parameters.maxGasPriceWei}`);
    }

    if (parameters.enabled == undefined) {
        parameters.enabled = false;
    }

    if (!parameters.smartWithdrawContract || parameters.smartWithdrawContract == ethers.constants.AddressZero) {
        throw new Error(`smartWithdrawContract param must not be address zero or empty`);
    }

    if (!parameters.vaultAddress || parameters.vaultAddress == ethers.constants.AddressZero) {
        throw new Error(`vaultAddress param must not be address zero or empty`);
    }

    if (!parameters.riskDataBasePath) {
        throw new Error(`riskDataBasePath param must not be empty`);
    }
}
