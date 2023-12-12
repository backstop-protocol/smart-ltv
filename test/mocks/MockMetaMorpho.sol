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
