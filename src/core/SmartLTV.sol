// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import {Pythia} from "./Pythia.sol";
import {RiskData} from "../interfaces/RiskData.sol";
import {RiskyMath} from "../lib/RiskyMath.sol";
import {ErrorLib} from "../lib/ErrorLib.sol";

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
    RiskData memory riskData,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public view returns (uint) {
    // first verify the signature
    address signer = PYTHIA.getSigner(riskData, v, r, s);

    // invalid signature
    if (signer != TRUSTED_RELAYER) {
      revert ErrorLib.INVALID_SIGNER(signer, TRUSTED_RELAYER);
    }

    // timeout
    if (riskData.lastUpdate < block.timestamp - 1 days) {
      revert ErrorLib.TIMEOUT();
    }

    // chain id

    if (riskData.chainId != block.chainid) {
      revert ErrorLib.WRONG_CHAINID(riskData.chainId, block.chainid);
    }

    // check collateral asset is the same
    if (riskData.collateralAsset != collateralAsset) {
      revert ErrorLib.COLLATERAL_MISMATCH(
        riskData.collateralAsset,
        collateralAsset
      );
    }

    // check debt asset is the same
    if (riskData.debtAsset != debtAsset) {
      revert ErrorLib.DEBT_MISMATCH(riskData.debtAsset, debtAsset);
    }

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
