export interface SmartWithdrawParameters {
    maxGasPriceWei: string; // The maximum gas price in wei
    enabled: boolean; // Whether the smart withdraw feature is enabled
    smartWithdrawContract: string; // The address of the smart withdraw contract
    vaultAddress: string; // The address of the vault
    markets: SmartWithdrawMarketParameters[]; // The list of markets to work on
}

export interface SmartWithdrawMarketParameters {
    index: number; // The index of the market in the vault's withdrawal queue
    base: string; // The base symbol of the market
    quote: string; // quote symbol
    liquidationBonus: number; // in bps
}

export interface SignedRiskData {
    riskData: RiskData,
    v: number,
    r: string,
    s: string
}

export interface RiskData {
    collateralAsset: string;
    debtAsset: string;
    liquidity: string;
    volatility: string;
    liquidationBonus: string;
    lastUpdate: number;
    chainId: number;
}

export interface GithubRawData {
    r: string;
    s: string;
    v: number;
    liquidationBonus: number;
    riskData: RiskData;
}


export const smartWithdrawABI = [{ "type": "constructor", "inputs": [{ "name": "smartLTV", "type": "address", "internalType": "address" }], "stateMutability": "nonpayable" }, { "type": "function", "name": "SMART_LTV", "inputs": [], "outputs": [{ "name": "", "type": "address", "internalType": "contract SmartLTV" }], "stateMutability": "view" }, { "type": "function", "name": "VaultMaxRiskLevel", "inputs": [{ "name": "", "type": "address", "internalType": "address" }], "outputs": [{ "name": "", "type": "uint256", "internalType": "uint256" }], "stateMutability": "view" }, { "type": "function", "name": "keeperCall", "inputs": [{ "name": "vaultAddress", "type": "address", "internalType": "address" }, { "name": "marketIndex", "type": "uint256", "internalType": "uint256" }, { "name": "signedRiskData", "type": "tuple", "internalType": "struct SignedRiskData", "components": [{ "name": "riskData", "type": "tuple", "internalType": "struct RiskData", "components": [{ "name": "collateralAsset", "type": "address", "internalType": "address" }, { "name": "debtAsset", "type": "address", "internalType": "address" }, { "name": "liquidity", "type": "uint256", "internalType": "uint256" }, { "name": "volatility", "type": "uint256", "internalType": "uint256" }, { "name": "lastUpdate", "type": "uint256", "internalType": "uint256" }, { "name": "chainId", "type": "uint256", "internalType": "uint256" }] }, { "name": "v", "type": "uint8", "internalType": "uint8" }, { "name": "r", "type": "bytes32", "internalType": "bytes32" }, { "name": "s", "type": "bytes32", "internalType": "bytes32" }] }], "outputs": [], "stateMutability": "nonpayable" }, { "type": "function", "name": "keeperCheck", "inputs": [{ "name": "vaultAddress", "type": "address", "internalType": "address" }, { "name": "marketIndex", "type": "uint256", "internalType": "uint256" }, { "name": "signedRiskData", "type": "tuple", "internalType": "struct SignedRiskData", "components": [{ "name": "riskData", "type": "tuple", "internalType": "struct RiskData", "components": [{ "name": "collateralAsset", "type": "address", "internalType": "address" }, { "name": "debtAsset", "type": "address", "internalType": "address" }, { "name": "liquidity", "type": "uint256", "internalType": "uint256" }, { "name": "volatility", "type": "uint256", "internalType": "uint256" }, { "name": "lastUpdate", "type": "uint256", "internalType": "uint256" }, { "name": "chainId", "type": "uint256", "internalType": "uint256" }] }, { "name": "v", "type": "uint8", "internalType": "uint8" }, { "name": "r", "type": "bytes32", "internalType": "bytes32" }, { "name": "s", "type": "bytes32", "internalType": "bytes32" }] }], "outputs": [{ "name": "", "type": "bool", "internalType": "bool" }, { "name": "", "type": "uint256", "internalType": "uint256" }], "stateMutability": "view" }, { "type": "function", "name": "setVaultMaxRiskLevel", "inputs": [{ "name": "vaultAddress", "type": "address", "internalType": "address" }, { "name": "newMaxRiskLevel", "type": "uint256", "internalType": "uint256" }], "outputs": [], "stateMutability": "nonpayable" }]