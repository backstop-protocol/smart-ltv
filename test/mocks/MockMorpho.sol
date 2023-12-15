// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../../lib/morpho-blue/src/interfaces/IMorpho.sol";

contract MockMorpho is IMorpho {
  // Mock state variables
  mapping(Id => Market) public marketInfos;
  mapping(Id => mapping(address => Position)) public positionInfos;

  // Setters for mock data
  function setMarketInfo(Id marketId, Market memory marketInfo) external {
    marketInfos[marketId] = marketInfo;
  }

  function setPositionInfo(Id marketId, address user, Position memory positionInfo) external {
    positionInfos[marketId][user] = positionInfo;
  }

  function position(Id id, address user) external view returns (Position memory p) {
    return positionInfos[id][user];
  }

  function market(Id id) external view returns (Market memory m) {
    return marketInfos[id];
  }

  function idToMarketParams(Id id) external view returns (MarketParams memory) {
    return
      MarketParams({loanToken: address(0), collateralToken: address(0), oracle: address(0), irm: address(0), lltv: 0});
  }
}
