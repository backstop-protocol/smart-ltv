// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import {RiskData, Signature} from "../interfaces/RiskData.sol";
import {SmartLTV} from "../core/SmartLTV.sol";
import {IMetaMorpho, MarketAllocation, Id, MarketParams, IMorpho, MathLib, WAD, MAX_LIQUIDATION_INCENTIVE_FACTOR, LIQUIDATION_CURSOR} from "../external/Morpho.sol";
import {RiskyMath} from "../lib/RiskyMath.sol";
import {MorphoLib} from "../external/Morpho.sol";
import {ErrorLib} from "../lib/ErrorLib.sol";

/*  
USDC/sDAI
marketid 0x7a9e4757d1188de259ba5b47f4c08197f821e54109faa5b0502b9dfe2c10b741
loanToken   address :  0x62bD2A599664D421132d7C54AB4DbE3233f4f0Ae
  collateralToken   address :  0xD8134205b0328F5676aaeFb3B2a0DC15f4029d8C
  oracle   address :  0xc1466Cc7e9ace925fA54398f99D2277a571A7a0a
  irm   address :  0x9ee101eB4941d8D7A665fe71449360CEF3C8Bb87
  lltv   uint256 :  900000000000000000
  
  
USDC/USDT
marketid: 0xbc6d1789e6ba66e5cd277af475c5ed77fcf8b084347809d9d92e400ebacbdd10
  loanToken   address :  0x62bD2A599664D421132d7C54AB4DbE3233f4f0Ae
  collateralToken   address :  0x576e379FA7B899b4De1E251e935B31543Df3e954
  oracle   address :  0x095613a8C57a294E43E2bb5B62D628D8C8B00dAA
  irm   address :  0x9ee101eB4941d8D7A665fe71449360CEF3C8Bb87
  lltv   uint256 :  900000000000000000
*/

/// @title BProtocol Morpho Allocator Contract
/// @author bprotocol, la-tribu.xyz
/// @notice This contract is responsible for reallocating market allocations while checking risk data before reallocating.
///         It interacts with the SmartLTV and a MetaMorpho Vault to manage these allocations.
///         It needs to have the Allocator role in the MetaMorpho vault
/// @dev The contract uses immutable state variables for SmartLTV, trusted relayer, and MetaMorpho Vault addresses.
///      It includes functionality to check allocation risks and perform reallocation based on these assessments.
contract BProtocolMorphoAllocator {
  using MathLib for uint256;

  /// @notice The SmartLTV contract used for loan-to-value calculations
  SmartLTV immutable SMART_LTV;

  /// @notice The MetaMorpho Vault contract address for market allocations
  IMetaMorpho immutable METAMORPHO_VAULT;

  /// @notice A predefined constant representing the minimum collateralization liquidation factor
  uint256 immutable MIN_CLF = 3;

  constructor(SmartLTV smartLTV, address morphoVaultAddress) {
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
  ) external {
    if (allocations.length != riskDatas.length) {
      revert ErrorLib.INVALID_RISK_DATA_COUNT(allocations.length, riskDatas.length);
    }

    if (riskDatas.length != signatures.length) {
      revert ErrorLib.INVALID_SIGNATURE_COUNT(riskDatas.length, signatures.length);
    }

    for (uint256 i = 0; i < allocations.length; i++) {
      MarketAllocation memory allocation = allocations[i];

      // find the market Id for this allocation
      Id marketId = MorphoLib.id(allocation.marketParams);

      // get the market infos from morpho blue contract
      (uint128 totalSupplyAssets, uint128 totalSupplyShares, , , , ) = METAMORPHO_VAULT.MORPHO().market(marketId);

      if (!_isWithdraw(marketId, allocation.assets, totalSupplyAssets, totalSupplyShares)) {
        // only check risk if not withdraw
        // because we want to allow withdraw for a risky market
        uint256 currentCap = _getCurrentCap(marketId, totalSupplyAssets);
        _checkAllocationRisk(currentCap, allocation.marketParams.lltv, riskDatas[i], signatures[i]);
      }
    }

    // call reallocate
    METAMORPHO_VAULT.reallocate(allocations);
  }

  function _isWithdraw(
    Id marketId,
    uint256 allocationAssets,
    uint128 totalSupplyAsset,
    uint128 totalSupplyShares
  ) internal view returns (bool isWithdraw) {
    // get the vault supply for the market
    uint256 currentVaultMarketSupply = _getVaultMarketSupply(marketId, totalSupplyAsset, totalSupplyShares);

    // if the targeted allocation (allocationAssets) is less than the current vault market supply
    // it means we will withdraw liquidity from this market
    isWithdraw = allocationAssets < currentVaultMarketSupply;
  }

  function _getVaultMarketSupply(
    Id marketId,
    uint128 totalSupplyAssets,
    uint128 totalSupplyShares
  ) internal view returns (uint256) {
    (uint256 supplyShare, , ) = METAMORPHO_VAULT.MORPHO().position(marketId, address(METAMORPHO_VAULT));

    uint256 currentVaultMarketSupply = MorphoLib.toAssetsDown(supplyShare, totalSupplyAssets, totalSupplyShares);
    return currentVaultMarketSupply;
  }

  function _getCurrentCap(Id marketId, uint256 totalSupplyAsset) private view returns (uint256 d) {
    (uint184 cap, , ) = METAMORPHO_VAULT.config(marketId);
    // the cap d is the max between vault cap and total supply asset of the morpho market
    d = cap >= totalSupplyAsset ? cap : totalSupplyAsset; // supplyCap
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
