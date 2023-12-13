// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./MorphoFixture.sol";
import "../../src/external/Morpho.sol";
import "../TestUtils.sol";

contract IntegrationTestReallocateFlow is MorphoFixture {
  Id marketIdSDAI = Id.wrap(0x7a9e4757d1188de259ba5b47f4c08197f821e54109faa5b0502b9dfe2c10b741);
  Id marketIdUSDT = Id.wrap(0xbc6d1789e6ba66e5cd277af475c5ed77fcf8b084347809d9d92e400ebacbdd10);
  MarketParams marketParamSDAI;
  MarketParams marketParamUSDT;

  mapping(Id => int256) vaultSupplyChange;
  mapping(Id => int256) morphoMarketSupplyChange;

  function idToMarketParamsStruct(Id marketid) internal view returns (MarketParams memory) {
    (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv) = morpho.idToMarketParams(
      marketid
    );

    return MarketParams({loanToken: loanToken, collateralToken: collateralToken, oracle: oracle, irm: irm, lltv: lltv});
  }

  function computeMarketChange(Id marketId) internal {
    int256 currentChange = vaultSupplyChange[marketId];
    uint256 vaultSupply = getAssetSupplyForId(marketId);
    if (currentChange == 0) {
      vaultSupplyChange[marketId] = int256(vaultSupply);
    } else {
      vaultSupplyChange[marketId] = int256(vaultSupply) - currentChange;
    }

    int256 currentMorphoChange = morphoMarketSupplyChange[marketId];
    (uint128 totalSupplyAssets, , , , , ) = morpho.market(marketId);
    if (currentMorphoChange == 0) {
      morphoMarketSupplyChange[marketId] = int256(int128(totalSupplyAssets));
    } else {
      morphoMarketSupplyChange[marketId] = int256(int128(totalSupplyAssets)) - currentMorphoChange;
    }
  }

  function getAssetSupplyForId(Id marketId) internal view returns (uint256) {
    (uint128 totalSupplyAssets, uint128 totalSupplyShares, , , , ) = morpho.market(marketId);
    (uint256 supplyShare, , ) = morpho.position(marketId, address(metaMorpho));

    uint256 currentVaultMarketSupply = MorphoLib.toAssetsDown(supplyShare, totalSupplyAssets, totalSupplyShares);
    return currentVaultMarketSupply;
  }

  // used to log without needing to declare variable
  function logMetamorphoVaultSupply(Id marketId, string memory label) internal view {
    console2.log("%s %s", label, getAssetSupplyForId(marketId));
  }

  // used to log without needing to declare variable
  function logMorphoMarketSupply(Id marketId, string memory label) internal view {
    (uint128 totalSupplyAssets, , , , , ) = morpho.market(marketId);
    console2.log("%s %s", label, totalSupplyAssets);
  }

  function setUp() public override {
    super.setUp();

    marketParamSDAI = idToMarketParamsStruct(marketIdSDAI);
    marketParamUSDT = idToMarketParamsStruct(marketIdUSDT);
  }

  function testInitialization() public {
    assertTrue(metaMorpho.isAllocator(address(morphoAllocator)));
    assertNotEq(address(0), marketParamSDAI.collateralToken);
    assertNotEq(address(0), marketParamSDAI.loanToken);
    assertNotEq(address(0), marketParamUSDT.collateralToken);
    assertNotEq(address(0), marketParamUSDT.loanToken);
    assertNotEq(marketParamSDAI.collateralToken, marketParamUSDT.collateralToken);
  }

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
}
