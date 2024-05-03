// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import {IMetaMorpho, MarketAllocation, Id, MarketConfig} from "../../lib/metamorpho/src/interfaces/IMetaMorpho.sol";
import {MarketParamsLib, MarketParams} from "../../lib/metamorpho/lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import {IMorpho} from "../../lib/metamorpho/lib/morpho-blue/src/interfaces/IMorpho.sol";
import {SharesMathLib} from "../../lib/metamorpho/lib/morpho-blue/src/libraries/SharesMathLib.sol";
import {MathLib, WAD} from "../../lib/metamorpho/lib/morpho-blue/src/libraries/MathLib.sol";
import {MorphoBalancesLib} from "../../lib/metamorpho/lib/morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol";
import {MorphoLib} from "../../lib/metamorpho/lib/morpho-blue/src/libraries/periphery/MorphoLib.sol";
import {UtilsLib} from "../../lib/metamorpho/lib/morpho-blue/src/libraries/UtilsLib.sol";
import {RiskData} from "../interfaces/RiskData.sol";
import {SmartLTV} from "../core/SmartLTV.sol";
import "../../lib/metamorpho/lib/morpho-blue/src/libraries/ConstantsLib.sol";

/// @title Smart withdrawal using the SmartLTV suite
/// @notice This contract checks the risk level of a morpho market using the SmartLTV contract and withdraw if the risk if risk > 20
/// @dev this contract must have the allocator role on the vaults
contract SmartWithdrawal {
  using MorphoBalancesLib for IMorpho;
  using MarketParamsLib for MarketParams;
  using SharesMathLib for uint256;
  using MathLib for uint256;
  using MorphoLib for IMorpho;
  using UtilsLib for uint256;

  SmartLTV public immutable smartLTV = 0x000000;

  function SmartWithdraw(
    address vaultAddress,
    uint256 clf,
    uint256 marketIndex,
    RiskData memory riskData,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public {
    IMetaMorpho vault = IMetaMorpho(vaultAddress);
    // can only work if the msg.sender is an allocator of the vault
    require(vault.isAllocator(msg.sender), "SmartWithdraw: msg.sender is not vault allocator");
    IMorpho morpho = vault.MORPHO();
    uint256 nbMarkets = vault.withdrawQueueLength();
    Id marketId = vault.withdrawQueue(marketIndex);
    MarketParams memory marketParams = morpho.idToMarketParams(marketId);
    MarketConfig memory marketConfig = vault.config(marketId);

    uint256 beta = _getLiquidationIncentives(marketParams.lltv);
    uint256 recommendedLTV = smartLTV.ltv(
      marketParams.collateralToken,
      marketParams.loanToken,
      marketConfig.cap,
      beta,
      clf,
      riskData,
      v,
      r,
      s
    );

    if (recommendedLTV < marketParams.lltv) {
      // perform withdraw from the market
      _withdrawAllFromMarket(vault, morpho, marketParams);
    }
  }

  /// @notice Calculates the liquidation incentives based on market LTV.
  /// @param marketParamsLLTV The LTV parameter of the market.
  /// @return liquidationIncentives calculated liquidation incentives. 3% = 0.03e18
  function _getLiquidationIncentives(uint256 marketParamsLLTV) private pure returns (uint256 liquidationIncentives) {
    // The liquidation incentive factor is min(maxLiquidationIncentiveFactor, 1/(1 - cursor*(1 - lltv))).
    uint256 computedLiquidationIncentives = WAD.wDivDown(WAD - LIQUIDATION_CURSOR.wMulDown(WAD - marketParamsLLTV));

    // liquidation incentive is capped at 'MAX_LIQUIDATION_INCENTIVE_FACTOR' from the morpho constant lib
    liquidationIncentives = MAX_LIQUIDATION_INCENTIVE_FACTOR < computedLiquidationIncentives
      ? MAX_LIQUIDATION_INCENTIVE_FACTOR
      : computedLiquidationIncentives;

    // here liquidationIncentives for 15% is 1.15e18. We want 0.15e18 for the smartLTV call
    // so we substract 1 WAD from it
    liquidationIncentives -= WAD;
  }

  function _withdrawAllFromMarket(IMetaMorpho vault, IMorpho morpho, MarketParams memory marketToWithdraw) internal {
    MarketParams memory idleMarket = _getIdleMarket(vault);
    MarketAllocation[] memory allocations = new MarketAllocation[](2);
    (uint256 totalSupplyAssets, uint256 totalSupplyShares, uint256 totalBorrowAssets, ) = morpho.expectedMarketBalances(
      marketToWithdraw
    );

    uint256 supplyShares = morpho.supplyShares(marketToWithdraw.id(), address(vault));
    uint256 supplyAssets = supplyShares.toAssetsDown(totalSupplyAssets, totalSupplyShares);

    uint256 availableLiquidity = totalSupplyAssets - totalBorrowAssets;

    // withdraw max from market to withdraw
    allocations[0] = MarketAllocation({
      marketParams: marketToWithdraw,
      assets: supplyAssets.zeroFloorSub(availableLiquidity)
    });

    // supply max to idle market
    allocations[1] = MarketAllocation({marketParams: idleMarket, assets: type(uint256).max});

    vault.reallocate(allocations);
  }

  function _getIdleMarket(IMetaMorpho vault) internal view returns (MarketParams memory idleMarketParams) {
    IMorpho morpho = vault.MORPHO();
    uint256 nbMarkets = vault.withdrawQueueLength();
    for (uint256 i = 0; i < nbMarkets; i++) {
      Id marketId = vault.withdrawQueue(i);
      MarketParams memory marketParams = morpho.idToMarketParams(marketId);
      if (marketParams.collateralToken == address(0)) {
        // idle market
        idleMarketParams = marketParams;
      }
    }
  }
}
