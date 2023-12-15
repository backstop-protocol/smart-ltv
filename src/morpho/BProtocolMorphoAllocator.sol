// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import {RiskData, Signature} from "../interfaces/RiskData.sol";
import {SmartLTV} from "../core/SmartLTV.sol";
import {RiskyMath} from "../lib/RiskyMath.sol";
import {ErrorLib} from "../lib/ErrorLib.sol";
import {IMetaMorpho, MarketAllocation, Id, MarketConfig} from "../../lib/metamorpho/src/interfaces/IMetaMorpho.sol";
import {MathLib, WAD} from "../../lib/metamorpho/lib/morpho-blue/src/libraries/MathLib.sol";
import {SharesMathLib} from "../../lib/metamorpho/lib/morpho-blue/src/libraries/SharesMathLib.sol";
import {Market, Position} from "../../lib/metamorpho/lib/morpho-blue/src/interfaces/IMorpho.sol";
import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {MarketParamsLib, MarketParams} from "../../lib/metamorpho/lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import "../../lib/metamorpho/lib/morpho-blue/src/libraries/ConstantsLib.sol";

/// @title BProtocol Morpho Allocator Contract
/// @author bprotocol, la-tribu.xyz
/// @notice This contract is responsible for reallocating market allocations while checking risk data before reallocating.
///         It interacts with the SmartLTV and a MetaMorpho Vault to manage these allocations.
///         It needs to have the Allocator role in the MetaMorpho vault
/// @dev The contract uses immutable state variables for SmartLTV, trusted relayer, and MetaMorpho Vault addresses.
///      It includes functionality to check allocation risks and perform reallocation based on these assessments.
contract BProtocolMorphoAllocator is Ownable {
  using MathLib for uint256;

  /// @notice The SmartLTV contract used for loan-to-value calculations
  SmartLTV public immutable SMART_LTV;

  /// @notice The MetaMorpho Vault contract address for market allocations
  IMetaMorpho public immutable METAMORPHO_VAULT;

  /// @notice A predefined constant representing the minimum confidence level factor
  uint256 public immutable MIN_CLF = 3e18;

  constructor(SmartLTV smartLTV, address morphoVaultAddress, address initialOwner) Ownable(initialOwner) {
    SMART_LTV = smartLTV;
    METAMORPHO_VAULT = IMetaMorpho(morphoVaultAddress);
  }

  /// @notice Checks and reallocates market allocations based on the provided risk data and signatures.
  /// @dev Performs checks on array lengths for allocations, risk data, and signatures, and then
  ///      calls `_checkAllocationRisk` for each allocation. Finally, it calls `reallocate` on the MetaMorpho Vault.
  /// @param allocations Array of market allocations.
  /// @param riskDatas Array of risk data corresponding to each market allocation.
  /// @param signatures Array of signatures corresponding to each risk data entry.
  /// @custom:revert INVALID_RISK_DATA_COUNT If the length of allocations and riskDatas arrays do not match.
  /// @custom:revert INVALID_SIGNATURE_COUNT If the length of riskDatas and signatures arrays do not match.
  function checkAndReallocate(
    MarketAllocation[] calldata allocations,
    RiskData[] calldata riskDatas,
    Signature[] calldata signatures
  ) external onlyOwner {
    if (allocations.length != riskDatas.length) {
      revert ErrorLib.INVALID_RISK_DATA_COUNT(allocations.length, riskDatas.length);
    }

    if (riskDatas.length != signatures.length) {
      revert ErrorLib.INVALID_SIGNATURE_COUNT(riskDatas.length, signatures.length);
    }

    for (uint256 i = 0; i < allocations.length; i++) {
      _checkAllocation(allocations[i], riskDatas[i], signatures[i]);
    }

    // call reallocate
    METAMORPHO_VAULT.reallocate(allocations);
  }

  /// @notice Internal function to check an individual allocation's risk and compliance.
  /// @param allocation The market allocation to be checked.
  /// @param riskData The risk data associated with the allocation.
  /// @param signature The signature for verification.
  function _checkAllocation(
    MarketAllocation memory allocation,
    RiskData memory riskData,
    Signature memory signature
  ) internal view {
    // find the market Id for this allocation
    Id marketId = MarketParamsLib.id(allocation.marketParams);

    // get the market infos from morpho blue contract
    Market memory m = METAMORPHO_VAULT.MORPHO().market(marketId);

    if (allocation.marketParams.collateralToken != address(0)) {
      // only check risk if collateral is not address(0)
      // address(0) for collateral means it's an idle market ==> without risks
      if (!_isWithdraw(marketId, allocation.assets, m.totalSupplyAssets, m.totalSupplyShares)) {
        // only check risk if not withdraw
        // because we want to allow withdraw for a risky market
        uint256 currentCap = _getCurrentCap(marketId, m.totalSupplyAssets);
        _checkAllocationRisk(currentCap, allocation.marketParams.lltv, riskData, signature);
      }
    }
  }

  /// @notice Determines if an allocation is a withdrawal based on market ID and asset amounts.
  /// @param marketId The market ID.
  /// @param allocationAssets The amount of assets allocated.
  /// @param totalSupplyAsset The total supply of assets in the market.
  /// @param totalSupplyShares The total supply shares in the market.
  /// @return isWithdraw True if the operation is a withdrawal.
  function _isWithdraw(
    Id marketId,
    uint256 allocationAssets,
    uint128 totalSupplyAsset,
    uint128 totalSupplyShares
  ) internal view returns (bool isWithdraw) {
    // if allocation assets is zero, consider withdraw by default
    if (allocationAssets == 0) {
      return true;
    }
    // get the vault supply for the market
    uint256 currentVaultMarketSupply = _getVaultMarketSupply(marketId, totalSupplyAsset, totalSupplyShares);

    // if the targeted allocation (allocationAssets) is less than the current vault market supply
    // it means we will withdraw liquidity from this market
    isWithdraw = allocationAssets < currentVaultMarketSupply;
  }

  /// @notice Retrieves the current supply of assets for a specific market in the vault.
  /// @param marketId The market ID.
  /// @param totalSupplyAssets The total supply of assets in the market.
  /// @param totalSupplyShares The total supply shares in the market.
  /// @dev this does not call the accrue interest function, maybe we should do it
  /// @return currentVaultMarketSupply The current asset supply for the specified market.
  function _getVaultMarketSupply(
    Id marketId,
    uint128 totalSupplyAssets,
    uint128 totalSupplyShares
  ) internal view returns (uint256) {
    Position memory p = METAMORPHO_VAULT.MORPHO().position(marketId, address(METAMORPHO_VAULT));

    uint256 currentVaultMarketSupply = SharesMathLib.toAssetsDown(p.supplyShares, totalSupplyAssets, totalSupplyShares);
    return currentVaultMarketSupply;
  }

  /// @notice Retrieves the current cap for a specific market.
  /// @dev the current cap is defined as being the max between the metamorpho cap and the morpho blue market current total supply
  /// @param marketId The market ID.
  /// @param totalSupplyAsset The total supply of assets in the market.
  /// @return d The current cap for the market.
  function _getCurrentCap(Id marketId, uint256 totalSupplyAsset) private view returns (uint256 d) {
    MarketConfig memory config = METAMORPHO_VAULT.config(marketId);
    // the cap d is the max between vault cap and total supply asset of the morpho market
    d = config.cap >= totalSupplyAsset ? config.cap : totalSupplyAsset; // supplyCap
  }

  /// @notice Checks the allocation risk based on market configuration and provided risk data.
  /// @dev Retrieves market configuration and current supply from the vault to calculate the recommended LTV.
  ///      It then compares the current market LTV with the recommended LTV and reverts if the current LTV is higher.
  /// @param currentCap The market current cap, computed as the max between vault cap and current market supply.
  /// @param marketLLTV The market lltv, which will be checked against the SmartLTV recommendation.
  /// @param riskData Risk data associated with the market allocation, including collateral and debt assets.
  /// @param signature The signature used for verification in LTV calculation.
  /// @custom:revert LTV_TOO_HIGH If the current LTV (Loan-to-Value) is higher than the recommended LTV by the SmartLTV contract.
  function _checkAllocationRisk(
    uint256 currentCap,
    uint256 marketLLTV,
    RiskData memory riskData,
    Signature memory signature
  ) private view {
    uint256 beta = _getLiquidationIncentives(marketLLTV);

    uint recommendedLtv = SMART_LTV.ltv(
      riskData.collateralAsset,
      riskData.debtAsset,
      currentCap,
      beta,
      MIN_CLF,
      riskData,
      signature.v,
      signature.r,
      signature.s
    );

    // check if the current ltv is lower or equal to the recommended ltv
    if (marketLLTV > recommendedLtv) {
      revert ErrorLib.LTV_TOO_HIGH(marketLLTV, recommendedLtv);
    }
  }

  /// @notice Calculates the liquidation incentives based on market LTV.
  /// @param marketParamsLLTV The LTV parameter of the market.
  /// @return The calculated liquidation incentives.
  function _getLiquidationIncentives(uint256 marketParamsLLTV) private pure returns (uint256) {
    // The liquidation incentive factor is min(maxLiquidationIncentiveFactor, 1/(1 - cursor*(1 - lltv))).
    uint256 computedLiquidationIncentives = WAD.wDivDown(WAD - LIQUIDATION_CURSOR.wMulDown(WAD - marketParamsLLTV)) -
      WAD;

    if (MAX_LIQUIDATION_INCENTIVE_FACTOR < computedLiquidationIncentives) {
      return MAX_LIQUIDATION_INCENTIVE_FACTOR;
    } else {
      return computedLiquidationIncentives;
    }
  }
}
