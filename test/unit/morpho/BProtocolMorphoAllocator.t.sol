// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../../../lib/forge-std/src/Test.sol";
import {Pythia} from "../../../src/core/Pythia.sol";
import {SmartLTV} from "../../../src/core/SmartLTV.sol";
import {RiskData} from "../../../src/interfaces/RiskData.sol";
import {MessageHashUtils} from "../../../lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import "../../../src/lib/ErrorLib.sol";
import "../../mocks/MockMorpho.sol";
import "../../mocks/MockMetaMorpho.sol";
import "../../../src/external/Morpho.sol";
import "../../../src/morpho/BProtocolMorphoAllocator.sol";
import "../../TestUtils.sol";

/// @title Testing BProtocolMorphoAllocator Contract for Market reallocation with Risk Management
contract BProtocolMorphoAllocatorTest is Test {
  Pythia public pythia;
  SmartLTV public smartLTV;
  MockMorpho mockMorpho;
  MockMetaMorpho mockMetaMorpho;
  BProtocolMorphoAllocator morphoAllocator;

  address oracleAddress = address(10);
  address irmAddress = address(11);

  uint256 trustedRelayerPrivateKey = 0x42;
  address trustedRelayerAddress = vm.addr(trustedRelayerPrivateKey);

  address collateralAddress1 = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  address collateralAddress2 = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
  address debtAddress = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

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

  /// @notice Sets up the testing environment with necessary contract instances and configurations
  function setUp() public {
    pythia = new Pythia();
    smartLTV = new SmartLTV(pythia, trustedRelayerAddress);
    setupMorphoMock();
    setupMetaMorphoMock(IMorpho(mockMorpho));
    morphoAllocator = new BProtocolMorphoAllocator(smartLTV, address(mockMetaMorpho));

    // warp to a known block and timestamp
    vm.warp(1679067867);
    vm.roll(16848497);
  }

  /// @notice Tests the correct initialization of the BProtocolMorphoAllocator contract and its dependencies
  function testInitialization() public {
    assertEq(address(morphoAllocator.SMART_LTV()), address(smartLTV));
    assertEq(address(morphoAllocator.METAMORPHO_VAULT()), address(mockMetaMorpho));
    assertGt(morphoAllocator.MIN_CLF(), uint256(0));
  }

  /// @notice Tests the checkAndReallocate function with mismatched lengths of the allocations
  ///         and riskDatas arrays, expecting a revert with INVALID_RISK_DATA_COUNT error
  function testCheckAndReallocateWithMismatchedArrayLengths() public {
    // Create two MarketAllocations
    MarketAllocation[] memory allocations = new MarketAllocation[](2);
    allocations[0] = MarketAllocation({marketParams: market1, assets: 1000});
    allocations[1] = MarketAllocation({marketParams: market2, assets: 2000});

    // Create one RiskData
    RiskData[] memory riskDatas = new RiskData[](1);
    riskDatas[0] = RiskData({
      collateralAsset: address(1), // Example address
      debtAsset: address(2), // Example address
      liquidity: 1000, // Example value
      volatility: 500, // Example value
      lastUpdate: block.timestamp, // Current block timestamp
      chainId: block.chainid // Current chain ID
    });

    // Signatures array can be arbitrary since the test should revert before its length is checked
    Signature[] memory signatures = new Signature[](1);
    signatures[0] = Signature({
      v: uint8(27), // Example value
      r: bytes32(0), // Example value
      s: bytes32(0) // Example value
    });

    // Expect revert with INVALID_RISK_DATA_COUNT error
    vm.expectRevert(
      abi.encodeWithSelector(ErrorLib.INVALID_RISK_DATA_COUNT.selector, allocations.length, riskDatas.length)
    );

    morphoAllocator.checkAndReallocate(allocations, riskDatas, signatures);
  }

  /// @notice Tests the checkAndReallocate function with mismatched lengths of the riskDatas
  ///         and signatures arrays, expecting a revert with INVALID_SIGNATURE_COUNT error
  function testCheckAndReallocateWithMismatchedSignatureArrayLengths() public {
    MarketAllocation[] memory allocations = new MarketAllocation[](1);
    allocations[0] = MarketAllocation({marketParams: market1, assets: 1000});

    RiskData[] memory riskDatas = new RiskData[](1);
    riskDatas[0] = RiskData({
      collateralAsset: address(1), // Example address
      debtAsset: address(2), // Example address
      liquidity: 1000, // Example value
      volatility: 500, // Example value
      lastUpdate: block.timestamp, // Current block timestamp
      chainId: block.chainid // Current chain ID
    });

    Signature[] memory signatures = new Signature[](2);
    signatures[0] = Signature({
      v: uint8(27), // Example value
      r: bytes32(0), // Example value
      s: bytes32(0) // Example value
    });
    signatures[1] = Signature({
      v: uint8(27), // Example value
      r: bytes32(0), // Example value
      s: bytes32(0) // Example value
    });

    // Expect revert with INVALID_SIGNATURE_COUNT error
    vm.expectRevert(
      abi.encodeWithSelector(ErrorLib.INVALID_SIGNATURE_COUNT.selector, riskDatas.length, signatures.length)
    );

    morphoAllocator.checkAndReallocate(allocations, riskDatas, signatures);
  }

  /// @notice Tests the checkAndReallocate function with a withdrawal scenario, verifying correct handling of withdraw requests
  ///         that should not check the risk levels
  function testCheckReallocateWithWitdraw() public {
    // first we set a position for the market1
    PositionInfo memory pInfo = PositionInfo({supplyShares: 1000e18, borrowShares: 0, collateral: 0});
    mockMorpho.setPositionInfo(MorphoLib.id(market1), address(mockMetaMorpho), pInfo);

    // then we generate the allocation,
    MarketAllocation[] memory allocations = new MarketAllocation[](1);
    // the generated allocation target 10 assets to it should withdraw
    allocations[0] = MarketAllocation({marketParams: market1, assets: 10});

    // the risk data and signature don't matter because we won't test risk
    // as it is a withdraw
    RiskData[] memory riskDatas = new RiskData[](1);
    riskDatas[0] = RiskData({
      collateralAsset: address(1), // Example address
      debtAsset: address(2), // Example address
      liquidity: 1000, // Example value
      volatility: 500, // Example value
      lastUpdate: block.timestamp, // Current block timestamp
      chainId: block.chainid // Current chain ID
    });

    Signature[] memory signatures = new Signature[](1);
    signatures[0] = Signature({
      v: uint8(27), // Example value
      r: bytes32(0), // Example value
      s: bytes32(0) // Example value
    });

    morphoAllocator.checkAndReallocate(allocations, riskDatas, signatures);
  }

  /// @notice Tests the checkAndReallocate function with a scenario where supplying is too risky,
  ///         expecting a revert with LTV_TOO_HIGH error
  function testCheckReallocateSupplyTooRisky() public {
    // first we set a position for the market1
    PositionInfo memory pInfo = PositionInfo({supplyShares: 1000e18, borrowShares: 0, collateral: 0});
    mockMorpho.setPositionInfo(MorphoLib.id(market2), address(mockMetaMorpho), pInfo);

    // then we generate the allocation,
    // the signature needs to be valid because we will check risk
    MarketAllocation[] memory allocations = new MarketAllocation[](1);
    allocations[0] = MarketAllocation({marketParams: market2, assets: 2000e18});

    // these risk parameters should make the smartLTV returns 0% LTV
    // so it should revert
    uint256 liquidity = 1e18; // low liquidity
    uint256 volatility = 100_000_000e18; // big volatility

    (RiskData memory data, uint8 v, bytes32 r, bytes32 s) = TestUtils.signDataValid(
      trustedRelayerPrivateKey,
      market2.collateralToken,
      market2.loanToken,
      pythia.RISKDATA_TYPEHASH(),
      pythia.DOMAIN_SEPARATOR(),
      liquidity,
      volatility
    );

    RiskData[] memory riskDatas = new RiskData[](1);
    riskDatas[0] = data;

    Signature[] memory signatures = new Signature[](1);
    signatures[0] = Signature({v: v, r: r, s: s});

    vm.expectRevert(abi.encodeWithSelector(ErrorLib.LTV_TOO_HIGH.selector, market2.lltv, uint256(0)));
    morphoAllocator.checkAndReallocate(allocations, riskDatas, signatures);
  }

  /// @notice Tests the checkAndReallocate function with a valid risk scenario, verifying correct allocation without error
  function testCheckReallocateSupplyValidRisk() public {
    // first we set a position for the market1
    PositionInfo memory pInfo = PositionInfo({supplyShares: 1000e18, borrowShares: 0, collateral: 0});
    mockMorpho.setPositionInfo(MorphoLib.id(market1), address(mockMetaMorpho), pInfo);

    // then we generate the allocation,
    // the signature needs to be valid because we will check risk
    MarketAllocation[] memory allocations = new MarketAllocation[](1);
    allocations[0] = MarketAllocation({marketParams: market1, assets: 2000e18});

    // these risk parameters should make the smartLTV returns 0% LTV
    // so it should revert
    uint256 liquidity = 10_000_000e18; // big liquidity
    uint256 volatility = 0.01e18; // 1% volatility

    (RiskData memory data, uint8 v, bytes32 r, bytes32 s) = TestUtils.signDataValid(
      trustedRelayerPrivateKey,
      market1.collateralToken,
      market1.loanToken,
      pythia.RISKDATA_TYPEHASH(),
      pythia.DOMAIN_SEPARATOR(),
      liquidity,
      volatility
    );

    RiskData[] memory riskDatas = new RiskData[](1);
    riskDatas[0] = data;

    Signature[] memory signatures = new Signature[](1);
    signatures[0] = Signature({v: v, r: r, s: s});

    // vm.expectRevert(abi.encodeWithSelector(ErrorLib.LTV_TOO_HIGH.selector, market2.lltv, uint256(0)));
    morphoAllocator.checkAndReallocate(allocations, riskDatas, signatures);
  }

  /// @notice Tests the checkAndReallocate function with a combination of withdrawal and risky supply,
  ///         expecting a revert with LTV_TOO_HIGH error
  function testCheckReallocateWithdrawAndSupplyTooRisky() public {
    // first we set a position for the market1, where we want to withdraw
    PositionInfo memory pInfo1 = PositionInfo({supplyShares: 1000e18, borrowShares: 0, collateral: 0});
    mockMorpho.setPositionInfo(MorphoLib.id(market1), address(mockMetaMorpho), pInfo1);

    // first we set a position for the market2, where we want to supply
    PositionInfo memory pInfo2 = PositionInfo({supplyShares: 10e18, borrowShares: 0, collateral: 0});
    mockMorpho.setPositionInfo(MorphoLib.id(market2), address(mockMetaMorpho), pInfo2);

    // then we generate the allocation,
    MarketAllocation[] memory allocations = new MarketAllocation[](2);
    // the generated allocation target 10 assets to it should withdraw
    allocations[0] = MarketAllocation({marketParams: market1, assets: 10});
    allocations[1] = MarketAllocation({marketParams: market2, assets: 1000e18});

    // the first risk data and signature don't matter because it's a withdraw
    // but the second must be valid
    RiskData[] memory riskDatas = new RiskData[](2);
    riskDatas[0] = RiskData({
      collateralAsset: address(1), // Example address
      debtAsset: address(2), // Example address
      liquidity: 1000, // Example value
      volatility: 500, // Example value
      lastUpdate: block.timestamp, // Current block timestamp
      chainId: block.chainid // Current chain ID
    });

    // these risk parameters should make the smartLTV returns 0% LTV
    // so it should revert
    uint256 liquidity = 1e18; // low liquidity
    uint256 volatility = 100_000_000e18; // big volatility

    (RiskData memory data, uint8 v, bytes32 r, bytes32 s) = TestUtils.signDataValid(
      trustedRelayerPrivateKey,
      market2.collateralToken,
      market2.loanToken,
      pythia.RISKDATA_TYPEHASH(),
      pythia.DOMAIN_SEPARATOR(),
      liquidity,
      volatility
    );

    riskDatas[1] = data;

    Signature[] memory signatures = new Signature[](2);
    signatures[0] = Signature({
      v: uint8(27), // Example value
      r: bytes32(0), // Example value
      s: bytes32(0) // Example value
    });

    signatures[1] = Signature({v: v, r: r, s: s});

    vm.expectRevert(abi.encodeWithSelector(ErrorLib.LTV_TOO_HIGH.selector, market2.lltv, uint256(0)));
    morphoAllocator.checkAndReallocate(allocations, riskDatas, signatures);
  }

  /// @notice Tests the checkAndReallocate function with a combination of withdrawal and valid supply,
  ///         verifying correct processing of both actions
  function testCheckReallocateWithdrawAndSupplyValid() public {
    // first we set a position for the market1, where we want to withdraw
    PositionInfo memory pInfo1 = PositionInfo({supplyShares: 1000e18, borrowShares: 0, collateral: 0});
    mockMorpho.setPositionInfo(MorphoLib.id(market1), address(mockMetaMorpho), pInfo1);

    // we set a position for the market2, where we want to supply
    PositionInfo memory pInfo2 = PositionInfo({supplyShares: 10e18, borrowShares: 0, collateral: 0});
    mockMorpho.setPositionInfo(MorphoLib.id(market2), address(mockMetaMorpho), pInfo2);

    // then we generate the allocation,
    MarketAllocation[] memory allocations = new MarketAllocation[](2);
    // the generated allocation target 10 assets to it should withdraw
    allocations[0] = MarketAllocation({marketParams: market1, assets: 10});
    allocations[1] = MarketAllocation({marketParams: market2, assets: 1000e18});

    // the first risk data and signature don't matter because it's a withdraw
    // but the second must be valid
    RiskData[] memory riskDatas = new RiskData[](2);
    riskDatas[0] = RiskData({
      collateralAsset: address(1), // Example address
      debtAsset: address(2), // Example address
      liquidity: 1000, // Example value
      volatility: 500, // Example value
      lastUpdate: block.timestamp, // Current block timestamp
      chainId: block.chainid // Current chain ID
    });

    // these risk parameters should make the smartLTV returns a valid ltv
    uint256 liquidity = 10_000_000_000e18; // big liquidity
    uint256 volatility = 0.01e18; // low volatility

    (RiskData memory data, uint8 v, bytes32 r, bytes32 s) = TestUtils.signDataValid(
      trustedRelayerPrivateKey,
      market2.collateralToken,
      market2.loanToken,
      pythia.RISKDATA_TYPEHASH(),
      pythia.DOMAIN_SEPARATOR(),
      liquidity,
      volatility
    );

    riskDatas[1] = data;

    Signature[] memory signatures = new Signature[](2);
    signatures[0] = Signature({
      v: uint8(27), // Example value
      r: bytes32(0), // Example value
      s: bytes32(0) // Example value
    });

    signatures[1] = Signature({v: v, r: r, s: s});

    morphoAllocator.checkAndReallocate(allocations, riskDatas, signatures);
  }
}
