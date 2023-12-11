// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import {Test, console} from "../../../lib/forge-std/src/Test.sol";
import {Pythia} from "../../../src/core/Pythia.sol";
import {SmartLTV} from "../../../src/core/SmartLTV.sol";
import {RiskData} from "../../../src/interfaces/RiskData.sol";
import {ECDSA} from "../../../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "../../../lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

contract SmartLTVTest is Test {
  SmartLTV public smartLTV;
  Pythia public pythia;

  uint256 trustedRelayerPrivateKey = 0x42;
  address trustedRelayerAddress = vm.addr(trustedRelayerPrivateKey);
  uint256 wrongRelayerPrivateKey = 0x43;
  address wrongRelayerAddress = vm.addr(wrongRelayerPrivateKey);

  address collateralAddress = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address debtAddress = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

  function setUp() public {
    // Deploy and set up contracts here
    pythia = new Pythia();
    smartLTV = new SmartLTV(pythia, trustedRelayerAddress);
    vm.warp(1679067867);
    vm.roll(16848497);
  }

  function testInitialization() public {
    assertEq(address(smartLTV.PYTHIA()), address(pythia));
    assertEq(smartLTV.TRUSTED_RELAYER(), trustedRelayerAddress);
  }

  function testLTVWrongSignerShouldRevert(
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
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongRelayerPrivateKey, digest);

    // Expect revert with INVALID_SIGNER error
    vm.expectRevert(
      abi.encodeWithSignature("INVALID_SIGNER(address,address)", wrongRelayerAddress, trustedRelayerAddress)
    );

    // Call the ltv function
    smartLTV.ltv(
      address(0), // collateralAsset
      address(0), // debtAsset
      0, // d
      0, // beta
      0, // minClf
      data,
      v,
      r,
      s
    );
  }

  function testLTVDataTooOldShouldRevert(
    address collateralAsset,
    address debtAsset,
    uint256 liquidity,
    uint256 volatility,
    uint256 chainId
  ) public {
    RiskData memory data = RiskData({
      collateralAsset: collateralAsset,
      debtAsset: debtAsset,
      liquidity: liquidity,
      volatility: volatility,
      lastUpdate: block.timestamp - 10 days, // last update 10 days old
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
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(trustedRelayerPrivateKey, digest);

    // Expect revert with INVALID_SIGNER error
    vm.expectRevert(abi.encodeWithSignature("TIMEOUT()"));

    // Call the ltv function
    smartLTV.ltv(
      address(0), // collateralAsset
      address(0), // debtAsset
      0, // d
      0, // beta
      0, // minClf
      data,
      v,
      r,
      s
    );
  }

  function testLTVDataWrongChainIdShouldRevert(
    address collateralAsset,
    address debtAsset,
    uint256 liquidity,
    uint256 volatility,
    uint256 chainIdSeed
  ) public {
    RiskData memory data = RiskData({
      collateralAsset: collateralAsset,
      debtAsset: debtAsset,
      liquidity: liquidity,
      volatility: volatility,
      lastUpdate: block.timestamp - 3600, // 1 hour old data
      chainId: bound(chainIdSeed, block.chainid + 1, 1e20) // different chainid than the current one
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
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(trustedRelayerPrivateKey, digest);

    // Expect revert with INVALID_SIGNER error
    vm.expectRevert(abi.encodeWithSignature("WRONG_CHAINID(uint256,uint256)", data.chainId, block.chainid));

    // Call the ltv function
    smartLTV.ltv(
      address(0), // collateralAsset
      address(0), // debtAsset
      0, // d
      0, // beta
      0, // minClf
      data,
      v,
      r,
      s
    );
  }

  function testLTVDataWrongCollateralShouldRevert(address debtAsset, uint256 liquidity, uint256 volatility) public {
    RiskData memory data = RiskData({
      collateralAsset: address(25),
      debtAsset: debtAsset,
      liquidity: liquidity,
      volatility: volatility,
      lastUpdate: block.timestamp - 3600, // 1 hour old data
      chainId: block.chainid
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
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(trustedRelayerPrivateKey, digest);

    address collateral = address(0);
    // Expect revert with INVALID_SIGNER error
    vm.expectRevert(abi.encodeWithSignature("COLLATERAL_MISMATCH(address,address)", data.collateralAsset, collateral));

    // Call the ltv function
    smartLTV.ltv(
      collateral, // collateralAsset
      address(0), // debtAsset
      0, // d
      0, // beta
      0, // minClf
      data,
      v,
      r,
      s
    );
  }

  function testLTVDataWrongDebtShouldRevert(uint256 liquidity, uint256 volatility) public {
    RiskData memory data = RiskData({
      collateralAsset: collateralAddress,
      debtAsset: address(25),
      liquidity: liquidity,
      volatility: volatility,
      lastUpdate: block.timestamp - 3600, // 1 hour old data
      chainId: block.chainid
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
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(trustedRelayerPrivateKey, digest);

    // Expect revert with INVALID_SIGNER error
    vm.expectRevert(abi.encodeWithSignature("DEBT_MISMATCH(address,address)", data.debtAsset, address(0)));

    // Call the ltv function
    smartLTV.ltv(
      collateralAddress, // collateralAsset
      address(0), // debtAsset
      0, // d
      0, // beta
      0, // minClf
      data,
      v,
      r,
      s
    );
  }

  function testLTVCalculation(uint256 liquiditySeed, uint256 volatilitySeed) public {
    uint256 liquidity = bound(liquiditySeed, 1e15, 1e30);
    uint256 volatility = bound(volatilitySeed, 0.01e18, 100e18);
    RiskData memory data = RiskData({
      collateralAsset: collateralAddress,
      debtAsset: debtAddress,
      liquidity: liquidity,
      volatility: volatility,
      lastUpdate: block.timestamp - 3600, // 1 hour old data
      chainId: block.chainid
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
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(trustedRelayerPrivateKey, digest);

    // Call the ltv function
    uint256 ltv = smartLTV.ltv(
      collateralAddress, // collateralAsset
      debtAddress, // debtAsset
      10e18, // d = supply cap
      0.1e18, // beta = liquidation bonus
      3, // minClf
      data,
      v,
      r,
      s
    );
  }
}
