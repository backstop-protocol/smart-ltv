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

/// @title Emergency Withdrawal Contract
/// @notice This contract allows for the withdrawal of assets from all non-idle markets to the idle market in case of an emergency.
/// It uses various libraries from the MetaMorpho protocol for interacting with the vaults and computing correct values
/// Can only be called by a vault allocator to withdraw the maximum amount from all non-idle markets
/// @dev this contract must have the allocator role on the vaults
contract EmergencyWithdrawal {
  using MorphoBalancesLib for IMorpho;
  using MarketParamsLib for MarketParams;
  using SharesMathLib for uint256;
  using MathLib for uint256;
  using MorphoLib for IMorpho;
  using UtilsLib for uint256;

  // Addresses for the ETH and USDC Metamorpho vaults in the Morpho protocol.
  address public immutable ETH_VAULT = 0x38989BBA00BDF8181F4082995b3DEAe96163aC5D;
  address public immutable USDC_VAULT = 0x186514400e52270cef3D80e1c6F8d10A75d47344;

  /// @notice Withdraws the maximum possible assets from the ETH vault non-idle markets to the idle market.
  /// @dev Calls `withdrawMaxToIdle` with the ETH vault.
  function withdrawETH() public {
    withdrawMaxToIdle(ETH_VAULT);
  }

  /// @notice Withdraws the maximum possible assets from the USDC vault non-idle markets to the idle market.
  /// @dev Calls `withdrawMaxToIdle` with the USDC vault.
  function withdrawUSDC() public {
    withdrawMaxToIdle(USDC_VAULT);
  }

  /// @notice internal function allowing to withdraw the maximum possible assets from a specified vault to an idle market.
  /// @param vaultAddress The MetaMorpho vault address from which assets are to be withdrawn.
  /// Requires that the caller is an allocator for the specified vault.
  /// Reallocates funds from various markets to the idle market.
  /// @dev it assumes that there is only one idle market in the vault queue
  /// @dev this function is public to allow calling for any vault address
  function withdrawMaxToIdle(address vaultAddress) public {
    IMetaMorpho vault = IMetaMorpho(vaultAddress);
    // can only work is the msg.sender is an allocator of the vault
    require(vault.isAllocator(msg.sender), "EmergencyWithdrawal: msg.sender is not vault allocator");
    IMorpho morpho = vault.MORPHO();
    uint256 nbMarkets = vault.withdrawQueueLength();
    MarketParams memory idleMarketPrm;
    MarketAllocation[] memory allocations = new MarketAllocation[](nbMarkets);

    uint256 allocationCounter = 0;
    for (uint256 i = 0; i < nbMarkets; i++) {
      Id marketId = vault.withdrawQueue(i);
      MarketParams memory marketParams = morpho.idToMarketParams(marketId);
      if (marketParams.collateralToken == address(0)) {
        // idle market
        idleMarketPrm = marketParams;
      } else {
        (uint256 totalSupplyAssets, uint256 totalSupplyShares, uint256 totalBorrowAssets, ) = morpho
          .expectedMarketBalances(marketParams);

        uint256 supplyShares = morpho.supplyShares(marketParams.id(), address(vault));
        uint256 supplyAssets = supplyShares.toAssetsDown(totalSupplyAssets, totalSupplyShares);

        uint256 availableLiquidity = totalSupplyAssets - totalBorrowAssets;

        allocations[allocationCounter] = MarketAllocation({
          marketParams: marketParams,
          assets: supplyAssets.zeroFloorSub(availableLiquidity)
        });

        allocationCounter++;
      }
    }

    // last allocation is the uint max to the idle market, meaning all that is withdrawn in the previous allocations
    // will be sent to the idle market
    allocations[allocationCounter] = MarketAllocation({marketParams: idleMarketPrm, assets: type(uint256).max});

    // finally, call the reallocate with the allocations
    // allocations should always be: 1 allocation per non-idle market (should all be withdraws)
    // and exactly 1 allocation to the idle market with uint.max as the target supply
    vault.reallocate(allocations);
  }
}
