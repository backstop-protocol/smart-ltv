// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {SmartWithdraw} from "../../src/morpho/SmartWithdraw.sol";
import {MockMorpho} from "../mocks/MockMorpho.sol";
import {MockMetaMorpho} from "../mocks/MockMetaMorpho.sol";
import {SmartLTV} from "../../src/core/SmartLTV.sol";
import {TestUtils} from "../TestUtils.sol";
import {RiskData, SignedRiskData} from "../../src/interfaces/RiskData.sol";
import {Pythia} from "../../src/core/Pythia.sol";
import {SmartLTV} from "../../src/core/SmartLTV.sol";

contract IntegrationTestSmartWithdraw is Test {
  SmartWithdraw public smartWithdraw;
  Pythia public pythia;
  SmartLTV public smartLTV;
  address public ETH_VAULT = 0x38989BBA00BDF8181F4082995b3DEAe96163aC5D;
  uint256 public wstETH_945_MarketIndex = 1;
  address public wstETHAddress = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
  address public WETHAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  uint256 trustedRelayerPrivateKey = 0x42;
  address trustedRelayerAddress = vm.addr(trustedRelayerPrivateKey);

  function setUp() public {
    pythia = new Pythia();
    smartLTV = new SmartLTV(pythia, trustedRelayerAddress);
    smartWithdraw = new SmartWithdraw(address(smartLTV));
  }

  function testCheckWithdrawRealData() public {
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
}
