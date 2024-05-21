# SmartLTV.sol

## Overview

[SmartLTV.sol](../../src/core/SmartLTV.sol) is a core contract in the Smart LTV project, responsible for calculating the Loan-to-Value (LTV) ratio based on market conditions and risk data. It leverages risk data verification and advanced mathematical formulas to ensure accurate LTV calculations in decentralized finance platforms.

## Features

- **LTV Calculation**: Computes the LTV ratio using market and risk data.
- **Risk Data Verification**: Integrates with the Pythia contract for signature verification of risk data.

## Constants

- `MAX_MANTISSA`: Defines the maximum mantissa for LTV calculations. It is needed because when some conditions are met, the value passed to the RiskyMath library creates a uint256 overflow. The conditions are low liquidity or very high volatility which should always create a recommended LTV of 0%. That's why in the contract, we set the LTV to 0 if the computed mantissa (before calling the RiskyMath library) is met
  
## Immutable Variables

- `PYTHIA`: Address of the Pythia contract used for risk data verification.
- `TRUSTED_RELAYER`: Address of the trusted relayer for verifying data authenticity.
  
## Constructor

Sets up the SmartLTV contract with addresses for Pythia and the trusted relayer.

## Functions

### ltv

```solidity
function ltv(
    address collateralAsset,
    address debtAsset,
    uint d,
    uint beta,
    uint minClf,
    RiskData memory riskData,
    uint8 v,
    bytes32 r,
    bytes32 s
) public view returns (uint)
```

- **Description**: Calculates the Loan-to-Value ratio considering various risk parameters.
- **Parameters**:
  - `collateralAsset`: Address of the collateral asset.
  - `debtAsset`: Address of the debt asset.
  - `d`: Supply cap used in the LTV calculation.
  - `beta`: Liquidation bonus used in the LTV calculation.
  - `minClf`: Minimum confidence level factor.
  - `riskData`: Struct containing risk parameters.
  - `v`, `r`, `s`: Components of the Ethereum signature.
- **Returns**: The calculated Loan-to-Value ratio.

## Usage

The SmartLTV contract is utilized for determining the LTV ratios in lending scenarios, crucial for decision-making in loan issuance and management in DeFi applications.
