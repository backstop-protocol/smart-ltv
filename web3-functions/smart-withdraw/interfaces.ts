export interface SmartWithdrawParameters {
    maxGasPriceWei: string; // The maximum gas price in wei
    enabled: boolean; // Whether the smart withdraw feature is enabled
    smartWithdrawContract: string; // The address of the smart withdraw contract
    vaultAddress: string; // The address of the vault
    riskDataBasePath: string; // The base path of the risk data to get
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


export const smartWithdrawABI = [{"inputs":[{"internalType":"address","name":"smartLTV","type":"address"}],"stateMutability":"nonpayable","type":"constructor"},{"inputs":[],"name":"SMART_LTV","outputs":[{"internalType":"contract SmartLTV","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"VaultMaxRiskLevel","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"VaultMinLiquidityToWithdraw","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"vaultAddress","type":"address"},{"internalType":"uint256","name":"marketIndex","type":"uint256"},{"components":[{"components":[{"internalType":"address","name":"collateralAsset","type":"address"},{"internalType":"address","name":"debtAsset","type":"address"},{"internalType":"uint256","name":"liquidity","type":"uint256"},{"internalType":"uint256","name":"volatility","type":"uint256"},{"internalType":"uint256","name":"liquidationBonus","type":"uint256"},{"internalType":"uint256","name":"lastUpdate","type":"uint256"},{"internalType":"uint256","name":"chainId","type":"uint256"}],"internalType":"struct RiskData","name":"riskData","type":"tuple"},{"internalType":"uint8","name":"v","type":"uint8"},{"internalType":"bytes32","name":"r","type":"bytes32"},{"internalType":"bytes32","name":"s","type":"bytes32"}],"internalType":"struct SignedRiskData","name":"signedRiskData","type":"tuple"}],"name":"keeperCall","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"vaultAddress","type":"address"},{"internalType":"uint256","name":"marketIndex","type":"uint256"},{"components":[{"components":[{"internalType":"address","name":"collateralAsset","type":"address"},{"internalType":"address","name":"debtAsset","type":"address"},{"internalType":"uint256","name":"liquidity","type":"uint256"},{"internalType":"uint256","name":"volatility","type":"uint256"},{"internalType":"uint256","name":"liquidationBonus","type":"uint256"},{"internalType":"uint256","name":"lastUpdate","type":"uint256"},{"internalType":"uint256","name":"chainId","type":"uint256"}],"internalType":"struct RiskData","name":"riskData","type":"tuple"},{"internalType":"uint8","name":"v","type":"uint8"},{"internalType":"bytes32","name":"r","type":"bytes32"},{"internalType":"bytes32","name":"s","type":"bytes32"}],"internalType":"struct SignedRiskData","name":"signedRiskData","type":"tuple"}],"name":"keeperCheck","outputs":[{"internalType":"bool","name":"","type":"bool"},{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"vaultAddress","type":"address"},{"internalType":"uint256","name":"newMaxRiskLevel","type":"uint256"}],"name":"setVaultMaxRiskLevel","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"vaultAddress","type":"address"},{"internalType":"uint256","name":"newMinLiquidity","type":"uint256"}],"name":"setVaultMinLiquidityToWithdraw","outputs":[],"stateMutability":"nonpayable","type":"function"}]