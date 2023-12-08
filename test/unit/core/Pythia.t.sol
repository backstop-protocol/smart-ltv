// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "ds-test/test.sol";
import "src/core/Pythia.sol";

contract PythiaTest is DSTest {
  Pythia pythia;

  function setUp() public {
    pythia = new Pythia();
  }

  function testDomainSeparator() public {
    bytes32 expected = "0x030a1e878cd53df6af29a4bc520fde7936a8b4ff6a735f7da53b528cfdc6e207";
    assertEq(pythia.DOMAIN_SEPARATOR(), expected);
  }
}
