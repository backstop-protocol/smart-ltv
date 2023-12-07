// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

library ErrorLib {
  error INVALID_RISK_DATA_COUNT(uint256 a, uint256 b);
  error INVALID_SIGNATURE_COUNT(uint256 a, uint256 b);
  error INVALID_SIGNER(address dataSigner, address expected);
  error TIMEOUT();
  error WRONG_CHAINID(uint256 chainId, uint256 current);
  error COLLATERAL_MISMATCH(address c1, address c2);
  error DEBT_MISMATCH(address d1, address d2);
  error LTV_TOO_HIGH(uint256 ltv, uint256 maxLtv);
}
