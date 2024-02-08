// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../../lib/forge-std/src/Test.sol";
import {TargetAllocator} from "../../src/morpho/TargetAllocator.sol";
import {IERC20Metadata} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import {Market, Position} from "../../lib/metamorpho/lib/morpho-blue/src/interfaces/IMorpho.sol";
import {IMorpho} from "../../lib/metamorpho/lib/morpho-blue/src/interfaces/IMorpho.sol";
import {MorphoLib} from "../../lib/metamorpho/lib/morpho-blue/src/libraries/periphery/MorphoLib.sol";
import {MorphoBalancesLib} from "../../lib/metamorpho/lib/morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol";
import {MathLib, WAD} from "../../lib/metamorpho/lib/morpho-blue/src/libraries/MathLib.sol";
import {SharesMathLib} from "../../lib/metamorpho/lib/morpho-blue/src/libraries/SharesMathLib.sol";
import {MarketParamsLib, MarketParams} from "../../lib/metamorpho/lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import {IMetaMorpho, IMetaMorphoBase, MarketAllocation, Id, MarketConfig} from "../../lib/metamorpho/src/interfaces/IMetaMorpho.sol";
import {TestUtils} from "../TestUtils.sol";

interface FiatTokenV1 {
  function masterMinter() external returns (address);
  function mint(address _to, uint256 _amount) external returns (bool);
  function configureMinter(address minter, uint256 minterAmount) external returns (bool);
}

