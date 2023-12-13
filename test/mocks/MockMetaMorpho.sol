// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../../src/external/Morpho.sol";
import "../../lib/forge-std/src/Test.sol";

struct ConfigData {
  uint184 cap;
  bool enabled;
  uint64 removableAt;
}

contract MockMetaMorpho is IMetaMorpho {
  IMorpho public MORPHO;
  mapping(Id => ConfigData) public configs;

  constructor(IMorpho _morpho) {
    MORPHO = _morpho;
  }

  uint256 public totalAssets = 0;

  function isAllocator(address target) external view returns (bool) {
    console.log("%s is allocator", target);
    return true;
  }

  function setIsAllocator(address newAllocator, bool newIsAllocator) external view {
    console.log("new allocator %s to %s", newAllocator, newIsAllocator);
  }

  function owner() external pure returns (address) {
    return address(1);
  }

  function setConfig(Id id, ConfigData memory configData) external {
    configs[id] = configData;
  }

  function config(Id id) external view override returns (uint184 cap, bool enabled, uint64 removableAt) {
    ConfigData memory configData = configs[id];
    return (configData.cap, configData.enabled, configData.removableAt);
  }

  function reallocate(MarketAllocation[] calldata allocations) external view override {
    console.log("reallocate called for %s allocations", allocations.length);
    // does not really reallocate markets values
  }
}
