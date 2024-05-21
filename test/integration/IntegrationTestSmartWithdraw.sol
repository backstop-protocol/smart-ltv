// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {SmartWithdraw} from "../../src/morpho/SmartWithdraw.sol";
import {SmartLTV} from "../../src/core/SmartLTV.sol";
import {TestUtils} from "../TestUtils.sol";
import {RiskData, SignedRiskData} from "../../src/interfaces/RiskData.sol";
import {Pythia} from "../../src/core/Pythia.sol";
import {SmartLTV} from "../../src/core/SmartLTV.sol";
import {IMetaMorpho} from "../../lib/metamorpho/src/interfaces/IMetaMorpho.sol";
import "../../src/lib/ErrorLib.sol";

contract IntegrationTestSmartWithdraw is Test {
  SmartWithdraw public smartWithdraw;
  Pythia public pythia;
  SmartLTV public smartLTV;
  address public ETH_VAULT = 0x38989BBA00BDF8181F4082995b3DEAe96163aC5D;
  uint256 public wstETH_945_MarketIndex = 1;
  address public wstETHAddress = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
  address public WETHAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  address public ETH_VAULT_OWNER;
  address allocator = address(0x01010101010101);
  address notAllocator = address(0x02020202020202);

  uint256 trustedRelayerPrivateKey = 0x42;
  address trustedRelayerAddress = vm.addr(trustedRelayerPrivateKey);

  function setUp() public {
    pythia = new Pythia();
    smartLTV = new SmartLTV(pythia, trustedRelayerAddress);
    smartWithdraw = new SmartWithdraw(address(smartLTV));
    ETH_VAULT_OWNER = IMetaMorpho(ETH_VAULT).owner();
    vm.startPrank(ETH_VAULT_OWNER);
    IMetaMorpho(ETH_VAULT).setIsAllocator(allocator, true);
    IMetaMorpho(ETH_VAULT).setIsAllocator(address(smartWithdraw), true);
    vm.stopPrank();
  }

  function testCheckMarketEthVault() public {
    SmartWithdraw smartWithdrawProd = SmartWithdraw(0xCf48A240FB83861e729C65A5234598A16d045d99);
    SignedRiskData memory signedRiskData = SignedRiskData({
      riskData: RiskData({
        collateralAsset: 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0,
        debtAsset: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
        liquidity: 31077977373809277000000,
        volatility: 55280587205341895,
        liquidationBonus: 15000000000000000,
        lastUpdate: 1715781245,
        chainId: 1
      }),
      v: 28,
      r: 0xa7ba75d40041b027d8e4da5df64032b6c2c8fb255f6adbf505372f048fee360a,
      s: 0x2ab0789899029a58d357a8c87f27f9e02e7c8b4005e50407bab116bb0953ccff
    });

    (bool shouldWithdraw, uint256 recommendedLTV) = smartWithdrawProd.keeperCheck(
      ETH_VAULT,
      wstETH_945_MarketIndex,
      signedRiskData
    );
    assertFalse(shouldWithdraw);
    console.log("recommended ltv %s", TestUtils.toPercentageString(recommendedLTV));
  }

  // this test should fail because the minimum risk level is not set for the vault
  function testCheckWithdrawRealDataShouldRevertIfNoMinRisk() public {
    // these risk parameters should make the smartLTV returns 0% LTV
    uint256 liquidity = 44683720303239184000000;
    uint256 volatility = 55960824025022340;

    (RiskData memory data, uint8 v, bytes32 r, bytes32 s) = TestUtils.signDataValid(
      trustedRelayerPrivateKey,
      wstETHAddress,
      WETHAddress,
      pythia.RISKDATA_TYPEHASH(),
      pythia.DOMAIN_SEPARATOR(),
      liquidity,
      volatility,
      0.005e18 // 0.5% liquidation bonus
    );

    SignedRiskData memory signedRiskData = SignedRiskData({riskData: data, v: v, r: r, s: s});

    vm.expectRevert();
    smartWithdraw.keeperCheck(ETH_VAULT, wstETH_945_MarketIndex, signedRiskData);
    // assertFalse(shouldWithdraw);
    // console.log("recommended ltv %s", TestUtils.toPercentageString(recommendedLTV));
  }

  // this test should pass because the risk level is low compared to the maximum risk level set by the allocator
  function testCheckWithdrawRealData() public {
    vm.prank(allocator);
    smartWithdraw.setVaultMaxRiskLevel(ETH_VAULT, 20e18);
    // these risk parameters should make the smartLTV returns 0% LTV
    uint256 liquidity = 44683720303239184000000;
    uint256 volatility = 55960824025022340;

    (RiskData memory data, uint8 v, bytes32 r, bytes32 s) = TestUtils.signDataValid(
      trustedRelayerPrivateKey,
      wstETHAddress,
      WETHAddress,
      pythia.RISKDATA_TYPEHASH(),
      pythia.DOMAIN_SEPARATOR(),
      liquidity,
      volatility,
      0.005e18 // 0.5% liquidation bonus
    );

    SignedRiskData memory signedRiskData = SignedRiskData({riskData: data, v: v, r: r, s: s});

    (bool shouldWithdraw, uint256 recommendedLTV) = smartWithdraw.keeperCheck(
      ETH_VAULT,
      wstETH_945_MarketIndex,
      signedRiskData
    );
    assertFalse(shouldWithdraw);
    console.log("recommended ltv %s", TestUtils.toPercentageString(recommendedLTV));
  }

  // this test should fail because the risk level is too high compared to the maximum risk level set by the allocator
  function testCheckWithdrawDataTooRisky() public {
    vm.prank(allocator);
    smartWithdraw.setVaultMaxRiskLevel(ETH_VAULT, 20e18);
    // these risk parameters should make the smartLTV returns 0% LTV
    uint256 liquidity = 1000e18; // low liquidity
    uint256 volatility = 1e18; // 100% volatility

    (RiskData memory data, uint8 v, bytes32 r, bytes32 s) = TestUtils.signDataValid(
      trustedRelayerPrivateKey,
      wstETHAddress,
      WETHAddress,
      pythia.RISKDATA_TYPEHASH(),
      pythia.DOMAIN_SEPARATOR(),
      liquidity,
      volatility,
      0.005e18 // 0.5% liquidation bonus
    );

    SignedRiskData memory signedRiskData = SignedRiskData({riskData: data, v: v, r: r, s: s});

    (bool shouldWithdraw, uint256 recommendedLTV) = smartWithdraw.keeperCheck(
      ETH_VAULT,
      wstETH_945_MarketIndex,
      signedRiskData
    );
    assertTrue(shouldWithdraw);
    console.log("recommended ltv %s", TestUtils.toPercentageString(recommendedLTV));
  }

  // this test should fail because the available liquidity is too low compared to the minimum liquidity to withdraw
  // set by the allocator for this vault
  function testCheckWithdrawDataTooRiskyButAvailableLiquidityTooLow() public {
    vm.prank(allocator);
    smartWithdraw.setVaultMaxRiskLevel(ETH_VAULT, 20e18);
    vm.prank(allocator);
    smartWithdraw.setVaultMinLiquidityToWithdraw(ETH_VAULT, 1_000_000e18);
    // these risk parameters should make the smartLTV returns 0% LTV
    uint256 liquidity = 1000e18; // low liquidity
    uint256 volatility = 1e18; // 100% volatility

    (RiskData memory data, uint8 v, bytes32 r, bytes32 s) = TestUtils.signDataValid(
      trustedRelayerPrivateKey,
      wstETHAddress,
      WETHAddress,
      pythia.RISKDATA_TYPEHASH(),
      pythia.DOMAIN_SEPARATOR(),
      liquidity,
      volatility,
      0.005e18 // 0.5% liquidation bonus
    );

    SignedRiskData memory signedRiskData = SignedRiskData({riskData: data, v: v, r: r, s: s});

    (bool shouldWithdraw, uint256 recommendedLTV) = smartWithdraw.keeperCheck(
      ETH_VAULT,
      wstETH_945_MarketIndex,
      signedRiskData
    );
    assertFalse(shouldWithdraw);
    console.log("recommended ltv %s", TestUtils.toPercentageString(recommendedLTV));
  }
}
