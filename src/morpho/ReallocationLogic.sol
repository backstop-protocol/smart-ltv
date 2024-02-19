// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import {IMetaMorpho, IMetaMorphoBase, MarketAllocation, Id, MarketConfig} from "../../lib/metamorpho/src/interfaces/IMetaMorpho.sol";
import {MarketParamsLib, MarketParams} from "../../lib/metamorpho/lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import {IMorpho} from "../../lib/metamorpho/lib/morpho-blue/src/interfaces/IMorpho.sol";
import {SharesMathLib} from "../../lib/metamorpho/lib/morpho-blue/src/libraries/SharesMathLib.sol";
import {MathLib, WAD} from "../../lib/metamorpho/lib/morpho-blue/src/libraries/MathLib.sol";
import {MorphoBalancesLib} from "../../lib/metamorpho/lib/morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol";
import {MorphoLib} from "../../lib/metamorpho/lib/morpho-blue/src/libraries/periphery/MorphoLib.sol";
import {UtilsLib} from "../../lib/metamorpho/lib/morpho-blue/src/libraries/UtilsLib.sol";
import {TargetAllocator} from "./TargetAllocator.sol";

interface IReallocationLogic {
  function setParams(
    TargetAllocator _targetAllocator,
    address _vaultAddress,
    IMorpho _morpho,
    Id _idleMarketId,
    uint _minReallocationSize
  ) external;

  function checkReallocationNeeded() external view returns (bool, MarketAllocation[] memory);
}

