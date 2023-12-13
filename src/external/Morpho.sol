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
  function config(Id) external view returns (uint184 cap, bool enabled, uint64 removableAt);
  function reallocate(MarketAllocation[] calldata allocations) external;
  function MORPHO() external view returns (IMorpho);
  function setIsAllocator(address newAllocator, bool newIsAllocator) external;
  function owner() external returns (address);
  function isAllocator(address target) external view returns (bool);
  function totalAssets() external view returns (uint totalManagedAssets);
}

interface IMorpho {
  /// @notice The state of the market corresponding to `id`.
  /// @dev Warning: `totalSupplyAssets` does not contain the accrued interest since the last interest accrual.
  /// @dev Warning: `totalBorrowAssets` does not contain the accrued interest since the last interest accrual.
  /// @dev Warning: `totalSupplyShares` does not contain the accrued shares by `feeRecipient` since the last interest
  /// accrual.
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

  /// @notice The state of the position of `user` on the market corresponding to `id`.
  /// @dev Warning: For `feeRecipient`, `supplyShares` does not contain the accrued shares since the last interest
  /// accrual.
  function position(
    Id id,
    address user
  ) external view returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral);

  /// @notice The market params corresponding to `id`.
  /// @dev This mapping is not used in Morpho. It is there to enable reducing the cost associated to calldata on layer
  /// 2s by creating a wrapper contract with functions that take `id` as input instead of `marketParams`.
  function idToMarketParams(
    Id id
  ) external view returns (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv);
}

uint256 constant MARKET_PARAMS_BYTES_LENGTH = 5 * 32;

library MorphoLib {
  using MathLib for uint256;
  /// @dev The number of virtual shares has been chosen low enough to prevent overflows, and high enough to ensure
  /// high precision computations.
  uint256 internal constant VIRTUAL_SHARES = 1e6;

  /// @dev A number of virtual assets of 1 enforces a conversion rate between shares and assets when a market is
  /// empty.
  uint256 internal constant VIRTUAL_ASSETS = 1;

  function id(MarketParams memory marketParams) internal pure returns (Id marketParamsId) {
    assembly ("memory-safe") {
      marketParamsId := keccak256(marketParams, MARKET_PARAMS_BYTES_LENGTH)
    }
  }

  /// @dev Calculates the value of `shares` quoted in assets, rounding down.
  function toAssetsDown(uint256 shares, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256) {
    return shares.mulDivDown(totalAssets + VIRTUAL_ASSETS, totalShares + VIRTUAL_SHARES);
  }
}

uint256 constant WAD = 1e18;
uint256 constant MAX_LIQUIDATION_INCENTIVE_FACTOR = 0.15e18;
uint256 constant LIQUIDATION_CURSOR = 0.3e18;

/// @title MathLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library to manage fixed-point arithmetic.
library MathLib {
  /// @dev Returns (`x` * `y`) / `WAD` rounded down.
  function wMulDown(uint256 x, uint256 y) internal pure returns (uint256) {
    return mulDivDown(x, y, WAD);
  }

  /// @dev Returns (`x` * `WAD`) / `y` rounded down.
  function wDivDown(uint256 x, uint256 y) internal pure returns (uint256) {
    return mulDivDown(x, WAD, y);
  }

  /// @dev Returns (`x` * `WAD`) / `y` rounded up.
  function wDivUp(uint256 x, uint256 y) internal pure returns (uint256) {
    return mulDivUp(x, WAD, y);
  }

  /// @dev Returns (`x` * `y`) / `d` rounded down.
  function mulDivDown(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
    return (x * y) / d;
  }

  /// @dev Returns (`x` * `y`) / `d` rounded up.
  function mulDivUp(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
    return (x * y + (d - 1)) / d;
  }

  /// @dev Returns the sum of the first three non-zero terms of a Taylor expansion of e^(nx) - 1, to approximate a
  /// continuous compound interest rate.
  function wTaylorCompounded(uint256 x, uint256 n) internal pure returns (uint256) {
    uint256 firstTerm = x * n;
    uint256 secondTerm = mulDivDown(firstTerm, firstTerm, 2 * WAD);
    uint256 thirdTerm = mulDivDown(secondTerm, firstTerm, 3 * WAD);

    return firstTerm + secondTerm + thirdTerm;
  }
}
