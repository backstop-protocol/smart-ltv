// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../../lib/forge-std/src/Test.sol";
import "../../lib/metamorpho/src/interfaces/IMetaMorpho.sol";
import {Market} from "../../lib/metamorpho/lib/morpho-blue/src/interfaces/IMorpho.sol";

import "../../src/core/Pythia.sol";
import "../../src/core/SmartLTV.sol";
import {BProtocolMorphoAllocator} from "../../src/morpho/BProtocolMorphoAllocator.sol";

/*  
USDC/sDAI
marketid 0x7a9e4757d1188de259ba5b47f4c08197f821e54109faa5b0502b9dfe2c10b741
loanToken   address :  0x62bD2A599664D421132d7C54AB4DbE3233f4f0Ae
  collateralToken   address :  0xD8134205b0328F5676aaeFb3B2a0DC15f4029d8C
  oracle   address :  0xc1466Cc7e9ace925fA54398f99D2277a571A7a0a
  irm   address :  0x9ee101eB4941d8D7A665fe71449360CEF3C8Bb87
  lltv   uint256 :  900000000000000000
  
  
USDC/USDT
marketid: 0xbc6d1789e6ba66e5cd277af475c5ed77fcf8b084347809d9d92e400ebacbdd10
  loanToken   address :  0x62bD2A599664D421132d7C54AB4DbE3233f4f0Ae
  collateralToken   address :  0x576e379FA7B899b4De1E251e935B31543Df3e954
  oracle   address :  0x095613a8C57a294E43E2bb5B62D628D8C8B00dAA
  irm   address :  0x9ee101eB4941d8D7A665fe71449360CEF3C8Bb87
  lltv   uint256 :  900000000000000000
*/

/// @title defines the fixtures needed to take control of morpho blue goerli deployment
/// by pranking addresses with roles and giving roles to contracts
contract MorphoFixture is Test {
  /// VERIFY THESES HARDCODED VARIABLE AS THEY'RE THE ONE FROM THE GOERLI DEPLOYMENT
  /// IF DEPLOYMENT CHANGE OR MARKETS ARE CHANGED IT COULD BREAK THE TEST ENVIRONMENT
  Id marketIdSDAI = Id.wrap(0x7a9e4757d1188de259ba5b47f4c08197f821e54109faa5b0502b9dfe2c10b741);
  Id marketIdUSDT = Id.wrap(0xbc6d1789e6ba66e5cd277af475c5ed77fcf8b084347809d9d92e400ebacbdd10);
  Id marketIdIdle = Id.wrap(0x655f87b795c56753741185b9f6fa24c9eb8411bbbbadb44335c9cd4ee0883990);
  IMetaMorpho metaMorpho = IMetaMorpho(0xb6c383fF0257D20e4c9872B6c9F1ce412F4AAC4C);
  IMorpho morpho = IMorpho(0x64c7044050Ba0431252df24fEd4d9635a275CB41);

  Pythia public pythia;
  SmartLTV public smartLTV;
  BProtocolMorphoAllocator morphoAllocator;

  uint256 trustedRelayerPrivateKey = 0x42;
  address trustedRelayerAddress = vm.addr(trustedRelayerPrivateKey);
  address allocatorOwner = address(101);

  // fake function so that does not show up in the coverage report
  function test() public {}

  function setUp() public virtual {
    // create pythia, smartLTV and BProtocolMorphoAllocator contract
    pythia = new Pythia();
    smartLTV = new SmartLTV(pythia, trustedRelayerAddress);
    morphoAllocator = new BProtocolMorphoAllocator(smartLTV, address(metaMorpho), allocatorOwner);

    // gives the allocator role to the BProtocolMorphoAllocator contract
    address ownerAddress = metaMorpho.owner();
    vm.prank(ownerAddress);
    metaMorpho.setIsAllocator(address(morphoAllocator), true);
  }
}
