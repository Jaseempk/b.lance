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

    ////////////
   // imports//
  ////////////
  import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
  import{ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";



    ////////////
   // Errors //
  ////////////
    error BLance__NotBeforeDeadLine();
    error BLance__NotAfterDeadline();
    error BLance__WorkUnverified();
    error BLance__OnlyClientCanRaiseDispute();
     

contract BLance is Ownable,ReentrancyGuard{

    ///////////
   // Enums // 
  ///////////
   enum Status{
    Agree,
    Completed,
    Active,
    Dispute
   }


    //////////////////////
   /// state variables //
  //////////////////////

    uint256 public s_payRate;
    uint256 public deadline;
    address payable public client;
    address payable public freelancer;
    address private immutable i_mediator;
    Status public status;
    bool disputeResolved;


    /////////////
   // Events ///
  ///////////// 

   event EscrowInitiated(address indexed sender,uint256 indexed amount); 
   event AgreementCancelled(address indexed sender,Status status);
   event ProjectSubmitted(address indexed _freelancer);
   event PaymentReleased(address indexed _freelancer,uint256 indexed _amount);

    ///////////////
   // Modifiers //
  ///////////////

  modifier  pastDeadline {
   
    if(!(block.timestamp >= deadline)){
       revert BLance__NotBeforeDeadLine();
    }
   _;
   
  }
  modifier preDeadline{
    if(block.timestamp>deadline){
      revert BLance__NotAfterDeadline();
    }
    _;
  }
  modifier isVerified{
    if(status==Status.Completed){
      //revert BLance__WorkUnverified();
      if(status==Status.Dispute){
        resolveDispute();
      }
      require(status!=Status.Dispute,"Resolve the existing dispute");
    }

    _;
  }

  modifier onlyClient{
    if(msg.sender!=client){
      revert BLance__OnlyClientCanRaiseDispute();
    }
    _;
  }
    /**
     * 
    */
    






    constructor(address payable _client,address payable _freelancer){
      client=_client;
      freelancer=_freelancer;
      deadline=block.timestamp + 30 days;

    }

    ////////////////////////
   // External Functions //
  ////////////////////////

    function escrowDeposit(uint256 _escrowAmount,uint256 _minAmount)payable external{
        
      s_payRate =_escrowAmount;
      require(s_payRate>=_minAmount,"Minimum amount required");
      require( payable(address(this)).send(s_payRate),"Deposit failed");

      emit EscrowInitiated(msg.sender,_escrowAmount);

    }

    function cancelContract()external{

      require(
      msg.sender==client||
      msg.sender==freelancer,
      "Unauthorise Address,Permission denied"
      );
      require(
        status==Status.Agree,
        "Need mutual agreement to cancel the contract"
      );

     //Refund given to the client
      (bool refund,)=client.call{value:address(this).balance}("");
      require(refund,"Refund failed, try again");


      emit AgreementCancelled(msg.sender,status);
    }

    function submitWork()external preDeadline{

      status=Status.Completed;

      emit ProjectSubmitted(freelancer);
    }

    function raiseDispute()external{

            status=Status.Dispute;
    }

    function resolveDispute()internal{
      require(msg.sender==i_mediator,"Only mediator can resolve the dispute");
      disputeResolved=true;
    }


    function releaseFunds()internal onlyOwner pastDeadline nonReentrant{

     require(freelancer!=address(0),"invalid address");
     require(address(this).balance>=s_payRate,"insufficient balance");
     (bool fundRelease,)=freelancer.call{value:s_payRate}("");

     require(fundRelease,"Fund release failed");

     emit PaymentReleased(freelancer,s_payRate);
   
    }
    function workVerified()internal isVerified onlyOwner nonReentrant{

      releaseFunds();

      status==Status.Active;
    }




}