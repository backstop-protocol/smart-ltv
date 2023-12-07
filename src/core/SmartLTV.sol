// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import {Pythia} from "./Pythia.sol";
import {RiskData} from "../interfaces/RiskData.sol";
import {RiskyMath} from "../lib/RiskyMath.sol";
import {ErrorLib} from "../lib/ErrorLib.sol";

/// @title Smart Loan-to-Value (LTV) Calculation Contract
/// @author bprotocol
/// @notice This contract calculates the Loan-to-Value (LTV) ratio based on market and risk data.
/// @dev The contract utilizes the Pythia contract for data verification and the RiskyMath library for mathematical operations.
contract SmartLTV {
  /// @notice Address of the Pythia contract used for signature verification
  Pythia immutable PYTHIA;

  /// @notice Address of the trusted relayer for verifying data authenticity
  address immutable TRUSTED_RELAYER;

  /// @notice Initializes the SmartLTV contract with Pythia and TRUSTED_RELAYER addresses.
  /// @param pythia The Pythia contract address used for data verification.
  /// @param relayer The address of the trusted relayer.
  constructor(Pythia pythia, address relayer) {
    PYTHIA = pythia;
    TRUSTED_RELAYER = relayer;
  }

  /// @notice Calculates the Loan-to-Value ratio based on provided market conditions and risk data.
  /// @dev The function performs signature verification, time and chain ID checks, asset matching, and then calculates LTV.
  ///      It reverts in case of signature mismatch, data timeout, wrong chain ID, or asset mismatches.
  /// @param collateralAsset Address of the collateral asset.
  /// @param debtAsset Address of the debt asset.
  /// @param d the supply cap, used in LTV calculation.
  /// @param beta The liquidation bonus, used in the LTV calculation.
  /// @param minClf The min confidence level factor targeted
  /// @param riskData Struct containing various risk parameters like volatility, liquidity, last update time, and chain ID.
  /// @param v Component of the Ethereum signature
  /// @param r Component of the Ethereum signature
  /// @param s Component of the Ethereum signature
  /// @return The calculated Loan-to-Value ratio.
  /// @custom:revert INVALID_SIGNER If the signature verification fails.
  /// @custom:revert TIMEOUT If the risk data is older than 1 day.
  /// @custom:revert WRONG_CHAINID If the risk data chain ID does not match the current chain.
  /// @custom:revert COLLATERAL_MISMATCH If the collateral asset in risk data does not match the provided collateral asset.
  /// @custom:revert DEBT_MISMATCH If the debt asset in risk data does not match the provided debt asset.
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
