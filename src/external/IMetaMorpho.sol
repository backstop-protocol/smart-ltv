// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

struct MarketAllocation {
  /// @notice The market to allocate.
  MarketParams marketParams;
  /// @notice The amount of assets to allocate.
  uint256 assets;
}

struct MarketParams {
  address loanToken;
  address collateralToken;
  address oracle;
  address irm;
  uint256 lltv;
}

type Id is bytes32;

interface IMetaMorpho {
  function config(
    Id
  ) external view returns (uint184 cap, bool enabled, uint64 removableAt);

  function reallocate(MarketAllocation[] calldata allocations) external;
}
