// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import {IERC20Metadata} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

library TestLib {
  function toPercentageString(uint256 value) public pure returns (string memory) {
    require(value <= 1e20, "Value too large");

    uint256 percentageValue = (value * 100) / 1e16; // Convert to percentage
    uint256 integerPart = percentageValue / 100;
    uint256 fractionalPart = percentageValue % 100;

    return
      string(
        abi.encodePacked(
          uintToString(integerPart),
          ".",
          fractionalPart < 10 ? "0" : "", // Add leading zero for single digit fractional part
          uintToString(fractionalPart),
          "%"
        )
      );
  }

  function uintToString(uint256 value) internal pure returns (string memory) {
    // This function converts an unsigned integer to a string.
    if (value == 0) {
      return "0";
    }
    uint256 temp = value;
    uint256 digits;
    while (temp != 0) {
      digits++;
      temp /= 10;
    }
    bytes memory buffer = new bytes(digits);
    while (value != 0) {
      digits -= 1;
      buffer[digits] = bytes1(uint8(48 + (value % 10)));
      value /= 10;
    }
    return string(buffer);
  }

  function addressToSymbol(address _addr) public view returns (string memory) {
    if (_addr == address(0)) {
      return "idle";
    } else {
      return IERC20Metadata(_addr).symbol();
    }
  }
}
