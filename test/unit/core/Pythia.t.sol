// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import {Test} from "../../../lib/forge-std/src/Test.sol";
import {Pythia} from "../../../src/core/Pythia.sol";
import {RiskData} from "../../../src/interfaces/RiskData.sol";
import {ECDSA} from "../../../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "../../../lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

contract PythiaTest is Test {
  Pythia pythia;

  function setUp() public {
    pythia = new Pythia();
  }

  function testDomainSeparator() public {
    bytes32 expected = 0x030a1e878cd53df6af29a4bc520fde7936a8b4ff6a735f7da53b528cfdc6e207;
    assertEq(pythia.DOMAIN_SEPARATOR(), expected);
  }

  function testHashStruct(
    address collateralAsset,
    address debtAsset,
    uint256 liquidity,
    uint256 volatility,
    uint256 lastUpdate,
    uint256 chainId
  ) public {
    RiskData memory data = RiskData({
      collateralAsset: collateralAsset,
      debtAsset: debtAsset,
      liquidity: liquidity,
      volatility: volatility,
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
        data.lastUpdate,
        data.chainId
      )
    );

    assertEq(pythia.hashStruct(data), hashedStruct);
  }

  function testGetSigner(
    uint256 signerPrivateKeySeed,
    address collateralAsset,
    address debtAsset,
    uint256 liquidity,
    uint256 volatility,
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
