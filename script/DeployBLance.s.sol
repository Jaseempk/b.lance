//SPDX-License-Identifier:MIT

pragma solidity ^0.8.19;


import "forge-std/Script.sol";
import "../src/BLance.sol";
//

contract MyScript is Script{

    function run() public{

        uint256 deployerPrivKey=vm.envUint("PRIVATE_KEY");
        address payable client=payable(0x66aAf3098E1eB1F24348e84F509d8bcfD92D0620);
        address payable freelancer=payable(0xF941d25cEB9A56f36B2E246eC13C125305544283);

        vm.startBroadcast(deployerPrivKey);
        BLance blance=new BLance{value:0.1 ether}(client,freelancer);
        vm.deal(address(blance),0.1 ether);
        blance.escrowDeposit{value: 0.1 ether}(0.1 ether,0.01 ether);
        if(
           msg.sender==client||
           msg.sender==freelancer
           ){
            blance.submitWork();
           }
        
        vm.stopBroadcast();


    }

}