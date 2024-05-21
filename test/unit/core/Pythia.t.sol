// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import {Test} from "../../../lib/forge-std/src/Test.sol";
import {Pythia} from "../../../src/core/Pythia.sol";
import {RiskData} from "../../../src/interfaces/RiskData.sol";
import {MessageHashUtils} from "../../../lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

/// @title Testing the Pythia Contract for Risk Data Signature Verification
contract PythiaTest is Test {
  struct EIP712Domain {
    string name;
    string version;
    uint256 chainId;
    address verifyingContract;
  }

  bytes constant PYTHIA_CODE = type(Pythia).creationCode;
  event DEPLOYMENT_CODE(bytes code);

  Pythia pythia;

  /// @notice Set up the testing environment
  function setUp() public {
    pythia = new Pythia();
  }

  function testLogPythiaCreationCode() public {
    emit DEPLOYMENT_CODE(PYTHIA_CODE);
  }

  /// @notice Test to verify the DOMAIN_SEPARATOR is correctly set in the Pythia contract
  function testDomainSeparator() public {
    EIP712Domain memory domain = EIP712Domain({
      name: "SPythia",
      version: "0.0.1",
      chainId: block.chainid,
      verifyingContract: address(pythia)
    });

    bytes32 expectedDomainSeparator = keccak256(
      abi.encode(
        pythia.EIP712DOMAIN_TYPEHASH(),
        keccak256(bytes(domain.name)),
        keccak256(bytes(domain.version)),
        domain.chainId,
        domain.verifyingContract
      )
    );

    // bytes32 expected = 0x030a1e878cd53df6af29a4bc520fde7936a8b4ff6a735f7da53b528cfdc6e207;
    assertEq(pythia.DOMAIN_SEPARATOR(), expectedDomainSeparator);
  }

  /// @notice Test to ensure the hashStruct function in Pythia correctly hashes RiskData
  /// @param collateralAsset The address of the collateral asset
  /// @param debtAsset The address of the debt asset
  /// @param liquidity The liquidity amount
  /// @param volatility The volatility value
  /// @param lastUpdate The timestamp of the last update
  /// @param chainId The blockchain's chain ID
  function testHashStruct(
    address collateralAsset,
    address debtAsset,
    uint256 liquidity,
    uint256 volatility,
    uint256 liquidationBonus,
    uint256 lastUpdate,
    uint256 chainId
  ) public {
    RiskData memory data = RiskData({
      collateralAsset: collateralAsset,
      debtAsset: debtAsset,
      liquidity: liquidity,
      volatility: volatility,
      liquidationBonus: liquidationBonus,
      lastUpdate: lastUpdate,
      chainId: chainId
    });

    bytes32 hashedStruct = keccak256(
      abi.encode(
        pythia.RISKDATA_TYPEHASH(),
        data.collateralAsset,
        data.debtAsset,
        data.liquidity,
        data.volatility,
        data.liquidationBonus,
        data.lastUpdate,
        data.chainId
      )
    );

    assertEq(pythia.hashStruct(data), hashedStruct);
  }

  /// @notice Test to verify the correct recovery of a signer's address from an EIP712 signature in Pythia
  /// @param signerPrivateKeySeed A seed for generating a private key for the signer
  /// @param collateralAsset The address of the collateral asset
  /// @param debtAsset The address of the debt asset
  /// @param liquidity The liquidity amount
  /// @param volatility The volatility value
  /// @param lastUpdate The timestamp of the last update
  /// @param chainId The blockchain's chain ID
  function testGetSigner(
    uint256 signerPrivateKeySeed,
    address collateralAsset,
    address debtAsset,
    uint256 liquidity,
    uint256 volatility,
    uint256 liquidationBonus,
    uint256 lastUpdate,
    uint256 chainId
  ) public {
    uint256 signerPrivateKey = bound(signerPrivateKeySeed, 1, 1e20);
    address signerAddress = vm.addr(signerPrivateKey);

    RiskData memory data = RiskData({
      collateralAsset: collateralAsset,
      debtAsset: debtAsset,
      liquidity: liquidity,
      volatility: volatility,
      liquidationBonus: liquidationBonus,
      lastUpdate: lastUpdate,
      chainId: chainId
    });

    // sign risk data
    bytes32 structHash = keccak256(
      abi.encode(
        pythia.RISKDATA_TYPEHASH(),
        data.collateralAsset,
        data.debtAsset,
        data.liquidity,
        data.volatility,
        data.liquidationBonus,
        data.lastUpdate,
        data.chainId
      )
    );

    bytes32 digest = MessageHashUtils.toTypedDataHash(pythia.DOMAIN_SEPARATOR(), structHash);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);

    address signerAccordingToPythia = pythia.getSigner(data, v, r, s);

    assertEq(signerAccordingToPythia, signerAddress);
  }
}
