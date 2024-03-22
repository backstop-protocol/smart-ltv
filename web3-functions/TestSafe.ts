import { ethers } from 'ethers';
import Safe, { EthersAdapter, SafeFactory } from '@safe-global/protocol-kit';
import SafeApiKit from '@safe-global/api-kit';

async function test() {
  const chainId = 1n;
  const txServiceUrl = 'https://safe-transaction-mainnet.safe.global/api';
  const apiKit = new SafeApiKit({
    chainId,
    txServiceUrl
  });

  const RPC_URL = 'https://mainnet.infura.io/v3/eb9a2c404eef43b891e4066a148f71dd';
  const provider = new ethers.JsonRpcProvider(RPC_URL);

  const ethAdapter = new EthersAdapter({
    ethers,
    signerOrProvider: provider
  });

  const resp = await apiKit.getPendingTransactions(safeAddress);

  console.log(resp);

  const safeSdk = await Safe.create({ ethAdapter, safeAddress });

  //   const tx = resp.results[0];
  const tx = await apiKit.getTransaction(resp.results[0].safeTxHash);
  
  const safeTx = await safeSdk.toSafeTransactionType(tx);
  const encoded = await safeSdk.getEncodedTransaction(safeTx);
  console.log(encoded);
}

test();
