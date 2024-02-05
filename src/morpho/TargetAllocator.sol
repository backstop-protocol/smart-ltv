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

contract TargetAllocator {
  using MorphoBalancesLib for IMorpho;
  using MarketParamsLib for MarketParams;
  using SharesMathLib for uint256;
  using MathLib for uint256;
  using MorphoLib for IMorpho;
  using UtilsLib for uint256;

  struct TargetAllocation {
    uint64 maxUtilization; // percentage with 18 decimals. Max = ~1844% with uint64
    uint64 targetUtilization; // percentage with 18 decimals. Max = ~1844%  with uint64
    uint64 minUtilization; // percentage with 18 decimals. Max = ~1844% with uint64
    uint256 minLiquidity; // absolute amount in wei
  }

  /// @notice this is the idle market from/to which we will reallocate
  Id public immutable IDLE_MARKET_ID;

  address public immutable VAULT_ADDRESS;

  IMorpho public immutable MORPHO;

  uint256 public lastReallocationTimestamp;

  // TODO setter
  uint256 public minDelayBetweenReallocations;

  // TODO setter
  mapping(Id => TargetAllocation) public targetAllocations;

  // TODO setter
  uint256 public minReallocationSize;

  // TODO setter
  address public keeperAddress;

  constructor(
    bytes32 _idleMarketId,
    address _vault,
    uint256 _minDelayBetweenReallocations,
    uint256 _minReallocationSize,
    address _keeperAddress,
    bytes32[] memory _marketIds,
    TargetAllocation[] memory _targetAllocations
  ) {
    require(
      _marketIds.length == _targetAllocations.length,
      "TargetAllocator: length mismatch [_marketIds, _targetAllocations]"
    );

    IDLE_MARKET_ID = Id.wrap(_idleMarketId);
    VAULT_ADDRESS = _vault;
    MORPHO = IMetaMorpho(VAULT_ADDRESS).MORPHO();
    minDelayBetweenReallocations = _minDelayBetweenReallocations;
    lastReallocationTimestamp = 1; // initialize storage slot to cost less for next usage
    minReallocationSize = _minReallocationSize;
    keeperAddress = _keeperAddress;

    for (uint256 i = 0; i < _marketIds.length; ) {
      targetAllocations[Id.wrap(_marketIds[i])] = _targetAllocations[i];

      // use less gas
      unchecked {
        ++i;
      }
    }
  }

  function checkReallocationNeeded() public view returns (bool, MarketAllocation[] memory) {
    uint256 nbMarkets = IMetaMorpho(VAULT_ADDRESS).withdrawQueueLength();

    MarketParams memory idleMarketParams = MORPHO.idToMarketParams(IDLE_MARKET_ID);
    uint256 idleAssetsAvailable = 0;
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

    TargetAllocation memory targetAllocation = targetAllocations[marketId];

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
      marketAllocations[0] = MarketAllocation({marketParams: idleMarketParams, assets: amountToSupply});
      // create allocation: supply all withdrawn to market
      marketAllocations[1] = MarketAllocation({marketParams: marketParams, assets: type(uint256).max});

      return (true, marketAllocations);
    } else if (currentUtilization < targetAllocation.minUtilization) {
      // utilization < min target utilization, we should withdraw to the idle market

      // Keep at least targetAllocation.minLiquidity available
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
      marketAllocations[0] = MarketAllocation({marketParams: marketParams, assets: amountToWithdraw});
      // create allocation: supply all withdrawn to idle market
      marketAllocations[1] = MarketAllocation({marketParams: idleMarketParams, assets: type(uint256).max});

      return (true, marketAllocations);
    }

    return (false, marketAllocations);
  }

  function keeperCheck() public view returns (bool, bytes memory call) {
    if (lastReallocationTimestamp + minDelayBetweenReallocations > block.timestamp) {
      return (false, call);
    }

    (bool mustReallocate, MarketAllocation[] memory allocations) = checkReallocationNeeded();

    if (mustReallocate) {
      call = abi.encodeCall(IMetaMorphoBase.reallocate, allocations);
      return (true, call);
    }

    // return false for the gelato bot
    return (false, call);
  }

  function keeperCall(bytes calldata call) external {
    require(msg.sender == keeperAddress || isVaultAllocator(msg.sender), "TargetAllocator: caller not allowed");

    (bool success, bytes memory result) = VAULT_ADDRESS.call(call);
    if (success) {
      lastReallocationTimestamp = block.timestamp;
    } else {
      _getRevertMsg(result);
    }
  }

  function isVaultAllocator(address sender) public view returns (bool) {
    return IMetaMorpho(VAULT_ADDRESS).isAllocator(sender);
  }

  error CallError(bytes innerError);

  /// @dev Extracts a revert message from failed call return data.
  /// @param _returnData The return data from the failed call.
  function _getRevertMsg(bytes memory _returnData) internal pure {
    // If the _res length is less than 68, then
    // the transaction failed with custom error or silently (without a revert message)
    if (_returnData.length < 68) {
      revert CallError(_returnData);
    }

    assembly {
      // Slice the sighash.
      _returnData := add(_returnData, 0x04)
    }
    revert(abi.decode(_returnData, (string))); // All that remains is the revert string
  }
}
