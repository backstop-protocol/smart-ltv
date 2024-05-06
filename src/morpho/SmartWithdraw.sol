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
import {RiskData, SignedRiskData} from "../interfaces/RiskData.sol";
import {SmartLTV} from "../core/SmartLTV.sol";
import "../../lib/metamorpho/lib/morpho-blue/src/libraries/ConstantsLib.sol";

/// @title Smart Withdrawal Management
/// @notice Manages withdrawals based on risk assessments provided by the SmartLTV contract. Withdrawals are triggered when the risk level exceeds specific threshold.
/// @dev Requires allocator privileges on the associated vaults to perform withdrawals.
contract SmartWithdraw {
  using MorphoBalancesLib for IMorpho;
  using MarketParamsLib for MarketParams;
  using SharesMathLib for uint256;
  using MathLib for uint256;
  using MorphoLib for IMorpho;
  using UtilsLib for uint256;

  SmartLTV public immutable SMART_LTV;

  constructor(address smartLTV) {
    SMART_LTV = SmartLTV(smartLTV);
  }

  /// @notice Checks if the recommended Loan-to-Value (LTV) is below the market's liquidation LTV threshold.
  /// @dev This function is used by keepers to verify the risk parameters of a specific market
  /// @param vaultAddress The address of the vault where the market is located.
  /// @param maxAcceptableRiskLevel The maximum acceptable risk level for the the market.
  /// @param marketIndex The index of the market in the vault's withdrawal queue.
  /// @param signedRiskData The risk data used to calculate the recommended LTV and the signature.
  /// @return bool Returns true if the recommended LTV is below the market's liquidation LTV, false otherwise. If true, all available liquidity should be withdrawn. Also returns the recommended LTV
  function keeperCheck(
    address vaultAddress,
    uint256 maxAcceptableRiskLevel,
    uint256 marketIndex,
    SignedRiskData memory signedRiskData
  ) public view returns (bool, uint256) {
    (MarketParams memory marketParams, uint256 cap) = _getRequiredParameters(vaultAddress, marketIndex);

    uint256 recommendedLTV = SMART_LTV.ltv(
      marketParams.collateralToken,
      marketParams.loanToken,
      cap,
      _getLiquidationIncentives(marketParams.lltv),
      (1e18 * 1e18) / maxAcceptableRiskLevel,
      signedRiskData.riskData,
      signedRiskData.v,
      signedRiskData.r,
      signedRiskData.s
    );

    // if the recommended LTV is below the market's liquidation LTV, all available liquidity should be withdrawn
    return (recommendedLTV < marketParams.lltv, recommendedLTV);
  }

  function _getRequiredParameters(
    address vaultAddress,
    uint256 marketIndex
  ) internal view returns (MarketParams memory marketParams, uint256 cap) {
    IMetaMorpho vault = IMetaMorpho(vaultAddress);
    IMorpho morpho = vault.MORPHO();
    Id marketId = vault.withdrawQueue(marketIndex);
    marketParams = morpho.idToMarketParams(marketId);
    MarketConfig memory marketConfig = vault.config(marketId);
    return (marketParams, marketConfig.cap);
  }

  /// @notice Initiates the withdrawal of all available liquidity from a specified market in the vault.
  /// @dev This function can only be called by one of the vault's allocators.
  /// @param vaultAddress The address of the vault from which liquidity is to be withdrawn.
  /// @param marketIndex The index of the market in the vault's withdrawal queue.
  function keeperCall(address vaultAddress, uint256 marketIndex) public {
    IMetaMorpho vault = IMetaMorpho(vaultAddress);
    // can only work if the msg.sender is an allocator of the vault
    require(vault.isAllocator(msg.sender), "SmartWithdraw: msg.sender is not vault allocator");

    IMorpho morpho = vault.MORPHO();
    Id marketId = vault.withdrawQueue(marketIndex);
    MarketParams memory marketParams = morpho.idToMarketParams(marketId);

    _withdrawAllFromMarket(vault, morpho, marketParams);
  }

  /// @notice Calculates the liquidation incentives based on market LTV.
  /// @param marketParamsLLTV The LTV parameter of the market.
  /// @return liquidationIncentives calculated liquidation incentives. example: 3% = 0.03e18
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

  /// @notice Withdraws all available liquidity from a specified market and reallocates it the idle market.
  /// @param vault The vault contract from which assets are withdrawn.
  /// @param morpho The Morpho contract used to interact with the market.
  /// @param marketToWithdraw The market parameters from which all available liquidity is to be withdrawn.
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

  /// @notice Finds the idle market in the vault.
  /// @param vault The vault contract from which the idle market is to be found.
  /// @return idleMarketParams The parameters of the idle market.
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
