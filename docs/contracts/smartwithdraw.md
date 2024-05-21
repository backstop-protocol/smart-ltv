# SmartWithdraw.sol

## Overview

[SmartWithdraw](../../src/morpho/SmartWithdraw.sol) is a contract that used to check if the differents markets of a Metamorpho Vault are below a predefined risk level.

It uses the SmartLTV contract to check if the recommended LTV for a market, according to risk level and market condition, is higher than the currently set LTV for said market.

It's meant to be used by a keeper bot (Gelato bot for example).

## Functions

### keeperCheck
There are two main functions:


### keeperCheck
```solidity
function keeperCheck(
    address vaultAddress,
    uint256 marketIndex,
    SignedRiskData memory signedRiskData
  ) public view returns (bool, uint256)
```
The keeperCheck function is meant to be used off-chain to check if one market is too risky. If said market recommended LTV (using the SmartLTV contract) is lower than the current market configured LTV, then this function will return `true, {recommendedLTV}`. When this function returns true, it means that the keepCall function should be called to effectively perform the needed market liquidity withdraw.

### keeperCall
```solidity
function keeperCall(address vaultAddress, uint256 marketIndex, SignedRiskData memory signedRiskData) public
```

The keeperCall function is meant to be called only when the keeperCheck function returns true as the first return parameter. It performs the liquidity withdraw from a market to the idle market. To do so, the SmartWithdraw contract needs to be an Allocator of the Metamorpho vault
