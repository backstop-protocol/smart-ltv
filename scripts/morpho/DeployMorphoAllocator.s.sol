// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import {Script, console} from "../../lib/forge-std/src/Script.sol";
import {SmartLTV} from "../../src/core/SmartLTV.sol";
import {BProtocolMorphoAllocator} from "../../src/morpho/BProtocolMorphoAllocator.sol";
import {DeploySmartLTV} from "../core/DeploySmartLTV.s.sol";

contract DeployMorphoAllocator is Script {
    uint256 public PRIVATE_KEY;
    address public SMARTLTV_ADDRESS;
    address public METAMORPHO_VAULT;
    address public INITIAL_OWNER;

    function _parseEnv() internal {
        // Default behavior: use Anvil 0 private key
        PRIVATE_KEY = vm.envOr(
            "ETH_PRIVATE_KEY",
            77814517325470205911140941194401928579557062014761831930645393041380819009408
        );

        SMARTLTV_ADDRESS = vm.envOr("SMARTLTV_ADDRESS", address(0));
        METAMORPHO_VAULT = vm.envOr("METAMORPHO_VAULT", address(0));
        INITIAL_OWNER = vm.envOr("INITIAL_OWNER", address(0));
    }

    function run() public {
        _parseEnv();
        console.log("Running tx from wallet %s", vm.addr(PRIVATE_KEY));

        if(METAMORPHO_VAULT == address(0)) {
            revert ("missing METAMORPHO_VAULT");
        }
        console.log("Metamorpho vault: %s", METAMORPHO_VAULT);

        if(INITIAL_OWNER == address(0)) {
            revert ("missing INITIAL_OWNER");
        }
        console.log("Initial owner: %s", INITIAL_OWNER);

        
        if(SMARTLTV_ADDRESS == address(0)) {
            DeploySmartLTV dSmartLTV = new DeploySmartLTV();
            SMARTLTV_ADDRESS = dSmartLTV.run();
        }

        vm.startBroadcast(PRIVATE_KEY);
        console.log("Deploying BProtocolMorphoAllocator contract");
        new BProtocolMorphoAllocator(SmartLTV(SMARTLTV_ADDRESS), METAMORPHO_VAULT, INITIAL_OWNER, 10e18);
        console.log("Deployed BProtocolMorphoAllocator contract");
        vm.stopBroadcast();
    }
}