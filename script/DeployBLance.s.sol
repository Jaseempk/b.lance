//SPDX-License-Identifier:MIT

pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/BLance.sol";

//

contract MyScript is Script {
    function run() public {
        vm.startBroadcast();

        vm.stopBroadcast();
    }
}
