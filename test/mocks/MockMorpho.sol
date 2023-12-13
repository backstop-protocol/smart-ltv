// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../../src/external/Morpho.sol";

struct MarketInfo {
  uint128 totalSupplyAssets;
  uint128 totalSupplyShares;
  uint128 totalBorrowAssets;
  uint128 totalBorrowShares;
  uint128 lastUpdate;
  uint128 fee;
}

struct PositionInfo {
  uint256 supplyShares;
  uint128 borrowShares;
  uint128 collateral;
}

contract MockMorpho is IMorpho {
  // Mock state variables
  mapping(Id => MarketInfo) public marketInfos;
  mapping(Id => mapping(address => PositionInfo)) public positionInfos;

  // Setters for mock data
  function setMarketInfo(Id marketId, MarketInfo memory marketInfo) external {
    marketInfos[marketId] = marketInfo;
  }

  function setPositionInfo(Id marketId, address user, PositionInfo memory positionInfo) external {
    positionInfos[marketId][user] = positionInfo;
  }

  function idToMarketParams(
    Id /*id*/
  ) external pure returns (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv) {
    loanToken = address(0);
    collateralToken = address(0);
    oracle = address(0);
    irm = address(0);
    lltv = 0;
  }

  // Mock implementation of IMorpho interface methods
  function market(
    Id id
  )
    external
    view
    override
    returns (
      uint128 totalSupplyAssets,
      uint128 totalSupplyShares,
      uint128 totalBorrowAssets,
      uint128 totalBorrowShares,
      uint128 lastUpdate,
      uint128 fee
    )
  {
    MarketInfo memory mInfo = marketInfos[id];
    return (
      mInfo.totalSupplyAssets,
      mInfo.totalSupplyShares,
      mInfo.totalBorrowAssets,
      mInfo.totalBorrowShares,
      mInfo.lastUpdate,
      mInfo.fee
    );
  }

  function position(
    Id id,
    address user
  ) external view override returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral) {
    PositionInfo memory pInfo = positionInfos[id][user];
    return (pInfo.supplyShares, pInfo.borrowShares, pInfo.collateral);
  }
}
