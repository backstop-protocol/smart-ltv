import {
  Web3Function,
  Web3FunctionContext,
} from "@gelatonetwork/web3-functions-sdk";
import { BigNumber, Contract } from "ethers";
import ky from "ky"; // we recommend using ky as axios doesn't support fetch by default

// eslint-disable-next-line prettier/prettier
const TARGET_ALLOCATOR_ABI = [{"inputs":[{"internalType":"bytes32","name":"_idleMarketId","type":"bytes32"},{"internalType":"address","name":"_vault","type":"address"},{"internalType":"uint256","name":"_minDelayBetweenReallocations","type":"uint256"},{"internalType":"uint256","name":"_minReallocationSize","type":"uint256"},{"internalType":"address","name":"_keeperAddress","type":"address"},{"internalType":"bytes32[]","name":"_marketIds","type":"bytes32[]"},{"components":[{"internalType":"uint64","name":"maxUtilization","type":"uint64"},{"internalType":"uint64","name":"targetUtilization","type":"uint64"},{"internalType":"uint64","name":"minUtilization","type":"uint64"},{"internalType":"uint256","name":"minLiquidity","type":"uint256"}],"internalType":"struct TargetAllocator.TargetAllocation[]","name":"_targetAllocations","type":"tuple[]"}],"stateMutability":"nonpayable","type":"constructor"},{"inputs":[{"internalType":"bytes","name":"innerError","type":"bytes"}],"name":"CallError","type":"error"},{"inputs":[],"name":"IDLE_MARKET_ID","outputs":[{"internalType":"Id","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"MORPHO","outputs":[{"internalType":"contract IMorpho","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"VAULT_ADDRESS","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"bytes","name":"checkerBytecode","type":"bytes"}],"name":"checkReallocationNeeded","outputs":[{"internalType":"bool","name":"","type":"bool"},{"components":[{"components":[{"internalType":"address","name":"loanToken","type":"address"},{"internalType":"address","name":"collateralToken","type":"address"},{"internalType":"address","name":"oracle","type":"address"},{"internalType":"address","name":"irm","type":"address"},{"internalType":"uint256","name":"lltv","type":"uint256"}],"internalType":"struct MarketParams","name":"marketParams","type":"tuple"},{"internalType":"uint256","name":"assets","type":"uint256"}],"internalType":"struct MarketAllocation[]","name":"","type":"tuple[]"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"Id","name":"id","type":"bytes32"}],"name":"getTargetAllocation","outputs":[{"components":[{"internalType":"uint64","name":"maxUtilization","type":"uint64"},{"internalType":"uint64","name":"targetUtilization","type":"uint64"},{"internalType":"uint64","name":"minUtilization","type":"uint64"},{"internalType":"uint256","name":"minLiquidity","type":"uint256"}],"internalType":"struct TargetAllocator.TargetAllocation","name":"","type":"tuple"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"sender","type":"address"}],"name":"isVaultAllocator","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"keeperAddress","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"bytes","name":"call","type":"bytes"}],"name":"keeperCall","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes","name":"checkerBytecode","type":"bytes"}],"name":"keeperCheck","outputs":[{"internalType":"bool","name":"","type":"bool"},{"internalType":"bytes","name":"call","type":"bytes"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"lastReallocationTimestamp","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"minDelayBetweenReallocations","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"minReallocationSize","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_newValue","type":"address"}],"name":"setKeeperAddress","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_newValue","type":"uint256"}],"name":"setMinDelayBetweenReallocations","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_newValue","type":"uint256"}],"name":"setMinReallocationSize","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes32","name":"marketId","type":"bytes32"},{"components":[{"internalType":"uint64","name":"maxUtilization","type":"uint64"},{"internalType":"uint64","name":"targetUtilization","type":"uint64"},{"internalType":"uint64","name":"minUtilization","type":"uint64"},{"internalType":"uint256","name":"minLiquidity","type":"uint256"}],"internalType":"struct TargetAllocator.TargetAllocation","name":"targetAllocation","type":"tuple"}],"name":"setTargetAllocation","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"Id","name":"","type":"bytes32"}],"name":"targetAllocations","outputs":[{"internalType":"uint64","name":"maxUtilization","type":"uint64"},{"internalType":"uint64","name":"targetUtilization","type":"uint64"},{"internalType":"uint64","name":"minUtilization","type":"uint64"},{"internalType":"uint256","name":"minLiquidity","type":"uint256"}],"stateMutability":"view","type":"function"}]

const parametersUrl = "https://raw.githubusercontent.com/backstop-protocol/smart-ltv/main/params/KeeperParameters.json";

interface KeeperParameters {
  checkerBytecode: string;
  maxGasPriceWei: string;
}
Web3Function.onRun(async (context: Web3FunctionContext) => {
  const { userArgs, multiChainProvider } = context;
  // console.log("targetAllocatorAddress:", userArgs.targetAllocatorAddress);

  console.log(`Reading parameters from ${parametersUrl}`);
  const parameters: KeeperParameters = await ky.get(parametersUrl).json();

  console.log(`Max gas price: ${BigNumber.from(parameters.maxGasPriceWei).div(BigNumber.from(10**9)).toString()} GWei`);
  console.log(`checkerBytecode: ${parameters.checkerBytecode}`);

  if (
    context.gelatoArgs.gasPrice.gt(BigNumber.from(parameters.maxGasPriceWei))
  ) {
    return {
      canExec: false,
      message: `Gas price too high: ${context.gelatoArgs.gasPrice.toString()} > ${
        parameters.maxGasPriceWei
      }`,
    };
  }

  const provider = multiChainProvider.default();

  console.log(provider.connection.url);
  const targetAllocatorAddress = userArgs.targetAllocatorAddress as string;
  if (!targetAllocatorAddress) {
    throw new Error("userArgs.targetAllocatorAddress not found");
  }

  const targetAllocatorContract = new Contract(
    targetAllocatorAddress,
    TARGET_ALLOCATOR_ABI,
    provider
  );

  const keeperCheckResponse =
    await targetAllocatorContract.callStatic.keeperCheck(parameters.checkerBytecode);

  // const keeperCheckResponse =
  //   await targetAllocatorContract.callStatic.checkReallocationNeeded(
  //     parameters.checkerBytecode
  //   );

  // console.log(keeperCheckResponse);
  const mustReallocate = keeperCheckResponse[0];
  console.log(`mustReallocate: ${mustReallocate}`);

  if (mustReallocate) {
    const reallocateCallData = keeperCheckResponse[1];
    console.log(`reallocateCallData: ${reallocateCallData}`);

    return {
      canExec: true,
      callData: [
        {
          to: targetAllocatorAddress,
          data: targetAllocatorContract.interface.encodeFunctionData(
            "keeperCall",
            [reallocateCallData]
          ),
        },
      ],
    };
  } else {
    return { canExec: false, message: `No reallocation needed` };
  }
});
