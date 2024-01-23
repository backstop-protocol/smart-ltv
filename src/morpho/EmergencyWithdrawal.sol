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

contract EmergencyWithdrawal {
  using MorphoBalancesLib for IMorpho;
  using MarketParamsLib for MarketParams;
  using SharesMathLib for uint256;
  using MathLib for uint256;
  using MorphoLib for IMorpho;
  using UtilsLib for uint256;

  IMetaMorpho public immutable ETH_VAULT = IMetaMorpho(0x38989BBA00BDF8181F4082995b3DEAe96163aC5D);
  IMetaMorpho public immutable USDC_VAULT = IMetaMorpho(0x186514400e52270cef3D80e1c6F8d10A75d47344);

  function withdrawETH() public {
    withdrawMaxToIdle(ETH_VAULT);
  }

  function withdrawUSDC() public {
    withdrawMaxToIdle(USDC_VAULT);
  }

  function withdrawMaxToIdle(IMetaMorpho vault) private {
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

    // last allocation is the uint max to the idle market
    allocations[allocationCounter] = MarketAllocation({marketParams: idleMarketPrm, assets: type(uint256).max});

    vault.reallocate(allocations);
  }
}
