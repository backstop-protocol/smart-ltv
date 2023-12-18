// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import {Script, console} from "../../lib/forge-std/src/Script.sol";
import {SmartLTV} from "../../src/core/SmartLTV.sol";
import {Pythia} from "../../src/core/Pythia.sol";
import {DeployPythia} from "./DeployPythia.s.sol";

contract DeploySmartLTV is Script {
    uint256 public PRIVATE_KEY;
    address public TRUSTED_RELAYER;
    address public PYTHIA_ADDRESS;

    function _parseEnv() internal {
        // Default behavior: use Anvil 0 private key
        PRIVATE_KEY = vm.envOr(
            "ETH_PRIVATE_KEY",
            77814517325470205911140941194401928579557062014761831930645393041380819009408
        );

        TRUSTED_RELAYER = vm.envOr("TRUSTED_RELAYER", address(0));
        PYTHIA_ADDRESS = vm.envOr("PYTHIA_ADDRESS", address(0));
    }

    function run() public returns(address) {
        _parseEnv();

        
        if(TRUSTED_RELAYER == address(0)) {
            revert ("missing TRUSTED_RELAYER");
        }

        if(PYTHIA_ADDRESS == address(0)) {
            DeployPythia dPythia = new DeployPythia();
            PYTHIA_ADDRESS = dPythia.run();
        }

        vm.startBroadcast(PRIVATE_KEY);
        console.log("Deploying SmartLTV contract");
        SmartLTV smartLTVAddress = new SmartLTV(Pythia(PYTHIA_ADDRESS), TRUSTED_RELAYER);
        console.log("Deployed SmartLTV contract");
        vm.stopBroadcast();

        return address(smartLTVAddress);
    }
}