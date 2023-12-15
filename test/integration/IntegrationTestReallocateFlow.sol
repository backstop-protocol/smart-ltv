// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./MorphoFixture.sol";
import "../TestUtils.sol";
import "../../lib/metamorpho/lib/morpho-blue/src/libraries/MathLib.sol";
import {SharesMathLib} from "../../lib/metamorpho/lib/morpho-blue/src/libraries/SharesMathLib.sol";
import {Position} from "../../lib/metamorpho/lib/morpho-blue/src/interfaces/IMorpho.sol";

/// @title Integration Test for Reallocate Flow in Morpho Protocol
/// @notice This contract tests the reallocation flow in the Morpho protocol, focusing on markets for SDAI, USDT, and IDLE.
/// @dev Inherits from MorphoFixture to leverage common testing setup and utilities.
/// @dev You need to fork goerli for these tests to work (set env variable GOERLI_RPC_URL)
contract IntegrationTestReallocateFlow is MorphoFixture {
  MarketParams marketParamSDAI;
  MarketParams marketParamUSDT;
  MarketParams marketParamIdle;

  /// Mapping to track changes in vault supply for each market. Used for assertions
  mapping(Id => int256) vaultSupplyChange;
  /// Mapping to track changes in Morpho market supply for each market. Used for assertions
  mapping(Id => int256) morphoMarketSupplyChange;

  /// @notice Computes and records the change in supply for a specified market.
  /// @dev Calculates changes in vault supply and Morpho market supply.
  /// @param marketId The market ID for which to compute supply changes.
  function computeMarketChange(Id marketId) internal {
    int256 currentChange = vaultSupplyChange[marketId];
    uint256 vaultSupply = getAssetSupplyForId(marketId);
    if (currentChange == 0) {
      vaultSupplyChange[marketId] = int256(vaultSupply);
    } else {
      vaultSupplyChange[marketId] = int256(vaultSupply) - currentChange;
    }

    int256 currentMorphoChange = morphoMarketSupplyChange[marketId];
    Market memory m = morpho.market(marketId);
    if (currentMorphoChange == 0) {
      morphoMarketSupplyChange[marketId] = int256(int128(m.totalSupplyAssets));
    } else {
      morphoMarketSupplyChange[marketId] = int256(int128(m.totalSupplyAssets)) - currentMorphoChange;
    }
  }

  /// @notice Retrieves the current asset supply for a given market ID.
  /// @dev Calculates asset supply based on the total supply shares and positions.
  /// @param marketId The market ID to query.
  /// @return The current asset supply for the specified market.
  function getAssetSupplyForId(Id marketId) internal view returns (uint256) {
    Market memory m = morpho.market(marketId);
    Position memory p = morpho.position(marketId, address(metaMorpho));

    uint256 currentVaultMarketSupply = SharesMathLib.toAssetsDown(
      p.supplyShares,
      m.totalSupplyAssets,
      m.totalSupplyShares
    );
    return currentVaultMarketSupply;
  }

  /// @notice Logs the current supply of assets in the Metamorpho vault for a specified market.
  /// @dev Utility function for logging supply values during testing.
  /// @param marketId The market ID to log.
  /// @param label A label for the log entry.
  function logMetamorphoVaultSupply(Id marketId, string memory label) internal view {
    console2.log("%s %e", label, getAssetSupplyForId(marketId));
  }

  /// @notice Logs the current supply of assets in the Morpho market for a specified market.
  /// @dev Utility function for logging supply values during testing.
  /// @param marketId The market ID to log.
  /// @param label A label for the log entry.
  function logMorphoMarketSupply(Id marketId, string memory label) internal view {
    Market memory m = morpho.market(marketId);
    console2.log("%s %e", label, m.totalSupplyAssets);
  }

  /// @notice Sets up the test environment.
  /// @dev Initializes market parameters for SDAI, USDT, and IDLE markets.
  function setUp() public override {
    super.setUp();

    marketParamSDAI = morpho.idToMarketParams(marketIdSDAI);
    marketParamUSDT = morpho.idToMarketParams(marketIdUSDT);
    marketParamIdle = morpho.idToMarketParams(marketIdIdle);
  }

  /// @notice Tests the initialization of the contract and market parameters.
  /// @dev Asserts the correct setup of allocator, market parameters, and non-zero addresses.
  function testInitialization() public {
    assertTrue(metaMorpho.isAllocator(address(morphoAllocator)));
    assertNotEq(address(0), marketParamSDAI.collateralToken);
    assertNotEq(address(0), marketParamSDAI.loanToken);
    assertNotEq(address(0), marketParamUSDT.collateralToken);
    assertNotEq(address(0), marketParamUSDT.loanToken);
    assertNotEq(marketParamSDAI.collateralToken, marketParamUSDT.collateralToken);
    assertEq(address(0), marketParamIdle.collateralToken);
  }

  /// @notice Tests the reallocation process for the USDT market.
  /// @dev Simulates rebalancing between SDAI and USDT markets and checks supply changes.
  function testReallocateToMarketUSDT() public {
    // get and log morpho blue markets
    computeMarketChange(marketIdSDAI);
    computeMarketChange(marketIdUSDT);

    // get the number of asset in the sdai market
    uint256 sDaiSupplyBefore = getAssetSupplyForId(marketIdSDAI);
    console2.log("sDAI supply before: %s", sDaiSupplyBefore);

    // get the number of assets in the usdt market
    logMetamorphoVaultSupply(marketIdUSDT, "USDT supply before:");

    // rebalance to withdraw from sdai market
    // to do that we need to create 2 allocations (and the same amount of risk data and signature)
    MarketAllocation[] memory allocations = new MarketAllocation[](2);
    RiskData[] memory riskDatas = new RiskData[](2);
    Signature[] memory signatures = new Signature[](2);

    // divide the current sdai allocation by a factor of 2 to 100
    // first allocation is the withdraw from the sdai parameter
    uint256 targetSdaiSupply = sDaiSupplyBefore / 2;
    console2.log("targetSdaiSupply: %s", targetSdaiSupply);
    allocations[0] = MarketAllocation({marketParams: marketParamSDAI, assets: targetSdaiSupply});
    // second allocation is the supply to the usdt market
    uint256 targetUsdtSupply = type(uint256).max;
    console2.log("targetUsdtSupply: %s", targetUsdtSupply);
    allocations[1] = MarketAllocation({marketParams: marketParamUSDT, assets: targetUsdtSupply});
    // the risk data for the first allocation is useless because it's a withdraw
    riskDatas[0] = RiskData({
      collateralAsset: address(1), // Example address
      debtAsset: address(2), // Example address
      liquidity: 1000, // Example value
      volatility: 500, // Example value
      lastUpdate: block.timestamp, // Current block timestamp
      chainId: block.chainid // Current chain ID
    });

    // the risk data for the second allocation need to be correct
    // these risk parameters should make the smartLTV returns a valid ltv
    uint256 liquidity = 10_000_000_000e18; // big liquidity
    uint256 volatility = 0.01e18; // low volatility

    (RiskData memory data, uint8 v, bytes32 r, bytes32 s) = TestUtils.signDataValid(
      trustedRelayerPrivateKey,
      marketParamUSDT.collateralToken,
      marketParamUSDT.loanToken,
      pythia.RISKDATA_TYPEHASH(),
      pythia.DOMAIN_SEPARATOR(),
      liquidity,
      volatility
    );

    riskDatas[1] = data;

    signatures[0] = Signature({
      v: uint8(27), // Example value
      r: bytes32(0), // Example value
      s: bytes32(0) // Example value
    });

    signatures[1] = Signature({v: v, r: r, s: s});

    vm.prank(allocatorOwner);
    morphoAllocator.checkAndReallocate(allocations, riskDatas, signatures);

    computeMarketChange(marketIdSDAI);
    computeMarketChange(marketIdUSDT);

    // get the number of asset in the sdai market
    logMetamorphoVaultSupply(marketIdSDAI, "sDAI supply after:");
    logMetamorphoVaultSupply(marketIdUSDT, "USDT supply after:");

    // the vault supply change for the sDAI market should be negative
    assertLt(vaultSupplyChange[marketIdSDAI], 0);
    // same for the global morpho blue market
    assertLt(morphoMarketSupplyChange[marketIdSDAI], 0);
    console2.log("sDAI vault supply change: %s", vaultSupplyChange[marketIdSDAI]);
    console2.log("sDAI market supply change: %s", morphoMarketSupplyChange[marketIdSDAI]);

    // while the USDT market should have increased
    assertGt(vaultSupplyChange[marketIdUSDT], 0);
    assertGt(morphoMarketSupplyChange[marketIdUSDT], 0);
    console2.log("USDT vault supply change: %s", vaultSupplyChange[marketIdUSDT]);
    console2.log("USDT market supply change: %s", morphoMarketSupplyChange[marketIdUSDT]);
  }

  /// @notice Tests reallocating all assets to the IDLE market.
  /// @dev Withdraws from SDAI and USDT markets and reallocates to the IDLE market, asserting expected supply changes.
  function testReallocateAllToIdle() public {
    // get and log morpho blue markets
    computeMarketChange(marketIdSDAI);
    computeMarketChange(marketIdUSDT);
    computeMarketChange(marketIdIdle);

    logMetamorphoVaultSupply(marketIdSDAI, "sDAI vault supply before:");
    logMetamorphoVaultSupply(marketIdUSDT, "USDT vault supply before:");
    logMetamorphoVaultSupply(marketIdIdle, "IDLE vault supply before:");
    logMorphoMarketSupply(marketIdSDAI, "sDAI market supply before:");
    logMorphoMarketSupply(marketIdUSDT, "USDT market supply before:");
    logMorphoMarketSupply(marketIdIdle, "IDLE market supply before:");

    // withdraw from sDAI and USDT markets and put all to idle
    // to do that we need to create 3 allocations (and the same amount of risk data and signature)
    MarketAllocation[] memory allocations = new MarketAllocation[](3);
    RiskData[] memory riskDatas = new RiskData[](3);
    Signature[] memory signatures = new Signature[](3);

    // first allocation is the withdraw from the sdai market
    allocations[0] = MarketAllocation({marketParams: marketParamSDAI, assets: 0});
    // second allocation is the withdraw from the usdt market
    allocations[1] = MarketAllocation({marketParams: marketParamUSDT, assets: 0});

    console.log("idle market collateral %s", marketParamIdle.collateralToken);
    // third allocation is the supply to the idle market
    allocations[2] = MarketAllocation({marketParams: marketParamIdle, assets: type(uint256).max});
    // all risk data are useless because only withdraw or supply to idle market
    riskDatas[0] = RiskData({
      collateralAsset: address(1), // Example address
      debtAsset: address(2), // Example address
      liquidity: 1000, // Example value
      volatility: 500, // Example value
      lastUpdate: block.timestamp, // Current block timestamp
      chainId: block.chainid // Current chain ID
    });
    riskDatas[1] = riskDatas[0];
    riskDatas[2] = riskDatas[0];
    // same for signature
    signatures[0] = Signature({
      v: uint8(27), // Example value
      r: bytes32(0), // Example value
      s: bytes32(0) // Example value
    });

    signatures[1] = signatures[0];
    signatures[2] = signatures[0];

    vm.prank(allocatorOwner);
    morphoAllocator.checkAndReallocate(allocations, riskDatas, signatures);

    computeMarketChange(marketIdSDAI);
    computeMarketChange(marketIdUSDT);
    computeMarketChange(marketIdIdle);

    logMetamorphoVaultSupply(marketIdSDAI, "sDAI vault supply after:");
    logMetamorphoVaultSupply(marketIdUSDT, "USDT vault supply after:");
    logMetamorphoVaultSupply(marketIdIdle, "IDLE vault supply after:");
    logMorphoMarketSupply(marketIdSDAI, "sDAI market supply after:");
    logMorphoMarketSupply(marketIdUSDT, "USDT market supply after:");
    logMorphoMarketSupply(marketIdIdle, "IDLE market supply after:");

    // the vault supply change for the sDAI market should be negative
    assertTrue(vaultSupplyChange[marketIdSDAI] <= 0);
    // same for the global morpho blue market
    assertTrue(morphoMarketSupplyChange[marketIdSDAI] <= 0);
    console2.log("sDAI vault supply change: %s", vaultSupplyChange[marketIdSDAI]);
    console2.log("sDAI market supply change: %s", morphoMarketSupplyChange[marketIdSDAI]);

    // same for usdt
    assertTrue(vaultSupplyChange[marketIdUSDT] <= 0);
    assertTrue(morphoMarketSupplyChange[marketIdUSDT] <= 0);
    console2.log("USDT vault supply change: %s", vaultSupplyChange[marketIdUSDT]);
    console2.log("USDT market supply change: %s", morphoMarketSupplyChange[marketIdUSDT]);

    // idle market should have increased
    assertGt(vaultSupplyChange[marketIdIdle], 0);
    assertGt(morphoMarketSupplyChange[marketIdIdle], 0);
    console2.log("IDLE vault supply change: %s", vaultSupplyChange[marketIdIdle]);
    console2.log("IDLE market supply change: %s", morphoMarketSupplyChange[marketIdIdle]);
  }
}
