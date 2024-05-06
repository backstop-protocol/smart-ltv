// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../../../lib/forge-std/src/Test.sol";
import {Pythia} from "../../../src/core/Pythia.sol";
import {SmartLTV} from "../../../src/core/SmartLTV.sol";
import {RiskData, SignedRiskData} from "../../../src/interfaces/RiskData.sol";
import {MessageHashUtils} from "../../../lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import "../../../src/lib/ErrorLib.sol";
import {MockMorpho} from "../../mocks/MockMorpho.sol";
import {MockMetaMorpho} from "../../mocks/MockMetaMorpho.sol";
import "../../../lib/metamorpho/src/interfaces/IMetaMorpho.sol";
import {MarketParamsLib} from "../../../lib/metamorpho/lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import {Market, Position} from "../../../lib/metamorpho/lib/morpho-blue/src/interfaces/IMorpho.sol";
import {BProtocolMorphoAllocator, Ownable} from "../../../src/morpho/BProtocolMorphoAllocator.sol";
import "../../TestUtils.sol";
import {SmartWithdraw} from "../../../src/morpho/SmartWithdraw.sol";

contract SmartWithdrawTest is Test {
  Pythia public pythia;
  SmartLTV public smartLTV;
  MockMorpho public mockMorpho;
  MockMetaMorpho public mockMetaMorpho;
  SmartWithdraw public smartWithdraw;

  address oracleAddress = address(10);
  address irmAddress = address(11);

  uint256 trustedRelayerPrivateKey = 0x42;
  address trustedRelayerAddress = vm.addr(trustedRelayerPrivateKey);

  address collateralAddress1 = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address collateralAddress2 = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
  address debtAddress = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
  address allocatorOwner = address(101);

  MarketParams market1 =
    MarketParams({
      loanToken: debtAddress,
      collateralToken: collateralAddress1,
      oracle: oracleAddress,
      irm: irmAddress,
      lltv: 0.90e18
    });

  MarketParams market2 =
    MarketParams({
      loanToken: debtAddress,
      collateralToken: collateralAddress2,
      oracle: oracleAddress,
      irm: irmAddress,
      lltv: 0.1e18
    });

  MarketParams marketIdle =
    MarketParams({loanToken: debtAddress, collateralToken: address(0), oracle: address(0), irm: address(0), lltv: 0});

  // set morpho blue with 2 markets
  function setupMorphoMock() internal {
    mockMorpho = new MockMorpho();

    Market memory market1Info = Market({
      totalSupplyAssets: 1000e18,
      totalSupplyShares: 500e18,
      totalBorrowAssets: 250e18,
      totalBorrowShares: 125e18,
      lastUpdate: uint128(block.timestamp),
      fee: 0
    });
    mockMorpho.setMarketInfo(MarketParamsLib.id(market1), market1Info);

    Market memory market2Info = Market({
      totalSupplyAssets: 5000e18,
      totalSupplyShares: 2500e18,
      totalBorrowAssets: 4000e18,
      totalBorrowShares: 2000e18,
      lastUpdate: uint128(block.timestamp),
      fee: 0
    });

    mockMorpho.setMarketInfo(MarketParamsLib.id(market2), market2Info);

    Market memory marketIdleInfo = Market({
      totalSupplyAssets: 0,
      totalSupplyShares: 0,
      totalBorrowAssets: 0,
      totalBorrowShares: 0,
      lastUpdate: uint128(block.timestamp),
      fee: 0
    });

    mockMorpho.setMarketInfo(MarketParamsLib.id(marketIdle), marketIdleInfo);
    mockMorpho.setMarketParams(MarketParamsLib.id(market1), market1);
    mockMorpho.setMarketParams(MarketParamsLib.id(market2), market2);
    mockMorpho.setMarketParams(MarketParamsLib.id(marketIdle), marketIdle);
  }

  function setupMetaMorphoMock(IMorpho morpho) internal {
    mockMetaMorpho = new MockMetaMorpho(morpho);

    MarketConfig memory configDataMarket1 = MarketConfig({cap: 1_000_000e18, enabled: true, removableAt: 0});
    mockMetaMorpho.setConfig(MarketParamsLib.id(market1), configDataMarket1);
    MarketConfig memory configDataMarket2 = MarketConfig({cap: 10_000e18, enabled: true, removableAt: 0});
    mockMetaMorpho.setConfig(MarketParamsLib.id(market2), configDataMarket2);
    MarketConfig memory configDataMarketIdle = MarketConfig({cap: 0, enabled: true, removableAt: 0});
    mockMetaMorpho.setConfig(MarketParamsLib.id(marketIdle), configDataMarketIdle);

    Id[] memory marketIds = new Id[](3);
    marketIds[0] = MarketParamsLib.id(market1);
    marketIds[1] = MarketParamsLib.id(market2);
    marketIds[2] = MarketParamsLib.id(marketIdle);
    mockMetaMorpho.setMarkets(marketIds);
  }

  /// @notice Sets up the testing environment with necessary contract instances and configurations
  function setUp() public {
    pythia = new Pythia();
    smartLTV = new SmartLTV(pythia, trustedRelayerAddress);
    setupMorphoMock();
    setupMetaMorphoMock(IMorpho(mockMorpho));
    smartWithdraw = new SmartWithdraw(address(smartLTV));

    // warp to a known block and timestamp
    // this is needed because we sign data with a timestamp using block.timestamp - 3600
    vm.warp(1679067867);
    vm.roll(16848497);
  }

  /// @notice Tests the initialization of the SmartWithdraw contract and the setup of the MetaMorpho mock.
  /// @dev Asserts the correct initialization of the SmartLTV address in SmartWithdraw and the correct ordering of markets in the MetaMorpho mock's withdraw queue.
  function testInitialization() public {
    assertEq(address(smartWithdraw.SMART_LTV()), address(smartLTV));
    assertEq(Id.unwrap(mockMetaMorpho.withdrawQueue(0)), Id.unwrap(MarketParamsLib.id(market1)));
    assertEq(Id.unwrap(mockMetaMorpho.withdrawQueue(1)), Id.unwrap(MarketParamsLib.id(market2)));
    assertEq(Id.unwrap(mockMetaMorpho.withdrawQueue(2)), Id.unwrap(MarketParamsLib.id(marketIdle)));
  }

  /// @notice Tests the withdrawal recommendation for a market with high risk parameters.
  /// @dev This test simulates a scenario with low liquidity and high volatility to check if the SmartWithdraw contract recommends withdrawal.
  function testCheckWithdrawRiskyMarket() public {
    // these risk parameters should make the smartLTV returns 0% LTV
    uint256 liquidity = 0.1e18; // low liquidity
    uint256 volatility = 100_000e18; // big volatility

    (RiskData memory data, uint8 v, bytes32 r, bytes32 s) = TestUtils.signDataValid(
      trustedRelayerPrivateKey,
      market2.collateralToken,
      market2.loanToken,
      pythia.RISKDATA_TYPEHASH(),
      pythia.DOMAIN_SEPARATOR(),
      liquidity,
      volatility
    );

    uint256 market2Index = 1;

    SignedRiskData memory signedRiskData = SignedRiskData({riskData: data, v: v, r: r, s: s});

    (bool shouldWithdraw, uint256 recommendedLTV) = smartWithdraw.keeperCheck(
      address(mockMetaMorpho),
      20e18,
      market2Index,
      signedRiskData
    );
    assertTrue(shouldWithdraw);
    console.log("recommended ltv %s", TestUtils.toPercentageString(recommendedLTV));
  }

  /// @notice Tests the withdrawal check for a market with high liquidity and low volatility.
  /// @dev This test simulates a scenario where the market conditions are healthy (high liquidity, low volatility),
  ///      and verifies that the SmartWithdraw contract recommends not to withdraw.
  function testCheckWithdrawHealthyMarket() public {
    // Set high liquidity and low volatility to simulate a healthy market condition
    uint256 liquidity = 1_000_000_000e18; // high liquidity
    uint256 volatility = 0.01e18; // low volatility

    // Sign the risk data with the given parameters
    (RiskData memory data, uint8 v, bytes32 r, bytes32 s) = TestUtils.signDataValid(
      trustedRelayerPrivateKey,
      market1.collateralToken,
      market1.loanToken,
      pythia.RISKDATA_TYPEHASH(),
      pythia.DOMAIN_SEPARATOR(),
      liquidity,
      volatility
    );

    // Index of the market to check
    uint256 marketIndex = 0;

    // Create a signed risk data structure
    SignedRiskData memory signedRiskData = SignedRiskData({riskData: data, v: v, r: r, s: s});

    // Perform the keeper check to determine if withdrawal is recommended
    (bool shouldWithdraw, uint256 recommendedLTV) = smartWithdraw.keeperCheck(
      address(mockMetaMorpho),
      20e18,
      marketIndex,
      signedRiskData
    );

    // Assert that withdrawal should not occur in a healthy market
    assertFalse(shouldWithdraw);
    console.log("recommended ltv %s", TestUtils.toPercentageString(recommendedLTV));
  }
}
