// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import {Pythia} from "./Pythia.sol";
import {RiskyMath} from "../lib/RiskyMath.sol";

contract SmartLTV {
  Pythia immutable PYTHIA;
  address immutable TRUSTED_RELAYER;

  constructor(Pythia pythia, address relayer) {
    PYTHIA = pythia;
    TRUSTED_RELAYER = relayer;
  }

  function ltv(
    address collateralAsset,
    address debtAsset,
    uint d,
    uint beta,
    uint minClf,
    Pythia.RiskData memory riskData,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public view returns (uint) {
    // first verify the signature
    address signer = PYTHIA.getSigner(riskData, v, r, s);

    // invalid signature
    // TODO - use error objects, like the cool kids do
    require(signer == TRUSTED_RELAYER, "invalid signer");

    // timeout
    require(riskData.lastUpdate + 1 days >= block.timestamp, "timeout");

    // chain id
    require(riskData.chainId == block.chainid, "invalid chainId");

    // check collateral asset is the same
    require(
      riskData.collateralAsset == collateralAsset,
      "wrong collateral asset"
    );

    // check debt asset is the same
    require(riskData.debtAsset == debtAsset, "wrong debt asset");

    uint sigma = riskData.volatility;
    uint l = riskData.liquidity;

    // LTV  = e ^ (-c * sigma / sqrt(l/d)) - beta
    uint cTimesSigma = (minClf * sigma) / 1e18;
    uint sqrtValue = RiskyMath.sqrt((1e18 * l) / d) * 1e9;
    uint mantissa = ((1 << 59) * cTimesSigma) / sqrtValue;

    uint expResult = RiskyMath.generalExp(mantissa, 59);

    return (1e18 * (1 << 59)) / expResult - beta;
  }
}
