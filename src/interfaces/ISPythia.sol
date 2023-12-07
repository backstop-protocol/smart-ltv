// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

struct RiskData {
  address collateralAsset;
  address debtAsset;
  uint256 liquidity;
  uint256 volatility;
  uint256 lastUpdate;
  uint256 chainId;
}

struct Signature {
  uint8 v;
  bytes32 r;
  bytes32 s;
}

interface ISPythia {
  function getSigner(
    RiskData memory data,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external returns (address);
}
