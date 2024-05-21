// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import {RiskData} from "../interfaces/RiskData.sol";

/// @title Pythia Contract for Risk Data Signature Verification
/// @author bprotocol
/// @notice This contract is designed to manage and verify signatures for risk data, using EIP712 typed data standard.
/// @dev It uses EIP712 domain and type hashes for structuring and verifying data,
///      providing a function to easily recover the signer's address from signed risk data.
contract Pythia {
  struct EIP712Domain {
    string name;
    string version;
    uint256 chainId;
    address verifyingContract;
  }

  /// @notice Type hash for the EIP712 domain, used in constructing the domain separator.
  bytes32 public constant EIP712DOMAIN_TYPEHASH =
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

  /// @notice Type hash for RiskData, used in the EIP712 typed data signing process.
  bytes32 public constant RISKDATA_TYPEHASH =
    keccak256(
      "RiskData(address collateralAsset,address debtAsset,uint256 liquidity,uint256 volatility,uint256 liquidationBonus,uint256 lastUpdate,uint256 chainId)"
    );

  /// @notice Immutable EIP712 domain separator, unique to this contract and its deployment environment.
  bytes32 public immutable DOMAIN_SEPARATOR;

  /// @notice The chain ID on which this contract is deployed, immutable and set at contract deployment.
  uint256 public immutable chainId;

  /// @notice Initializes the contract, setting up the domain separator with the contract's details.
  constructor() {
    chainId = block.chainid;

    EIP712Domain memory domain = EIP712Domain({
      name: "SPythia",
      version: "0.0.1",
      chainId: chainId,
      verifyingContract: address(this)
    });
    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        EIP712DOMAIN_TYPEHASH,
        keccak256(bytes(domain.name)),
        keccak256(bytes(domain.version)),
        domain.chainId,
        domain.verifyingContract
      )
    );
  }

  /// @notice Hashes a RiskData struct using the EIP712 risk data type hash.
  /// @param data The RiskData struct to be hashed.
  /// @return The keccak256 hash of the encoded RiskData struct.
  function hashStruct(RiskData memory data) public pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          RISKDATA_TYPEHASH,
          data.collateralAsset,
          data.debtAsset,
          data.liquidity,
          data.volatility,
          data.liquidationBonus,
          data.lastUpdate,
          data.chainId
        )
      );
  }

  /// @notice Recovers the signer's address from the provided EIP712 signature and RiskData.
  /// @dev Uses the EIP712 standard for typed data signing to recover the address.
  /// @param data The signed RiskData struct.
  /// @param v The recovery byte of the signature.
  /// @param r Half of the ECDSA signature pair.
  /// @param s Half of the ECDSA signature pair.
  /// @return The address of the signer who signed the provided RiskData.
  function getSigner(RiskData memory data, uint8 v, bytes32 r, bytes32 s) public view returns (address) {
    bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, hashStruct(data)));
    return ecrecover(digest, v, r, s);
  }
}
