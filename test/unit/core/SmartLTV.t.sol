// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../../../lib/forge-std/src/Test.sol";
import {Pythia} from "../../../src/core/Pythia.sol";
import {SmartLTV} from "../../../src/core/SmartLTV.sol";
import {RiskData} from "../../../src/interfaces/RiskData.sol";
import {MessageHashUtils} from "../../../lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {Math} from "../../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {RiskyMath} from "../../../src/lib/RiskyMath.sol";
import "../../../src/lib/ErrorLib.sol";
import "../../TestUtils.sol";

/// @title Testing the SmartLTV Contract for Loan-to-Value Calculation
contract SmartLTVTest is Test {
  SmartLTV public smartLTV;
  Pythia public pythia;

  uint256 trustedRelayerPrivateKey = 0x42;
  address trustedRelayerAddress = vm.addr(trustedRelayerPrivateKey);
  uint256 wrongRelayerPrivateKey = 0x43;
  address wrongRelayerAddress = vm.addr(wrongRelayerPrivateKey);

  address collateralAddress = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address debtAddress = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

  /// @notice Set up the testing environment
  function setUp() public {
    pythia = new Pythia();
    smartLTV = new SmartLTV(pythia, trustedRelayerAddress);
    vm.warp(1679067867);
    vm.roll(16848497);
  }

  function computeLtv(
    uint256 liquidity,
    uint256 volatility,
    uint256 cap,
    uint256 minCLF,
    uint256 liquidationBonus
  ) internal view returns (uint256) {
    console.log("liquidity: %s", liquidity);
    console.log("volatility: %s", volatility);
    console.log("cap: %s", cap);
    console.log("minCLF: %s", minCLF);
    console.log("liquidationBonus: %s", liquidationBonus);

    // does the same calculation as the smartLTV contract
    uint cTimesSigma = (minCLF * volatility) / 1e18;
    console.log("cTimesSigma: %s", cTimesSigma);
    uint sqrtValue = RiskyMath.sqrt((1e18 * liquidity) / cap) * 1e9;
    console.log("sqrtValue: %s", sqrtValue);
    uint mantissa = ((1 << 59) * cTimesSigma) / sqrtValue;
    console.log("mantissa: %s", mantissa);
    // when mantissa is higher than MAX_MANTISSA, ltv is 0%
    if (mantissa >= smartLTV.MAX_MANTISSA()) {
      return 0;
    }
    uint expResult = RiskyMath.generalExp(mantissa, 59);
    console.log("expResult: %s", expResult);
    uint divResult = (1e18 * (1 << 59)) / expResult;
    console.log("divResult: %s", divResult);
    (, uint256 computedLTV) = Math.trySub(divResult, liquidationBonus);
    return computedLTV;
  }

  /// @notice Tests the initialization and correct setting of dependencies in the SmartLTV contract
  function testInitialization() public {
    assertEq(address(smartLTV.PYTHIA()), address(pythia));
    assertEq(smartLTV.TRUSTED_RELAYER(), trustedRelayerAddress);
  }

  /// @notice Tests the LTV calculation function in the SmartLTV contract with incorrect signer, expecting a revert
  /// @param collateralAsset The address of the collateral asset
  /// @param debtAsset The address of the debt asset
  /// @param liquidity The liquidity value
  /// @param volatility The volatility value
  /// @param lastUpdate The timestamp of the last update
  /// @param chainId The chain ID
  function testLTVWrongSignerShouldRevert(
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
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongRelayerPrivateKey, digest);

    // Expect revert with INVALID_SIGNER error
    vm.expectRevert(
      abi.encodeWithSelector(ErrorLib.INVALID_SIGNER.selector, wrongRelayerAddress, trustedRelayerAddress)
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

  /// @notice Tests the LTV calculation function in the SmartLTV contract with outdated data, expecting a revert
  /// @param collateralAsset The address of the collateral asset
  /// @param debtAsset The address of the debt asset
  /// @param liquidity The liquidity value
  /// @param volatility The volatility value
  /// @param chainId The chain ID
  function testLTVDataTooOldShouldRevert(
    address collateralAsset,
    address debtAsset,
    uint256 liquidity,
    uint256 volatility,
    uint256 liquidationBonus,
    uint256 chainId
  ) public {
    RiskData memory data = RiskData({
      collateralAsset: collateralAsset,
      debtAsset: debtAsset,
      liquidity: liquidity,
      volatility: volatility,
      liquidationBonus: liquidationBonus,
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
        data.liquidationBonus,
        data.lastUpdate,
        data.chainId
      )
    );

    bytes32 digest = MessageHashUtils.toTypedDataHash(pythia.DOMAIN_SEPARATOR(), structHash);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(trustedRelayerPrivateKey, digest);

    // Expect revert with INVALID_SIGNER error
    vm.expectRevert(abi.encodeWithSelector(ErrorLib.TIMEOUT.selector));

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

  /// @notice Tests the LTV calculation function in the SmartLTV contract with incorrect chain ID, expecting a revert
  /// @param collateralAsset The address of the collateral asset
  /// @param debtAsset The address of the debt asset
  /// @param liquidity The liquidity value
  /// @param volatility The volatility value
  /// @param chainIdSeed A seed value to generate an incorrect chain ID
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
      liquidationBonus: 0.005e18, // 0.5% liquidation bonus
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
        data.liquidationBonus,
        data.lastUpdate,
        data.chainId
      )
    );

    bytes32 digest = MessageHashUtils.toTypedDataHash(pythia.DOMAIN_SEPARATOR(), structHash);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(trustedRelayerPrivateKey, digest);

    // Expect revert with INVALID_SIGNER error
    vm.expectRevert(abi.encodeWithSelector(ErrorLib.WRONG_CHAINID.selector, data.chainId, block.chainid));

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

  /// @notice Tests the LTV calculation function in the SmartLTV contract with incorrect collateral, expecting a revert
  /// @param debtAsset The address of the debt asset
  /// @param liquidity The liquidity value
  /// @param volatility The volatility value
  function testLTVDataWrongCollateralShouldRevert(address debtAsset, uint256 liquidity, uint256 volatility) public {
    RiskData memory data = RiskData({
      collateralAsset: address(25),
      debtAsset: debtAsset,
      liquidity: liquidity,
      volatility: volatility,
      liquidationBonus: 0.005e18, // 0.5% liquidation bonus
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
        data.liquidationBonus,
        data.lastUpdate,
        data.chainId
      )
    );

    bytes32 digest = MessageHashUtils.toTypedDataHash(pythia.DOMAIN_SEPARATOR(), structHash);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(trustedRelayerPrivateKey, digest);

    address collateral = address(0);
    // Expect revert with INVALID_SIGNER error
    vm.expectRevert(abi.encodeWithSelector(ErrorLib.COLLATERAL_MISMATCH.selector, data.collateralAsset, collateral));

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

  /// @notice Tests the LTV calculation function in the SmartLTV contract with incorrect debt, expecting a revert
  /// @param liquidity The liquidity value
  /// @param volatility The volatility value
  function testLTVDataWrongDebtShouldRevert(uint256 liquidity, uint256 volatility) public {
    RiskData memory data = RiskData({
      collateralAsset: collateralAddress,
      debtAsset: address(25),
      liquidity: liquidity,
      volatility: volatility,
      liquidationBonus: 0.005e18, // 0.5% liquidation bonus
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
        data.liquidationBonus,
        data.lastUpdate,
        data.chainId
      )
    );

    bytes32 digest = MessageHashUtils.toTypedDataHash(pythia.DOMAIN_SEPARATOR(), structHash);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(trustedRelayerPrivateKey, digest);

    // Expect revert with INVALID_SIGNER error
    vm.expectRevert(abi.encodeWithSelector(ErrorLib.DEBT_MISMATCH.selector, data.debtAsset, address(0)));

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

  /// @notice Tests the LTV calculation function in the SmartLTV contract with various inputs using fuzz testing
  /// @param liquiditySeed A seed value for liquidity
  /// @param volatilitySeed A seed value for volatility
  /// @param capSeed A seed value for supply cap
  /// @param liquidationBonusSeed A seed value for liquidation bonus
  /// @param minCLFSeed A seed value for minimum CLF
  function testLTVCalculationFuzzing(
    uint256 liquiditySeed,
    uint256 volatilitySeed,
    uint256 capSeed,
    uint256 liquidationBonusSeed,
    uint256 minCLFSeed
  ) public {
    uint256 liquidity = bound(liquiditySeed, 1_000e18, 100_000_000e18); // 1k to 100M liquidity
    // 1 is 100%, 0.1 is 10%, 0.01 is 1%, 0.001 is 0.1%
    uint256 volatility = bound(volatilitySeed, 0.001e18, 10e18); // 0.1% to 1000% volatility
    uint256 cap = bound(capSeed, 1_000e18, 100_000_000e18); // 1k to 100M cap
    uint256 liquidationBonus = bound(liquidationBonusSeed, 0.01e18, 0.2e18); // 1% to 20% liquidation bonus
    uint256 minCLF = bound(minCLFSeed, 0.1e18, 5e18); // 0.1 to 5 CLF

    uint256 testLtv = computeLtv(liquidity, volatility, cap, minCLF, liquidationBonus);
    vm.assume(testLtv > 0);

    (RiskData memory data, uint8 v, bytes32 r, bytes32 s) = TestUtils.signDataValid(
      trustedRelayerPrivateKey,
      collateralAddress,
      debtAddress,
      pythia.RISKDATA_TYPEHASH(),
      pythia.DOMAIN_SEPARATOR(),
      liquidity,
      volatility,
      liquidationBonus
    );
    // Call the ltv function
    uint256 ltv = smartLTV.ltv(
      collateralAddress, // collateralAsset
      debtAddress, // debtAsset
      cap, // d = supply cap
      liquidationBonus, // beta = liquidation bonus
      minCLF, // minClf
      data,
      v,
      r,
      s
    );

    console.log("computed ltv: %s", ltv);
    assertEq(ltv, testLtv);
  }

  /// @notice Tests the LTV calculation function in the SmartLTV contract with exact values
  function testLTVCalculationExact() public {
    uint256 liquidity = 1_000_000e18; // 1M liquidity
    uint256 volatility = 0.10e18; // 10% volatility
    uint256 supplyCap = 200_000e18; // 200k supply cap
    uint256 liquidationBonus = 0.05e18; // 5% liquidation bonus
    uint256 minCLF = 3e18;

    (RiskData memory data, uint8 v, bytes32 r, bytes32 s) = TestUtils.signDataValid(
      trustedRelayerPrivateKey,
      collateralAddress,
      debtAddress,
      pythia.RISKDATA_TYPEHASH(),
      pythia.DOMAIN_SEPARATOR(),
      liquidity,
      volatility,
      liquidationBonus
    );
    // Call the ltv function
    uint256 ltv = smartLTV.ltv(
      collateralAddress, // collateralAsset
      debtAddress, // debtAsset
      supplyCap, // d = supply cap
      liquidationBonus, // beta = liquidation bonus
      minCLF, // minClf
      data,
      v,
      r,
      s
    );

    console.log("computed ltv: %s", ltv);
    // assertEq(ltv, 12);
    assertApproxEqAbs(ltv, 0.82444657e18, 0.00000001e18);
  }

  /// @notice Tests the LTV calculation function in the SmartLTV contract with risk data values
  ///         generating a case of max mantissa value that should returns a 0% LTV
  function testLTVCalculationMaxMantissa() public {
    uint256 liquidity = 10_000_000e18; // 10M liquidity
    uint256 cap = 10_000_000e18; // 10M cap
    uint256 volatility = 9.99e18; // 999% volatility
    uint256 minCLF = 4.9e18;
    uint256 liquidationBonus = 0.19e18; // 19% liquidation bonus

    (RiskData memory data, uint8 v, bytes32 r, bytes32 s) = TestUtils.signDataValid(
      trustedRelayerPrivateKey,
      collateralAddress,
      debtAddress,
      pythia.RISKDATA_TYPEHASH(),
      pythia.DOMAIN_SEPARATOR(),
      liquidity,
      volatility,
      liquidationBonus
    );
    // Call the ltv function
    uint256 ltv = smartLTV.ltv(
      collateralAddress, // collateralAsset
      debtAddress, // debtAsset
      cap, // d = supply cap
      liquidationBonus, // beta = liquidation bonus
      minCLF, // minClf
      data,
      v,
      r,
      s
    );

    console.log("computed ltv: %s", ltv);
    // assertEq(ltv, 12);
    assertEq(ltv, 0);
  }
}
