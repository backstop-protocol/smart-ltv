// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../../../lib/forge-std/src/Test.sol";
import {Pythia} from "../../../src/core/Pythia.sol";

import {SmartLTV} from "../../../src/core/SmartLTV.sol";
import {RiskData} from "../../../src/interfaces/RiskData.sol";
import {ECDSA} from "../../../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "../../../lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {Math} from "../../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {RiskyMath} from "../../../src/lib/RiskyMath.sol";
import "../../mocks/MockMorpho.sol";
import "../../mocks/MockMetaMorpho.sol";
import "../../../src/external/Morpho.sol";
import "../../../src/morpho/BProtocolMorphoAllocator.sol";

contract BProtocolMorphoAllocatorTest is Test {
  SmartLTV public smartLTV;
  MockMorpho mockMorpho;
  MockMetaMorpho mockMetaMorpho;
  BProtocolMorphoAllocator morphoAllocator;

  uint256 trustedRelayerPrivateKey = 0x42;
  address trustedRelayerAddress = vm.addr(trustedRelayerPrivateKey);

  address collateralAddress = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address debtAddress = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

  MarketParams market1 =
    MarketParams({
      loanToken: address(1),
      collateralToken: address(2),
      oracle: address(3),
      irm: address(4),
      lltv: 0.90e18
    });

  MarketParams market2 =
    MarketParams({
      loanToken: address(1),
      collateralToken: address(20),
      oracle: address(3),
      irm: address(4),
      lltv: 0.50e18
    });

  // set morpho blue with 2 markets
  function setupMorphoMock() internal {
    mockMorpho = new MockMorpho();

    MarketInfo memory market1Info = MarketInfo({
      totalSupplyAssets: 1000e18,
      totalSupplyShares: 500e18,
      totalBorrowAssets: 250e18,
      totalBorrowShares: 125e18,
      lastUpdate: uint128(block.timestamp),
      fee: 0
    });
    mockMorpho.setMarketInfo(MorphoLib.id(market1), market1Info);

    MarketInfo memory market2Info = MarketInfo({
      totalSupplyAssets: 5000e18,
      totalSupplyShares: 2500e18,
      totalBorrowAssets: 4000e18,
      totalBorrowShares: 2000e18,
      lastUpdate: uint128(block.timestamp),
      fee: 0
    });

    mockMorpho.setMarketInfo(MorphoLib.id(market2), market2Info);
  }

  function setupMetaMorphoMock(IMorpho morpho) internal {
    mockMetaMorpho = new MockMetaMorpho(morpho);

    ConfigData memory configDataMarket1 = ConfigData({cap: 1_000_000e18, enabled: true, removableAt: 0});
    mockMetaMorpho.setConfig(MorphoLib.id(market1), configDataMarket1);
    ConfigData memory configDataMarket2 = ConfigData({cap: 10_000e18, enabled: true, removableAt: 0});
    mockMetaMorpho.setConfig(MorphoLib.id(market2), configDataMarket2);
  }

  function setUp() public {
    smartLTV = new SmartLTV(new Pythia(), trustedRelayerAddress);
    setupMorphoMock();
    setupMetaMorphoMock(IMorpho(mockMorpho));
    morphoAllocator = new BProtocolMorphoAllocator(smartLTV, address(mockMetaMorpho));

    // warp to a known block and timestamp
    vm.warp(1679067867);
    vm.roll(16848497);
  }

  function testInitialization() public {
    assertEq(address(morphoAllocator.SMART_LTV()), address(smartLTV));
    assertEq(address(morphoAllocator.METAMORPHO_VAULT()), address(mockMetaMorpho));
  }
}
