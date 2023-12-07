// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import {MarketParams, Id} from "../interfaces/IMetaMorpho.sol";

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
