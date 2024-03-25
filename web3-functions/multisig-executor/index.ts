import {
  Web3Function,
  Web3FunctionContext,
} from "@gelatonetwork/web3-functions-sdk";
import { ethers, BigNumber, Contract } from "ethers";
import ky from "ky"; // we recommend using ky as axios doesn't support fetch by default
import { ExecutorParameters, PendingTransactions, SafeInfo } from "./interfaces";

// eslint-disable-next-line prettier/prettier
const GNOSIS_SAFE_ABI = [{ "inputs": [], "stateMutability": "nonpayable", "type": "constructor" }, { "anonymous": false, "inputs": [{ "indexed": false, "internalType": "address", "name": "owner", "type": "address" }], "name": "AddedOwner", "type": "event" }, { "anonymous": false, "inputs": [{ "indexed": true, "internalType": "bytes32", "name": "approvedHash", "type": "bytes32" }, { "indexed": true, "internalType": "address", "name": "owner", "type": "address" }], "name": "ApproveHash", "type": "event" }, { "anonymous": false, "inputs": [{ "indexed": false, "internalType": "address", "name": "handler", "type": "address" }], "name": "ChangedFallbackHandler", "type": "event" }, { "anonymous": false, "inputs": [{ "indexed": false, "internalType": "address", "name": "guard", "type": "address" }], "name": "ChangedGuard", "type": "event" }, { "anonymous": false, "inputs": [{ "indexed": false, "internalType": "uint256", "name": "threshold", "type": "uint256" }], "name": "ChangedThreshold", "type": "event" }, { "anonymous": false, "inputs": [{ "indexed": false, "internalType": "address", "name": "module", "type": "address" }], "name": "DisabledModule", "type": "event" }, { "anonymous": false, "inputs": [{ "indexed": false, "internalType": "address", "name": "module", "type": "address" }], "name": "EnabledModule", "type": "event" }, { "anonymous": false, "inputs": [{ "indexed": false, "internalType": "bytes32", "name": "txHash", "type": "bytes32" }, { "indexed": false, "internalType": "uint256", "name": "payment", "type": "uint256" }], "name": "ExecutionFailure", "type": "event" }, { "anonymous": false, "inputs": [{ "indexed": true, "internalType": "address", "name": "module", "type": "address" }], "name": "ExecutionFromModuleFailure", "type": "event" }, { "anonymous": false, "inputs": [{ "indexed": true, "internalType": "address", "name": "module", "type": "address" }], "name": "ExecutionFromModuleSuccess", "type": "event" }, { "anonymous": false, "inputs": [{ "indexed": false, "internalType": "bytes32", "name": "txHash", "type": "bytes32" }, { "indexed": false, "internalType": "uint256", "name": "payment", "type": "uint256" }], "name": "ExecutionSuccess", "type": "event" }, { "anonymous": false, "inputs": [{ "indexed": false, "internalType": "address", "name": "owner", "type": "address" }], "name": "RemovedOwner", "type": "event" }, { "anonymous": false, "inputs": [{ "indexed": true, "internalType": "address", "name": "sender", "type": "address" }, { "indexed": false, "internalType": "uint256", "name": "value", "type": "uint256" }], "name": "SafeReceived", "type": "event" }, { "anonymous": false, "inputs": [{ "indexed": true, "internalType": "address", "name": "initiator", "type": "address" }, { "indexed": false, "internalType": "address[]", "name": "owners", "type": "address[]" }, { "indexed": false, "internalType": "uint256", "name": "threshold", "type": "uint256" }, { "indexed": false, "internalType": "address", "name": "initializer", "type": "address" }, { "indexed": false, "internalType": "address", "name": "fallbackHandler", "type": "address" }], "name": "SafeSetup", "type": "event" }, { "anonymous": false, "inputs": [{ "indexed": true, "internalType": "bytes32", "name": "msgHash", "type": "bytes32" }], "name": "SignMsg", "type": "event" }, { "stateMutability": "nonpayable", "type": "fallback" }, { "inputs": [], "name": "VERSION", "outputs": [{ "internalType": "string", "name": "", "type": "string" }], "stateMutability": "view", "type": "function" }, { "inputs": [{ "internalType": "address", "name": "owner", "type": "address" }, { "internalType": "uint256", "name": "_threshold", "type": "uint256" }], "name": "addOwnerWithThreshold", "outputs": [], "stateMutability": "nonpayable", "type": "function" }, { "inputs": [{ "internalType": "bytes32", "name": "hashToApprove", "type": "bytes32" }], "name": "approveHash", "outputs": [], "stateMutability": "nonpayable", "type": "function" }, { "inputs": [{ "internalType": "address", "name": "", "type": "address" }, { "internalType": "bytes32", "name": "", "type": "bytes32" }], "name": "approvedHashes", "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }], "stateMutability": "view", "type": "function" }, { "inputs": [{ "internalType": "uint256", "name": "_threshold", "type": "uint256" }], "name": "changeThreshold", "outputs": [], "stateMutability": "nonpayable", "type": "function" }, { "inputs": [{ "internalType": "bytes32", "name": "dataHash", "type": "bytes32" }, { "internalType": "bytes", "name": "data", "type": "bytes" }, { "internalType": "bytes", "name": "signatures", "type": "bytes" }, { "internalType": "uint256", "name": "requiredSignatures", "type": "uint256" }], "name": "checkNSignatures", "outputs": [], "stateMutability": "view", "type": "function" }, { "inputs": [{ "internalType": "bytes32", "name": "dataHash", "type": "bytes32" }, { "internalType": "bytes", "name": "data", "type": "bytes" }, { "internalType": "bytes", "name": "signatures", "type": "bytes" }], "name": "checkSignatures", "outputs": [], "stateMutability": "view", "type": "function" }, { "inputs": [{ "internalType": "address", "name": "prevModule", "type": "address" }, { "internalType": "address", "name": "module", "type": "address" }], "name": "disableModule", "outputs": [], "stateMutability": "nonpayable", "type": "function" }, { "inputs": [], "name": "domainSeparator", "outputs": [{ "internalType": "bytes32", "name": "", "type": "bytes32" }], "stateMutability": "view", "type": "function" }, { "inputs": [{ "internalType": "address", "name": "module", "type": "address" }], "name": "enableModule", "outputs": [], "stateMutability": "nonpayable", "type": "function" }, { "inputs": [{ "internalType": "address", "name": "to", "type": "address" }, { "internalType": "uint256", "name": "value", "type": "uint256" }, { "internalType": "bytes", "name": "data", "type": "bytes" }, { "internalType": "enum Enum.Operation", "name": "operation", "type": "uint8" }, { "internalType": "uint256", "name": "safeTxGas", "type": "uint256" }, { "internalType": "uint256", "name": "baseGas", "type": "uint256" }, { "internalType": "uint256", "name": "gasPrice", "type": "uint256" }, { "internalType": "address", "name": "gasToken", "type": "address" }, { "internalType": "address", "name": "refundReceiver", "type": "address" }, { "internalType": "uint256", "name": "_nonce", "type": "uint256" }], "name": "encodeTransactionData", "outputs": [{ "internalType": "bytes", "name": "", "type": "bytes" }], "stateMutability": "view", "type": "function" }, { "inputs": [{ "internalType": "address", "name": "to", "type": "address" }, { "internalType": "uint256", "name": "value", "type": "uint256" }, { "internalType": "bytes", "name": "data", "type": "bytes" }, { "internalType": "enum Enum.Operation", "name": "operation", "type": "uint8" }, { "internalType": "uint256", "name": "safeTxGas", "type": "uint256" }, { "internalType": "uint256", "name": "baseGas", "type": "uint256" }, { "internalType": "uint256", "name": "gasPrice", "type": "uint256" }, { "internalType": "address", "name": "gasToken", "type": "address" }, { "internalType": "address payable", "name": "refundReceiver", "type": "address" }, { "internalType": "bytes", "name": "signatures", "type": "bytes" }], "name": "execTransaction", "outputs": [{ "internalType": "bool", "name": "success", "type": "bool" }], "stateMutability": "payable", "type": "function" }, { "inputs": [{ "internalType": "address", "name": "to", "type": "address" }, { "internalType": "uint256", "name": "value", "type": "uint256" }, { "internalType": "bytes", "name": "data", "type": "bytes" }, { "internalType": "enum Enum.Operation", "name": "operation", "type": "uint8" }], "name": "execTransactionFromModule", "outputs": [{ "internalType": "bool", "name": "success", "type": "bool" }], "stateMutability": "nonpayable", "type": "function" }, { "inputs": [{ "internalType": "address", "name": "to", "type": "address" }, { "internalType": "uint256", "name": "value", "type": "uint256" }, { "internalType": "bytes", "name": "data", "type": "bytes" }, { "internalType": "enum Enum.Operation", "name": "operation", "type": "uint8" }], "name": "execTransactionFromModuleReturnData", "outputs": [{ "internalType": "bool", "name": "success", "type": "bool" }, { "internalType": "bytes", "name": "returnData", "type": "bytes" }], "stateMutability": "nonpayable", "type": "function" }, { "inputs": [], "name": "getChainId", "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }], "stateMutability": "view", "type": "function" }, { "inputs": [{ "internalType": "address", "name": "start", "type": "address" }, { "internalType": "uint256", "name": "pageSize", "type": "uint256" }], "name": "getModulesPaginated", "outputs": [{ "internalType": "address[]", "name": "array", "type": "address[]" }, { "internalType": "address", "name": "next", "type": "address" }], "stateMutability": "view", "type": "function" }, { "inputs": [], "name": "getOwners", "outputs": [{ "internalType": "address[]", "name": "", "type": "address[]" }], "stateMutability": "view", "type": "function" }, { "inputs": [{ "internalType": "uint256", "name": "offset", "type": "uint256" }, { "internalType": "uint256", "name": "length", "type": "uint256" }], "name": "getStorageAt", "outputs": [{ "internalType": "bytes", "name": "", "type": "bytes" }], "stateMutability": "view", "type": "function" }, { "inputs": [], "name": "getThreshold", "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }], "stateMutability": "view", "type": "function" }, { "inputs": [{ "internalType": "address", "name": "to", "type": "address" }, { "internalType": "uint256", "name": "value", "type": "uint256" }, { "internalType": "bytes", "name": "data", "type": "bytes" }, { "internalType": "enum Enum.Operation", "name": "operation", "type": "uint8" }, { "internalType": "uint256", "name": "safeTxGas", "type": "uint256" }, { "internalType": "uint256", "name": "baseGas", "type": "uint256" }, { "internalType": "uint256", "name": "gasPrice", "type": "uint256" }, { "internalType": "address", "name": "gasToken", "type": "address" }, { "internalType": "address", "name": "refundReceiver", "type": "address" }, { "internalType": "uint256", "name": "_nonce", "type": "uint256" }], "name": "getTransactionHash", "outputs": [{ "internalType": "bytes32", "name": "", "type": "bytes32" }], "stateMutability": "view", "type": "function" }, { "inputs": [{ "internalType": "address", "name": "module", "type": "address" }], "name": "isModuleEnabled", "outputs": [{ "internalType": "bool", "name": "", "type": "bool" }], "stateMutability": "view", "type": "function" }, { "inputs": [{ "internalType": "address", "name": "owner", "type": "address" }], "name": "isOwner", "outputs": [{ "internalType": "bool", "name": "", "type": "bool" }], "stateMutability": "view", "type": "function" }, { "inputs": [], "name": "nonce", "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }], "stateMutability": "view", "type": "function" }, { "inputs": [{ "internalType": "address", "name": "prevOwner", "type": "address" }, { "internalType": "address", "name": "owner", "type": "address" }, { "internalType": "uint256", "name": "_threshold", "type": "uint256" }], "name": "removeOwner", "outputs": [], "stateMutability": "nonpayable", "type": "function" }, { "inputs": [{ "internalType": "address", "name": "to", "type": "address" }, { "internalType": "uint256", "name": "value", "type": "uint256" }, { "internalType": "bytes", "name": "data", "type": "bytes" }, { "internalType": "enum Enum.Operation", "name": "operation", "type": "uint8" }], "name": "requiredTxGas", "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }], "stateMutability": "nonpayable", "type": "function" }, { "inputs": [{ "internalType": "address", "name": "handler", "type": "address" }], "name": "setFallbackHandler", "outputs": [], "stateMutability": "nonpayable", "type": "function" }, { "inputs": [{ "internalType": "address", "name": "guard", "type": "address" }], "name": "setGuard", "outputs": [], "stateMutability": "nonpayable", "type": "function" }, { "inputs": [{ "internalType": "address[]", "name": "_owners", "type": "address[]" }, { "internalType": "uint256", "name": "_threshold", "type": "uint256" }, { "internalType": "address", "name": "to", "type": "address" }, { "internalType": "bytes", "name": "data", "type": "bytes" }, { "internalType": "address", "name": "fallbackHandler", "type": "address" }, { "internalType": "address", "name": "paymentToken", "type": "address" }, { "internalType": "uint256", "name": "payment", "type": "uint256" }, { "internalType": "address payable", "name": "paymentReceiver", "type": "address" }], "name": "setup", "outputs": [], "stateMutability": "nonpayable", "type": "function" }, { "inputs": [{ "internalType": "bytes32", "name": "", "type": "bytes32" }], "name": "signedMessages", "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }], "stateMutability": "view", "type": "function" }, { "inputs": [{ "internalType": "address", "name": "targetContract", "type": "address" }, { "internalType": "bytes", "name": "calldataPayload", "type": "bytes" }], "name": "simulateAndRevert", "outputs": [], "stateMutability": "nonpayable", "type": "function" }, { "inputs": [{ "internalType": "address", "name": "prevOwner", "type": "address" }, { "internalType": "address", "name": "oldOwner", "type": "address" }, { "internalType": "address", "name": "newOwner", "type": "address" }], "name": "swapOwner", "outputs": [], "stateMutability": "nonpayable", "type": "function" }, { "stateMutability": "payable", "type": "receive" }]