/// @notice
/// launch with: forge test --match-contract IntegrationTestTargetAllocator --rpc-url {MAINNET RPC URL} -vvv
contract IntegrationTestTargetAllocator is Test {
  /// USDC
  address public USDC_VAULT = 0x186514400e52270cef3D80e1c6F8d10A75d47344;
  bytes32 public USDC_IDLE_MARKET = 0x54efdee08e272e929034a8f26f7ca34b1ebe364b275391169b28c6d7db24dbc8;
  TargetAllocator public usdcTargetAllocator;
  address public usdcVaultOwner;

  /// ETH
  address public ETH_VAULT = 0x38989BBA00BDF8181F4082995b3DEAe96163aC5D;
  bytes32 public ETH_IDLE_MARKET = 0x58e212060645d18eab6d9b2af3d56fbc906a92ff5667385f616f662c70372284;
  TargetAllocator public ethTargetAllocator;
  address public ethVaultOwner;

  /// GLOBAL
  IMorpho public immutable MORPHO = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);

  /// USERS
  address allocator = address(0x01010101010101);
  address notAllocator = address(0x02020202020202);
  address keeper = address(0x9999999999999999);

  function setUp() public {
    deployUsdcTargetAllocator();
    deployEthTargetAllocator();

    vm.startPrank(usdcVaultOwner);
    IMetaMorpho(USDC_VAULT).setIsAllocator(allocator, true);
    IMetaMorpho(USDC_VAULT).setIsAllocator(address(usdcTargetAllocator), true);
    vm.stopPrank();

    vm.startPrank(ethVaultOwner);
    IMetaMorpho(ETH_VAULT).setIsAllocator(allocator, true);
    IMetaMorpho(ETH_VAULT).setIsAllocator(address(ethTargetAllocator), true);
    vm.stopPrank();
  }

  function deployUsdcTargetAllocator() public {
    // automatically set up all markets to target 75% utilization
    uint256 nbMarkets = IMetaMorpho(USDC_VAULT).withdrawQueueLength();
    bytes32[] memory marketIds = new bytes32[](nbMarkets - 1); // assume only 1 idle market
    TargetAllocator.TargetAllocation[] memory targetAllocations = new TargetAllocator.TargetAllocation[](nbMarkets - 1); // assume only 1 idle market
    uint cursor = 0;
    for (uint i = 0; i < nbMarkets; i++) {
      Id marketId = IMetaMorpho(USDC_VAULT).withdrawQueue(i);
      MarketParams memory prms = MORPHO.idToMarketParams(marketId);
      if (prms.collateralToken != address(0)) {
        marketIds[cursor] = Id.unwrap(marketId);
        targetAllocations[cursor++] = TargetAllocator.TargetAllocation({
          maxUtilization: 0.80e18,
          targetUtilization: 0.75e18,
          minUtilization: 0.70e18,
          minLiquidity: 100_000e6
        });
      }
    }

    usdcTargetAllocator = new TargetAllocator(
      USDC_IDLE_MARKET,
      USDC_VAULT,
      120,
      1, // 1 wei of usdc for testing purpose
      keeper,
      marketIds,
      targetAllocations
    );
    usdcVaultOwner = IMetaMorpho(USDC_VAULT).owner();
  }

  function deployEthTargetAllocator() public {
    // automatically set up all markets to target 75% utilization
    uint256 nbMarkets = IMetaMorpho(ETH_VAULT).withdrawQueueLength();
    bytes32[] memory marketIds = new bytes32[](nbMarkets - 1); // assume only 1 idle market
    TargetAllocator.TargetAllocation[] memory targetAllocations = new TargetAllocator.TargetAllocation[](nbMarkets - 1); // assume only 1 idle market
    uint cursor = 0;
    for (uint i = 0; i < nbMarkets; i++) {
      Id marketId = IMetaMorpho(ETH_VAULT).withdrawQueue(i);
      MarketParams memory prms = MORPHO.idToMarketParams(marketId);
      if (prms.collateralToken != address(0)) {
        marketIds[cursor] = Id.unwrap(marketId);
        targetAllocations[cursor++] = TargetAllocator.TargetAllocation({
          maxUtilization: 0.80e18,
          targetUtilization: 0.75e18,
          minUtilization: 0.70e18,
          minLiquidity: 100e18
        });
      }
    }

    ethTargetAllocator = new TargetAllocator(
      ETH_IDLE_MARKET,
      ETH_VAULT,
      120,
      1, // 1 wei of eth for testing purpose
      keeper,
      marketIds,
      targetAllocations
    );
    ethVaultOwner = IMetaMorpho(ETH_VAULT).owner();
  }

  function testInitialize() public {
    assertEq(IMetaMorpho(USDC_VAULT).isAllocator(allocator), true);
    assertEq(IMetaMorpho(ETH_VAULT).isAllocator(allocator), true);

    assertEq(USDC_IDLE_MARKET, Id.unwrap(usdcTargetAllocator.IDLE_MARKET_ID()));
    assertEq(ETH_IDLE_MARKET, Id.unwrap(ethTargetAllocator.IDLE_MARKET_ID()));

    assertEq(USDC_VAULT, usdcTargetAllocator.VAULT_ADDRESS());
    assertEq(ETH_VAULT, ethTargetAllocator.VAULT_ADDRESS());
  }

  /// @notice set the utilization for each markets to 90% and then call checkReallocation needed
  /// it should reallocate supply to the first market in the list to decrease the utilization to the setUp target parameter
  /// of 75%
  function testReallocationUsdcDecreaseUtilization() public {
    // this methods set all non-idle markets to 90% utilization
    // and also add 10M tokens to the idle market supply
    setUpVaultMarketsToXPctUtilization(IMetaMorpho(USDC_VAULT), 0.9e18);

    (bool reallocationNeeded, MarketAllocation[] memory allocations) = usdcTargetAllocator.checkReallocationNeeded();
    assertTrue(reallocationNeeded);
    TestUtils.displayMarketStatus("BEFORE", IMetaMorpho(usdcTargetAllocator.VAULT_ADDRESS()), MORPHO);
    MarketParams memory changedMarket;
    for (uint i = 0; i < allocations.length; i++) {
      // displayAllocationAsLog(allocations[i]);
      if (allocations[i].marketParams.collateralToken != address(0)) {
        changedMarket = allocations[i].marketParams;
      }
    }

    (, bytes memory call) = usdcTargetAllocator.keeperCheck();
    vm.prank(allocator);
    usdcTargetAllocator.keeperCall(call);
    TestUtils.displayMarketStatus("AFTER", IMetaMorpho(usdcTargetAllocator.VAULT_ADDRESS()), MORPHO);

    // compute utilization of the modified market
    Market memory m = MORPHO.market(MarketParamsLib.id(changedMarket));
    uint256 utilization = m.totalSupplyAssets == 0
      ? 0
      : (uint256(m.totalBorrowAssets) * 1e18) / uint256(m.totalSupplyAssets);

    assertApproxEqAbs(utilization, 0.75e18, 0.01e18);

    vm.roll(block.number + 100);
    vm.warp(block.timestamp + 100 * 12);

    // next market shoud now be the target
    (bool newReallocationNeeded, MarketAllocation[] memory newAllocations) = usdcTargetAllocator
      .checkReallocationNeeded();
    assertTrue(newReallocationNeeded);
    MarketParams memory newChangedMarket;
    for (uint i = 0; i < newAllocations.length; i++) {
      // displayAllocationAsLog(newAllocations[i]);
      if (newAllocations[i].marketParams.collateralToken != address(0)) {
        newChangedMarket = newAllocations[i].marketParams;
      }
    }

    // assert new changed market is different than the fost
    assertTrue(
      newChangedMarket.collateralToken != changedMarket.collateralToken || newChangedMarket.lltv != changedMarket.lltv
    );

    (, call) = usdcTargetAllocator.keeperCheck();
    vm.prank(allocator);
    usdcTargetAllocator.keeperCall(call);
    TestUtils.displayMarketStatus(
      "AFTER SECOND REALLOCATION",
      IMetaMorpho(usdcTargetAllocator.VAULT_ADDRESS()),
      MORPHO
    );

    // recompute utilization of the new changed market
    m = MORPHO.market(MarketParamsLib.id(newChangedMarket));
    utilization = m.totalSupplyAssets == 0 ? 0 : (uint256(m.totalBorrowAssets) * 1e18) / uint256(m.totalSupplyAssets);

    assertApproxEqAbs(utilization, 0.75e18, 0.01e18);

    // if (reallocationNeeded) {
    //   TestUtils.displayMarketStatus("BEFORE", IMetaMorpho(usdcTargetAllocator.VAULT_ADDRESS()), MORPHO);
    //   console.log("%s reallocations on USDC vault", allocations.length);
    //   for (uint i = 0; i < allocations.length; i++) {
    //     displayAllocationAsLog(allocations[i]);
    //   }

    //   (, bytes memory call) = usdcTargetAllocator.keeperCheck();
    //   vm.prank(allocator);
    //   usdcTargetAllocator.keeperCall(call);

    //   TestUtils.displayMarketStatus("AFTER", IMetaMorpho(usdcTargetAllocator.VAULT_ADDRESS()), MORPHO);
    // } else {
    //   console.log("No reallocations on USDC vault");
    // }
  }

  /// @notice set the utilization for each markets to 90% and then call checkReallocation needed
  /// it should reallocate supply to the first market in the list to decrease the utilization to the setUp target parameter
  /// of 75%
  function testReallocationEthDecreaseUtilization() public {
    // this methods set all non-idle markets to 90% utilization
    // and also add 10M tokens to the idle market supply
    setUpVaultMarketsToXPctUtilization(IMetaMorpho(ETH_VAULT), 0.9e18);

    (bool reallocationNeeded, MarketAllocation[] memory allocations) = ethTargetAllocator.checkReallocationNeeded();
    assertTrue(reallocationNeeded);
    TestUtils.displayMarketStatus("BEFORE", IMetaMorpho(ethTargetAllocator.VAULT_ADDRESS()), MORPHO);
    MarketParams memory changedMarket;
    for (uint i = 0; i < allocations.length; i++) {
      // displayAllocationAsLog(allocations[i]);
      if (allocations[i].marketParams.collateralToken != address(0)) {
        changedMarket = allocations[i].marketParams;
      }
    }

    (, bytes memory call) = ethTargetAllocator.keeperCheck();
    vm.prank(allocator);
    ethTargetAllocator.keeperCall(call);
    TestUtils.displayMarketStatus("AFTER", IMetaMorpho(ethTargetAllocator.VAULT_ADDRESS()), MORPHO);

    // compute utilization of the modified market
    Market memory m = MORPHO.market(MarketParamsLib.id(changedMarket));
    uint256 utilization = m.totalSupplyAssets == 0
      ? 0
      : (uint256(m.totalBorrowAssets) * 1e18) / uint256(m.totalSupplyAssets);

    assertApproxEqAbs(utilization, 0.75e18, 0.01e18);
  }

  /// @notice set the utilization for each markets to 10% and then call checkReallocation needed
  /// it should reallocate supply to the first market in the list to increase the utilization to the setUp target parameter
  /// of 75%
  function testReallocationEthIncreaseUtilization() public {
    // this methods set all non-idle markets to 10% utilization
    // and also add 10M tokens to the idle market supply
    setUpVaultMarketsToXPctUtilization(IMetaMorpho(ETH_VAULT), 0.1e18);

    (bool reallocationNeeded, MarketAllocation[] memory allocations) = ethTargetAllocator.checkReallocationNeeded();
    assertTrue(reallocationNeeded);
    TestUtils.displayMarketStatus("BEFORE", IMetaMorpho(ethTargetAllocator.VAULT_ADDRESS()), MORPHO);
    MarketParams memory changedMarket;
    for (uint i = 0; i < allocations.length; i++) {
      // displayAllocationAsLog(allocations[i]);
      if (allocations[i].marketParams.collateralToken != address(0)) {
        changedMarket = allocations[i].marketParams;
      }
    }

    (, bytes memory call) = ethTargetAllocator.keeperCheck();
    vm.prank(allocator);
    ethTargetAllocator.keeperCall(call);
    TestUtils.displayMarketStatus("AFTER", IMetaMorpho(ethTargetAllocator.VAULT_ADDRESS()), MORPHO);

    // compute utilization of the modified market
    Market memory m = MORPHO.market(MarketParamsLib.id(changedMarket));
    uint256 utilization = m.totalSupplyAssets == 0
      ? 0
      : (uint256(m.totalBorrowAssets) * 1e18) / uint256(m.totalSupplyAssets);

    assertApproxEqAbs(utilization, 0.75e18, 0.01e18);
  }

  function setUpVaultMarketsToXPctUtilization(IMetaMorpho vault, uint256 pctTarget) public {
    // function deal(address token, address to, uint256 give)
    // give 1B asset to this
    uint256 dealAmount = 1_000_000_000 * 10 ** IERC20Metadata(vault.asset()).decimals();
    dealToken(vault.asset(), address(this), dealAmount);
    ERC20(vault.asset()).approve(address(MORPHO), dealAmount);

    uint256 nbMarkets = vault.withdrawQueueLength();
    for (uint i = 0; i < nbMarkets; i++) {
      Id marketId = vault.withdrawQueue(i);
      MarketParams memory marketParams = MORPHO.idToMarketParams(marketId);
      if (marketParams.collateralToken != address(0)) {
        Market memory m = MORPHO.market(marketId);
        uint256 pctUtilization = (uint256(m.totalBorrowAssets) * 1e18) / uint256(m.totalSupplyAssets);
        if (pctUtilization >= pctTarget) {
          // NEEDS TO ADD SUPPLY TO LOWER THE UTILIZATION TO 50%
          // supplyToAdd => borrow x2 minus already supplied
          uint256 targetSupply = (uint256(m.totalBorrowAssets) * 1e18) / pctTarget;
          uint256 supplyToAdd = targetSupply - uint256(m.totalSupplyAssets);
          MORPHO.supply(marketParams, supplyToAdd, 0, address(vault), "");
        } else {
          // NEEDS TO BORROW TO MAKE THE UTILIZATION HIGHER
          uint256 targetBorrow = (uint256(m.totalSupplyAssets) * pctTarget) / 1e18;
          uint256 amountToBorrow = targetBorrow - uint256(m.totalBorrowAssets);
          uint256 amountCollateral = 1_000_000_000 * 10 ** IERC20Metadata(marketParams.collateralToken).decimals();
          dealToken(marketParams.collateralToken, address(this), amountCollateral);
          ERC20(marketParams.collateralToken).approve(address(MORPHO), amountCollateral);
          MORPHO.supplyCollateral(marketParams, amountCollateral, address(this), "");
          MORPHO.borrow(marketParams, amountToBorrow, 0, address(this), address(this));
        }
      } else {
        // supply 10_000_000 to the idle market onBehalf of the vault
        uint256 amountToSupplyToIdle = 10_000_000 * 10 ** IERC20Metadata(vault.asset()).decimals();
        MORPHO.supply(marketParams, amountToSupplyToIdle, 0, address(vault), "");
      }
    }
  }

  function displayAllocationAsLog(MarketAllocation memory allocation) public view {
    console.log(
      "%s market (%s), assets: %s",
      TestUtils.addressToSymbol(allocation.marketParams.collateralToken),
      TestUtils.toPercentageString(allocation.marketParams.lltv),
      allocation.assets == type(uint256).max ? "MAX" : TestUtils.uintToString(allocation.assets)
    );
  }

  function dealToken(address token, address to, uint256 amount) public {
    address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    if (token == usdc) {
      // if usdc, needs to mint as the master minter
      address masterMint = FiatTokenV1(usdc).masterMinter();
      vm.prank(masterMint);
      FiatTokenV1(usdc).configureMinter(address(this), type(uint256).max);
      FiatTokenV1(usdc).mint(to, amount);
    } else {
      deal(token, address(this), amount);
    }
  }
}
