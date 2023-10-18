//SPDX-License-Identifier:MIT

pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/BLance.sol";

contract BLanceTest is Test{

    BLance bLance;

    address payable freelancer;
    address payable client;
    uint256 escrowAmount=40;
    uint256 minAmount=69;

    event EscrowInitiated(address indexed sender, uint256 indexed amount);

    function setUp() public{


        bLance= new BLance(client,freelancer);
        
    }
    function testFail_NoMinAmount() public {
        bLance.escrowDeposit(escrowAmount,minAmount);
    }
    function test_expectEmit() public {

        vm.expectEmit(true,true,true,true);
        emit EscrowInitiated(msg.sender,escrowAmount);
        
    }
    

}