Web3Function.onRun(async (context: Web3FunctionContext) => {
  const { userArgs, multiChainProvider } = context;
  const parametersUrl = userArgs.parametersUrl.toString();
  if (!parametersUrl) {
    throw new Error(`Cannot get parameters url from userArgs: ${userArgs.parametersUrl}`);
  }

  // console.log("parametersUrl:", userArgs.parametersUrl);

  const provider = multiChainProvider.default();

  // console.log(`Reading parameters from ${parametersUrl}`);
  const parameters: ExecutorParameters = await ky.get(parametersUrl).json();
  validateParameters(parameters);

  console.log(`PARAMETERS: Max gas price: ${BigNumber.from(parameters.maxGasPriceWei)
    .div(BigNumber.from(10 ** 9))
    .toString()} GWei | Service URL: ${parameters.gnosisServiceUrl} | Multisigs: ${parameters.multisigAddresses.join(',')}`)

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

  for (const safeAddress of parameters.multisigAddresses) {
    console.log(`[${safeAddress}] | Working on safe ${safeAddress}`);

    // get the nonce
    // get safe example https://safe-transaction-mainnet.safe.global/api/v1/safes/0xF89e9cf758EEd6ae41822DEe15945583C121d10e/
    const safeInfoUrl = `${parameters.gnosisServiceUrl}/safes/${safeAddress}/`;
    const safeInfo: SafeInfo = await ky.get(safeInfoUrl).json();
    if (safeInfo.nonce == undefined || Number.isNaN(safeInfo.nonce)) {
      throw new Error(`Cannot read safe nonce from url ${safeInfoUrl}`);
    }

    console.log(`[${safeAddress}] | nonce: ${safeInfo.nonce}`);

    // get the pending transactions (if any)
    // get tx example https://safe-transaction-mainnet.safe.global/api/v1/safes/0xF89e9cf758EEd6ae41822DEe15945583C121d10e/multisig-transactions/?nonce__gte=5&executed=false
    const pendingTxUrl = `${parameters.gnosisServiceUrl}/safes/${safeAddress}/multisig-transactions/?nonce__gte=${safeInfo.nonce}&executed=false`
    // console.log(`pendingTxUrl : ${pendingTxUrl}`);
    const pendingTxs: PendingTransactions = await ky.get(pendingTxUrl).json();
    if (pendingTxs.count > 0) {
      console.log(`[${safeAddress}] | ${pendingTxs.count} pending transactions`);
      for (const pendingTx of pendingTxs.results) {
        console.log(`[${safeAddress}] | pending transaction ${pendingTx.safeTxHash} has ${pendingTx.confirmations.length}/${pendingTx.confirmationsRequired} confirmations`);

        if (pendingTx.confirmations.length >= pendingTx.confirmationsRequired) {
          console.log(`[${safeAddress}] | will execute transaction ${pendingTx.safeTxHash}`);
          const safeContract = new Contract(safeAddress, GNOSIS_SAFE_ABI, provider);

          let concatSignatures = '0x';
          // order confirmation by owners
          // console.log(`before sort: ${pendingTx.confirmations.map(_ => _.owner)}`);
          pendingTx.confirmations.sort((a,b) => { return a.owner.localeCompare(b.owner) });
          // console.log(`after sort: ${pendingTx.confirmations.map(_ => _.owner)}`);
          for (const confirmation of pendingTx.confirmations) {
            // console.log(`adding signature ${confirmation.signature} to ${concatSignatures}`);
            concatSignatures += confirmation.signature.substring(2);
            // console.log(`new concat: ${concatSignatures}`);
          }

          const encoded = safeContract.interface.encodeFunctionData('execTransaction', [
            pendingTx.to, // to
            pendingTx.value, // value
            pendingTx.data == null || undefined ? '0x' : pendingTx.data, // data, might be null when transfering eth
            pendingTx.operation, // operation
            pendingTx.safeTxGas, // safeTxGas
            pendingTx.baseGas, // baseGas
            pendingTx.gasPrice, // gasPrice
            pendingTx.gasToken, // gasToken
            pendingTx.refundReceiver, // refundReceiver
            concatSignatures // signatures
          ]);

          console.log(encoded);
          return {
            canExec: true,
            callData: [
              {
                to: safeAddress,
                data: encoded,
              },
            ],
          };
        }
      }
    }
  }

  return { canExec: false, message: `Nothing to execute` };
});

function validateParameters(parameters: ExecutorParameters) {
  if (!parameters.maxGasPriceWei || Number.isNaN(parameters.maxGasPriceWei)) {
    throw new Error(`Cannot read param maxGasPriceWei: ${parameters.maxGasPriceWei}`);
  }

  if (
    !parameters.multisigAddresses ||
    parameters.multisigAddresses.length == 0
  ) {
    throw new Error(
      `Cannot read param multisigAddresses: ${parameters.multisigAddresses}`
    );
  }

  if (
    !parameters.gnosisServiceUrl
  ) {
    throw new Error(
      `Cannot read param gnosisServiceUrl`
    );
  }
}
