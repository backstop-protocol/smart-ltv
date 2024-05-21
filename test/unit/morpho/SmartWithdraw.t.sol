// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import {Test, console} from "../../../lib/forge-std/src/Test.sol";
import {SmartWithdraw} from "../../../src/morpho/SmartWithdraw.sol";

contract SmartWitdrawTest is Test {
  event DEPLOYMENT_CODE(bytes code);

  function testLogSmartWithdrawCreationCode() public {
    // https://book.getfoundry.sh/cheatcodes/get-code
    address smartLTVAddressProd = 0xE38dC49cae5F1C7a8ce80b99DC18A015c96cebab;
    bytes memory args = abi.encode(smartLTVAddressProd);
    bytes memory bytecode = abi.encodePacked(vm.getCode("SmartWithdraw.sol:SmartWithdraw"), args);
    emit DEPLOYMENT_CODE(bytecode);
  }
}
