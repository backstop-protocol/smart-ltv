// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import {Script, console} from "../../lib/forge-std/src/Script.sol";
import {Pythia} from "../../src/core/Pythia.sol";

contract DeployPythia is Script {
  uint256 public PRIVATE_KEY;

  function _parseEnv() internal {
    // Default behavior: use Anvil 0 private key
    PRIVATE_KEY = vm.envOr(
      "ETH_PRIVATE_KEY",
      77814517325470205911140941194401928579557062014761831930645393041380819009408
    );
  }

  function run() public returns (address) {
    _parseEnv();

    vm.startBroadcast(PRIVATE_KEY);
    console.log("Deploying pythia contract");
    Pythia pythiaAddress = new Pythia();
    console.log("Deployed pythia contract");
    vm.stopBroadcast();

    return address(pythiaAddress);
  }
}
