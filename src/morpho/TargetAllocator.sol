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

  /// @notice this is the idle market from/to which we will reallocate, set in the ctor
  Id public immutable IDLE_MARKET_ID;

  /// @notice the metamorpho vault address, set in the ctor
  address public immutable VAULT_ADDRESS;

  /// @notice the Morpho blue contract, set in the ctor
  IMorpho public immutable MORPHO;

  /// @notice the last reallocation performed by the keeperCall function
  uint256 public lastReallocationTimestamp;

  /// @notice the minimum delay between two reallocation by the keeperCall function
  uint256 public minDelayBetweenReallocations;

  /// @notice mapping of marketId => target allocation parameters
  /// set in the constructor but can be modified by any of the vault allocators
  mapping(Id => TargetAllocation) public targetAllocations;

  /// @notice the minimum reallocation size, used to not broadcast a transaction for moving dust amount of an asset
  uint256 public minReallocationSize;

  /// @notice the keeper (bot) address that will be used to automatically call the keeperCheck and keeperCall functions
  address public keeperAddress;

  /// @notice Initializes a new TargetAllocator contract with specific market target allocations and operational settings.
  /// @param _idleMarketId The market identifier for the idle market.
  /// @param _vault The address of the Morpho vault.
  /// @param _minDelayBetweenReallocations The minimum delay between two reallocation actions.
  /// @param _minReallocationSize The minimum size of assets to be considered for reallocation.
  /// @param _keeperAddress The address of the keeper responsible for triggering reallocations.
  /// @param _marketIds An array of market identifiers for which target allocations are being set.
  /// @param _targetAllocations An array of target allocation settings corresponding to the market identifiers.
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

  /** ONLY ALLOCATORS SETTER FUNCTIONS */

  /// @notice Sets the minimum delay between reallocations.
  /// @param _newValue The new minimum delay value in seconds.
  function SetMinDelayBetweenReallocations(uint256 _newValue) external {
    require(isVaultAllocator(msg.sender), "TargetAllocator: caller not allowed");
    minDelayBetweenReallocations = _newValue;
  }

  /// @notice Sets the minimum size for reallocations to avoid transactions for negligible amounts.
  /// @param _newValue The new minimum reallocation size in the asset's smallest unit.
  function SetMinReallocationSize(uint256 _newValue) external {
    require(isVaultAllocator(msg.sender), "TargetAllocator: caller not allowed");
    minReallocationSize = _newValue;
  }

  /// @notice Sets the keeper address responsible for triggering reallocations.
  /// @param _newValue The new address of the keeper.
  function SetKeeperAddress(address _newValue) external {
    require(isVaultAllocator(msg.sender), "TargetAllocator: caller not allowed");
    keeperAddress = _newValue;
  }

  /// @notice Sets target allocation parameters for a given market.
  /// @param marketId The market identifier for which to set the target allocation.
  /// @param targetAllocation The target allocation parameters including max, target, and min utilization percentages, and min liquidity.
  function SetTargetAllocation(bytes32 marketId, TargetAllocation memory targetAllocation) external {
    require(isVaultAllocator(msg.sender), "TargetAllocator: caller not allowed");
    targetAllocations[Id.wrap(marketId)] = targetAllocation;
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
      marketAllocations[0] = MarketAllocation({marketParams: marketParams, assets: amountToWithdraw});
      // create allocation: supply all withdrawn to idle market
      marketAllocations[1] = MarketAllocation({marketParams: idleMarketParams, assets: type(uint256).max});

      return (true, marketAllocations);
    }

    return (false, marketAllocations);
  }

  /** KEEPER FUNCTIONS */

  /// @notice Checks if a reallocation action is necessary and returns the encoded call data to perform the reallocation if so.
  /// @return bool Indicates if a reallocation action should be taken.
  /// @return call The encoded call data to execute the reallocation.
  function keeperCheck() external view returns (bool, bytes memory call) {
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

  /// @notice Executes a reallocation action based on call data provided by the keeperCheck function.
  /// @param call The encoded call data for the reallocation action.
  function keeperCall(bytes calldata call) external {
    require(msg.sender == keeperAddress || isVaultAllocator(msg.sender), "TargetAllocator: caller not allowed");

    (bool success, bytes memory result) = VAULT_ADDRESS.call(call);
    if (success) {
      lastReallocationTimestamp = block.timestamp;
    } else {
      _getRevertMsg(result);
    }
  }

  /// @notice Checks if the sender is an authorized vault allocator.
  /// @param sender The address to check.
  /// @return bool Indicates if the address is an authorized allocator.
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
