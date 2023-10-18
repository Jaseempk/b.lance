// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions



//SPDX-License-Identifier:MIT

pragma solidity ^0.8.19;

/**
 * 
library Escrow {
    
}
 */

//Errors 
error BLance__ProvideAValidAddress();
error BLance__OnlyClientCanAccess();
error BLance__EscrowNeedsToBeActive();
error BLance__OnlyClientCanDepositEscrow();
error BLance__DelayedSubmissionNotPermissible();
error BLance__OnlymediatorCanResolveDispute();
error BLance__OnlyClientCanRaiseDispute();

contract BLance{


    //enum
    enum Status{
      Inactive,
      Active,
      Agree,
      Completed,
      Dispute,
      Resolved,
      Released
    }

    //struct 
    struct escrow{
        address client;
        address freelancer;
        uint s_payRate;
        uint escrowAmount;
        uint deadline;
        Status status;
    }

    //state variables
    address public immutable i_owner;
    address private immutable i_mediator;

    //Mapping
    mapping(address => uint)gigDuration;
    mapping(address=> mapping(address=>Status))gigToFreelancerStatus;


    //Events
    event DepositedEscrow(address indexed _client,uint indexed escrowAmount);
    event EscrowCancelled(address indexed _client,address indexed _freelancer);
    event ProjectSubmitted(address indexed _freelancer);
    event EscrowPaymentReleased(address indexed _freelancer,uint indexed amount);


    //modifiers
    modifier onlyClientNFreelancer{
        require(msg.sender== escrow.client ||msg.sender==escrow.freelancer,"No unauthorised access");
        _;
    }
    modifier onlyClient{
        if(msg.sender!=escrow.client){
            revert BLance__OnlyClientCanAccess();
        }
        _;
    }
    modifier preDeadline{
        if(block.timestamp<=escrow.deadline){
            revert BLance__DelayedSubmissionNotPermissible();
        }
        _;
    }
    modifier onlyMediator{
        if(msg.sender!=i_mediator){
            revert BLance__OnlymediatorCanResolveDispute();
        }
        _;
    }

    //constructor
    constructor(){
        i_owner=msg.sender;
        escrow.status=Status.Inactive;
    }

    //functions

    function createEscrow(address _client,address _freelancer,uint _deadline,uint _payRate)public onlyClientNFreelancer{
        require(escrow.status==Status.Inactive,"Already an active escrow exists");
        if(_client==address(0)|| _freelancer==address(0)){
            revert BLance__ProvideAValidAddress();
        }
        escrow.client=_client;
        escrow.freelancer=_freelancer;
        escrow.deadline=block.timestamp + _deadline;
        escrow.s_payRate=_payRate;
        escrow.status=Status.Active;
        gigToFreelancerStatus[_client][_freelancer]=escrow.status;
        gigDuration[_freelancer]=escrow.deadline;
    }


    function escrowDeposited(address _client,uint _escrowAmount)public payable onlyClient{
        if(escrow.status!=Status.Active){
            revert BLance__EscrowNeedsToBeActive();
        }
        if(msg.sender!=_client){
            revert BLance__OnlyClientCanDepositEscrow();
        }
        escrow.escrowAmount=_escrowAmount;
        require(_escrowAmount>=escrow.s_payRate,"Escrow amount is insufficient");
        address(this).balance+=_escrowAmount;
        escrow.status=Status.Active;
        gigToFreelancerStatus[_client][escrow.freelancer]=escrow.status;
        emit DepositedEscrow(_client,_escrowAmount);


    }

    function cancelContract(address _client,address _freelancer)payable public{
        require(escrow.status==Status.Active,"Escrow needs to be active");
        require(address(this).balance>=escrow.escrowAmount,"Insufficient fund in the escrow contract");
        gigToFreelancerStatus[_client][_freelancer]=Status.Agree;

        uint amountToRefund=escrow.escrowAmount;
        escrow.escrowAmount=0;
        escrow.status=Status.Inactive;
        gigToFreelancerStatus[_client][_freelancer]=escrow.status;


        require(payable(escrow.client).transfer(escrow.escrowAmount),"Unable to refund");
        emit EscrowCancelled(_client,_freelancer);

    }

    function submitFinishedGig(address _freelancer,address _client)external preDeadline{
        require(gigToFreelancerStatus[_client][_freelancer]=Status.Active,"Escrow not active");
        require(msg.sender==_freelancer,"Only freelancer have access");

        emit ProjectSubmitted(_freelancer);


        if(haveDispute){
            resolveDispute();
        }
        else {
            releaseFunds();
        }
    }

    function releaseFunds()payable public{
        require(escrow.status==Status.Completed && escrow.status!=Status.Dispute,"Invalid status to release funds");
        require(address(this).balance>=escrow.escrowAmount,"insufficient balance");
        
        address _freelancer=escrow.freelancer;
        address _client=escrow.client;

        uint256 balance=escrow.escrowAmount-escrow.s_payRate;

        escrow.freelancer=address(0);
        escrow.client=address(0);

        require(_freelancer!=address(0),"invalid address");

        require(_freelancer.send(escrow.s_payRate),"Escrowpayment failed");
        if(balance>0 && _client!=address(0)){
            _client.transfer(balance);
        }

        emit EscrowPaymentReleased(escrow.freelancer,escrow.s_payRate);


    }

    function resolveDispute()public onlyMediator{
        require(gigToFreelancerStatus[escrow.client][escrow.freelancer]==Status.Dispute,"No dispute raised");
    }

    function haveDispute()internal returns(Status)  {
        require(gigToFreelancerStatus[escrow.client][escrow.freelancer]==Status.Completed);
        if(msg.sender!=escrow.client){
            revert BLance__OnlyClientCanRaiseDispute();
        }
        escrow.status=Status.Dispute;
        return gigToFreelancerStatus[msg.sender][escrow.freelancer]=escrow.status;
        //resolveDispute();
    }


}