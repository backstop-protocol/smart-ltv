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

  function idToMarketParamsStruct(Id marketid) internal view returns (MarketParams memory) {
    (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv) = morpho.idToMarketParams(
      marketid
    );

    return MarketParams({loanToken: loanToken, collateralToken: collateralToken, oracle: oracle, irm: irm, lltv: lltv});
  }

  function getAssetSupplyForId(Id marketId) internal view returns (uint256) {
    (uint128 totalSupplyAssets, uint128 totalSupplyShares, , , , ) = morpho.market(marketId);
    (uint256 supplyShare, , ) = morpho.position(marketId, address(metaMorpho));

    uint256 currentVaultMarketSupply = MorphoLib.toAssetsDown(supplyShare, totalSupplyAssets, totalSupplyShares);
    return currentVaultMarketSupply;
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
    // get the total number of asset of our vault
    uint256 vaultTotalAssets = metaMorpho.totalAssets();
    console.log("vault total assets: %s", vaultTotalAssets);
    // get the number of asset in the sdai market
    uint256 sDaiSupplyBefore = getAssetSupplyForId(marketIdSDAI);
    console.log("sDaiSupplyBefore: %s", sDaiSupplyBefore);

    // get the number of assets in the usdt market
    uint256 usdtSupplyBefore = getAssetSupplyForId(marketIdUSDT);
    console.log("usdtSupplyBefore: %s", usdtSupplyBefore);

    // rebalance to withdraw from sdai market
    // to do that we need to create 2 allocations (and the same amount of risk data and signature)
    MarketAllocation[] memory allocations = new MarketAllocation[](2);
    RiskData[] memory riskDatas = new RiskData[](2);
    Signature[] memory signatures = new Signature[](2);

    // first allocation is the withdraw from the sdai parameter
    // here we want to divide by 2 the current supply
    uint256 targetSdaiSupply = sDaiSupplyBefore / 2;
    console.log("targetSdaiSupply: %s", targetSdaiSupply);
    allocations[0] = MarketAllocation({marketParams: marketParamSDAI, assets: targetSdaiSupply});
    // second allocation is the supply to the usdt market
    uint256 targetUsdtSupply = 1000e6; // 1000 USDC supply
    console.log("targetUsdtSupply: %s", targetUsdtSupply);
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
  }
}
