// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

/**
 * All morphos needed interface are here to simplify integration without importing full interfaces
 */

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

  function MORPHO() external view returns (IMorpho);
}

interface IMorpho {
  function market(
    Id id
  )
    external
    view
    returns (
      uint128 totalSupplyAssets,
      uint128 totalSupplyShares,
      uint128 totalBorrowAssets,
      uint128 totalBorrowShares,
      uint128 lastUpdate,
      uint128 fee
    );
}

uint256 constant MARKET_PARAMS_BYTES_LENGTH = 5 * 32;

library MorphoLib {
  function id(
    MarketParams memory marketParams
  ) internal pure returns (Id marketParamsId) {
    assembly ("memory-safe") {
      marketParamsId := keccak256(marketParams, MARKET_PARAMS_BYTES_LENGTH)
    }
  }
}
