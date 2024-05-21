// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

/**
 * @title Error Library for Custom Errors
 * @author bprotocol, la-tribu.xyz
 * @notice defines custom errors used across the contracts of this repository
 */
library ErrorLib {
  /// @notice Error for mismatch in the count of risk data entries.
  /// @param a The count of market allocations.
  /// @param b The count of risk data entries.
  error INVALID_RISK_DATA_COUNT(uint256 a, uint256 b);

  /// @notice Error for mismatch in the count of signatures.
  /// @param a The count of risk data entries.
  /// @param b The count of signatures.
  error INVALID_SIGNATURE_COUNT(uint256 a, uint256 b);

  /// @notice Error for an invalid signer in data verification.
  /// @param dataSigner The address of the signer from the data.
  /// @param expected The expected signer's address.
  error INVALID_SIGNER(address dataSigner, address expected);

  /// @notice Error for data that has timed out (e.g., stale risk data).
  error TIMEOUT();

  /// @notice Error for mismatched chain ID in data verification.
  /// @param chainId The chain ID from the data.
  /// @param current The current chain ID.
  error WRONG_CHAINID(uint256 chainId, uint256 current);

  /// @notice Error for mismatched collateral addresses.
  /// @param c1 The collateral address from the data.
  /// @param c2 The expected collateral address.
  error COLLATERAL_MISMATCH(address c1, address c2);

  /// @notice Error for mismatched debt addresses.
  /// @param d1 The debt address from the data.
  /// @param d2 The expected debt address.
  error DEBT_MISMATCH(address d1, address d2);

  /// @notice Error for when the LTV is too high.
  /// @param ltv The current LTV.
  /// @param maxLtv The maximum allowed LTV.
  error LTV_TOO_HIGH(uint256 ltv, uint256 maxLtv);

  /// @notice Error for when the liquidation bonus is too high.
  /// @param beta The current liquidation bonus.
  /// @param liquidationBonus The liquidation bonus in the risk data.
  error WRONG_LIQUIDATION_BONUS(uint256 beta, uint256 liquidationBonus);
}
