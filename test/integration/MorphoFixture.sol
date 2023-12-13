// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../../lib/forge-std/src/Test.sol";
import "../../src/external/Morpho.sol";
import "../../src/core/Pythia.sol";
import "../../src/core/SmartLTV.sol";
import "../../src/morpho/BProtocolMorphoAllocator.sol";

/// @title defines the fixtures needed to take control of morpho blue goerli deployment
/// by pranking addresses with roles and giving roles to contracts
contract MorphoFixture is Test {
  Pythia public pythia;
  SmartLTV public smartLTV;
  BProtocolMorphoAllocator morphoAllocator;

  uint256 trustedRelayerPrivateKey = 0x42;
  address trustedRelayerAddress = vm.addr(trustedRelayerPrivateKey);
  IMetaMorpho metaMorpho = IMetaMorpho(0xb6c383fF0257D20e4c9872B6c9F1ce412F4AAC4C);
  IMorpho morpho = IMorpho(0x64c7044050Ba0431252df24fEd4d9635a275CB41);

  // fake function so that does not show up in the coverage report
  function test() public {}

  function setUp() public virtual {
    // create pythia, smartLTV and BProtocolMorphoAllocator contract
    pythia = new Pythia();
    smartLTV = new SmartLTV(pythia, trustedRelayerAddress);
    morphoAllocator = new BProtocolMorphoAllocator(smartLTV, address(metaMorpho));

    // gives the allocator role to the BProtocolMorphoAllocator contract
    address ownerAddress = metaMorpho.owner();
    vm.prank(ownerAddress);
    metaMorpho.setIsAllocator(address(morphoAllocator), true);
  }
}
