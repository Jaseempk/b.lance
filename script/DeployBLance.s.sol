//SPDX-License-Identifier:MIT

pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/BLance.sol";

//

contract DeployBlance is Script {
    function run() public returns (BLance) {
        vm.startBroadcast();
        BLance blance = new BLance();
        vm.stopBroadcast();
        return blance;
    }
}
