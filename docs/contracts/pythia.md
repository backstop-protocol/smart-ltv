# Pythia.sol

## Overview

[Pythia.sol](../../src/core/Pythia.sol) is a Solidity smart contract part of the Smart LTV project, designed for risk data signature verification in decentralized finance applications. It uses the EIP712 typed data standard to provide secure and efficient verification processes.

## Features

- **EIP712 Standard**: Implements EIP712 for structured and efficient data verification.
- **Signature Recovery**: Provides functionality to recover the signer's address from signed risk data.
- **Domain Separation**: Utilizes EIP712 domain separation to uniquely identify and secure the contract's context.

## Structs

- **EIP712Domain**: Represents the EIP712 domain with fields like `name`, `version`, `chainId`, and `verifyingContract`.

## Constants

- `EIP712DOMAIN_TYPEHASH`: Type hash for the EIP712 domain, used in constructing the domain separator.
- `RISKDATA_TYPEHASH`: Type hash for RiskData, used in the EIP712 typed data signing process.

## Immutable Variables

- `DOMAIN_SEPARATOR`: Immutable EIP712 domain separator, unique to this contract and its deployment environment.
- `chainId`: The chain ID on which the contract is deployed, immutable and set at contract deployment.

## Constructor

Initializes the contract, setting up the domain separator with the contract's details.

## Functions

### hashStruct

```solidity
function hashStruct(RiskData memory data) public pure returns (bytes32)
```
- **Description**: Hashes a RiskData struct using the EIP712 risk data type hash.
- **Parameters**: data - The RiskData struct to be hashed.
- **Returns**: The keccak256 hash of the encoded RiskData struct.

### getSigner

```solidity
function getSigner(RiskData memory data, uint8 v, bytes32 r, bytes32 s) public view returns (address)
```

- **Description**: Recovers the signer's address from the provided EIP712 signature and RiskData.
- **Parameters**:
  - data: The signed RiskData struct.
  - v, r, s: Components of the Ethereum signature.
- **Returns**: The address of the signer who signed the provided RiskData.

## Usage Example

The contract is typically used for verifying signatures on risk data in DeFi applications. After deploying the Pythia contract, you can use the getSigner function to recover and verify the address of a signer who signed the risk data.