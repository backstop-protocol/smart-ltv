
export interface ExecutorParameters {
    multisigAddresses: string[];
    maxGasPriceWei: string;
    gnosisServiceUrl: string;
}

export interface SafeInfo {
    address: string;
    nonce: number;
    threshold: number;
    owners: string[];
    masterCopy: string;
    modules: any[];
    fallbackHandler: string;
    guard: string;
    version: string;
}

export interface PendingTransactions {
    count: number;
    next: null;
    previous: null;
    results: Result[];
    countUniqueNonce: number;
}

export interface Result {
    safe: string;
    to: string;
    value: string;
    data: string;
    operation: number;
    gasToken: string;
    safeTxGas: number;
    baseGas: number;
    gasPrice: string;
    refundReceiver: string;
    nonce: number;
    executionDate: null;
    submissionDate: Date;
    modified: Date;
    blockNumber: null;
    transactionHash: null;
    safeTxHash: string;
    proposer: string;
    executor: null;
    isExecuted: boolean;
    isSuccessful: null;
    ethGasPrice: null;
    maxFeePerGas: null;
    maxPriorityFeePerGas: null;
    gasUsed: null;
    fee: null;
    origin: string;
    dataDecoded: DataDecoded;
    confirmationsRequired: number;
    confirmations: Confirmation[];
    trusted: boolean;
    signatures: null;
}

export interface Confirmation {
    owner: string;
    submissionDate: Date;
    transactionHash: null;
    signature: string;
    signatureType: string;
}

export interface DataDecoded {
    method: string;
    parameters: Parameter[];
}

export interface Parameter {
    name: string;
    type: string;
    value: string;
}