contract ReallocationLogic {
  using MorphoBalancesLib for IMorpho;
  using MarketParamsLib for MarketParams;
  using SharesMathLib for uint256;
  using MathLib for uint256;
  using MorphoLib for IMorpho;
  using UtilsLib for uint256;

  TargetAllocator targetAllocator;
  address VAULT_ADDRESS;
  IMorpho MORPHO;
  Id IDLE_MARKET_ID;
  uint minReallocationSize;

  function setParams(
    TargetAllocator _targetAllocator,
    address _vaultAddress,
    IMorpho _morpho,
    Id _idleMarketId,
    uint _minReallocationSize
  ) public {
    targetAllocator = _targetAllocator;
    VAULT_ADDRESS = _vaultAddress;
    MORPHO = _morpho;
    IDLE_MARKET_ID = _idleMarketId;
    minReallocationSize = _minReallocationSize;
  }

  /** CHECK FUNCTIONS */

  /// @notice Checks if reallocation is needed across all markets based on current and target utilizations.
  /// @return bool Indicates if reallocation is needed.
  /// @return marketAllocations The array of market allocations to be performed if reallocation is needed.
  function checkReallocationNeeded() public view returns (bool, MarketAllocation[] memory) {
    uint256 nbMarkets = IMetaMorpho(VAULT_ADDRESS).withdrawQueueLength();

    MarketParams memory idleMarketParams = MORPHO.idToMarketParams(IDLE_MARKET_ID);
    uint256 idleAssetsAvailable = getAvailableIdleAssets(idleMarketParams);
    for (uint256 i = 0; i < nbMarkets; i++) {
      Id marketId = IMetaMorpho(VAULT_ADDRESS).withdrawQueue(i);
      (bool mustReallocate, MarketAllocation[] memory allocations) = checkMarket(
        marketId,
        idleAssetsAvailable,
        idleMarketParams
      );

      if (mustReallocate) {
        return (true, allocations);
      }
    }

    return (false, new MarketAllocation[](0));
  }

  /// @notice Gets the available assets of the vault currently in the idle market.
  /// @return uint256 Amount of assets available in to be reallocated from the idle market
  function getAvailableIdleAssets(MarketParams memory idleMarketParams) public view returns (uint256) {
    (uint256 totalSupplyAssets, uint256 totalSupplyShares, uint256 totalBorrowAssets, ) = MORPHO.expectedMarketBalances(
      idleMarketParams
    );

    uint256 supplyShares = MORPHO.supplyShares(IDLE_MARKET_ID, VAULT_ADDRESS);
    uint256 supplyAssets = supplyShares.toAssetsDown(totalSupplyAssets, totalSupplyShares);
    uint256 availableLiquidity = totalSupplyAssets - totalBorrowAssets;

    uint256 idleAssetsAvailable = UtilsLib.min(supplyAssets, availableLiquidity);

    return idleAssetsAvailable;
  }

  /// @notice Checks a specific market to determine if reallocation is necessary based on its current utilization and target allocation settings.
  /// @param marketId The market identifier to check.
  /// @param idleAssetsAvailable The amount of assets available in the idle market that can be reallocated.
  /// @param idleMarketParams The market parameters of the idle market.
  /// @return bool Indicates if reallocation is needed for the market.
  /// @return marketAllocations The array of market allocations to be performed if reallocation is needed.
  function checkMarket(
    Id marketId,
    uint256 idleAssetsAvailable,
    MarketParams memory idleMarketParams
  ) public view returns (bool, MarketAllocation[] memory marketAllocations) {
    MarketParams memory marketParams = MORPHO.idToMarketParams(marketId);

    if (marketParams.collateralToken == address(0)) {
      // do not check idle market
      return (false, marketAllocations);
    }

    TargetAllocator.TargetAllocation memory targetAllocation = targetAllocator.getTargetAllocation(marketId);

    // if target allocation for market not set, ignore market
    if (targetAllocation.targetUtilization == 0) {
      return (false, marketAllocations);
    }

    (uint256 totalSupplyAssets, uint256 totalSupplyShares, uint256 totalBorrowAssets, ) = MORPHO.expectedMarketBalances(
      marketParams
    );

    // compute utilization and target total supply assets
    uint256 currentUtilization = (totalBorrowAssets * 1e18) / totalSupplyAssets;

    uint256 targetTotalSupplyAssets = (totalBorrowAssets * 1e18) / targetAllocation.targetUtilization;

    // check if we need to reallocate
    if (currentUtilization > targetAllocation.maxUtilization) {
      // utilization > max target utilization, we should add liquidity from idle
      // compute amount to supply
      // min between the amount available in the idle market and the amount we need to supply
      uint256 amountToSupply = UtilsLib.min(idleAssetsAvailable, targetTotalSupplyAssets - totalSupplyAssets);

      // only reallocate if sufficient amount
      if (amountToSupply < minReallocationSize) {
        return (false, marketAllocations);
      }

      marketAllocations = new MarketAllocation[](2);
      // create allocation: withdraw from idle
      marketAllocations[0] = MarketAllocation({
        marketParams: idleMarketParams,
        // new assets value for the idle market
        // = idleAssetsAvailable minus amount to supply
        assets: idleAssetsAvailable - amountToSupply
      });
      // create allocation: supply all withdrawn to market
      marketAllocations[1] = MarketAllocation({marketParams: marketParams, assets: type(uint256).max});

      return (true, marketAllocations);
    } else if (currentUtilization < targetAllocation.minUtilization) {
      // utilization < min target utilization, we should withdraw to the idle market

      // Keep at least targetAllocation.minLiquidity available
      // this is done because if total supply = 10, total borrow = 5 target utilization = 80% and minLiquidity = 4
      // currently, available liquidity is 10 - 5 = 5 and the current utilization is 50%
      // so to reach 80% we would need to lower the supply to 6.25 => 5/6.25 = 0.8. But if we do that,
      // the remaining liquidity will be 6.25 - 5 = 1.25 which is < 4
      // in this case we will then define the targetTotalSupplyAssets as totalBorrowAssets + targetAllocation.minLiquidity => (5 + 4) = 9
      // this mean a utilization of 55%, better than the current 50% but keeping the minLiquidity as desired
      if (targetTotalSupplyAssets < totalBorrowAssets + targetAllocation.minLiquidity) {
        targetTotalSupplyAssets = totalBorrowAssets + targetAllocation.minLiquidity;
      }

      uint256 supplyShares = MORPHO.supplyShares(marketParams.id(), VAULT_ADDRESS);
      uint256 supplyAssets = supplyShares.toAssetsDown(totalSupplyAssets, totalSupplyShares);
      uint256 availableLiquidity = totalSupplyAssets - totalBorrowAssets;

      // if the available liquidity is less than our threshold, do not change anything
      if (availableLiquidity < targetAllocation.minLiquidity) {
        return (false, marketAllocations);
      }

      uint256 amountToWithdraw = UtilsLib.min(availableLiquidity, totalSupplyAssets - targetTotalSupplyAssets);
      // do not try to withdraw more than what was supplied by the vault
      amountToWithdraw = UtilsLib.min(amountToWithdraw, supplyAssets);

      // only reallocate if sufficient amount
      if (amountToWithdraw < minReallocationSize) {
        return (false, marketAllocations);
      }

      marketAllocations = new MarketAllocation[](2);
      // create allocation: withdraw from the market
      marketAllocations[0] = MarketAllocation({
        marketParams: marketParams,
        // new assets value for the non idle market
        // = current vault supply minus amount to withdraw
        assets: supplyAssets - amountToWithdraw
      });
      // create allocation: supply all withdrawn to idle market
      marketAllocations[1] = MarketAllocation({marketParams: idleMarketParams, assets: type(uint256).max});

      return (true, marketAllocations);
    }

    return (false, marketAllocations);
  }
}
