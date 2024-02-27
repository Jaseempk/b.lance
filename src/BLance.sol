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

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * 
library Escrow {
    
}
 */

//Errors
error BLANCE__NoUnAuthorisedAccess();
error BLance__ProvideAValidAddress();
error BLance__OnlyClientCanAccess();
error BLANCE__OnlyFreelancerHaveAccess();
error BLANCE__EscrowAlreadyExists();
error BLance__EscrowNeedsToBeActive();
error BLANCE__GigRejected();
error BLANCE__RejectedGig();
error BLANCE_InsufficientDeposit();
error BLANCE__InsufficientEscrowBalance();
error BLance__OnlyClientCanDepositEscrow();
error BLANCE__GigCancellationFailed();
error BLance__DelayedSubmissionNotPermissible();
error BLance__OnlymediatorCanResolveDispute();
error BLance__OnlyClientCanRaiseDispute();

contract BLance {
    using ECDSA for bytes32;
    //enum
    enum Status {
        Inactive,
        Active,
        Agree,
        Completed,
        Dispute,
        Resolved,
        Released
    }

    //struct
    struct Escrow {
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
    uint64 nonce;

    //Mapping
    mapping(bytes32 => Escrow) public idToEscrow;
    mapping(address => uint) gigDuration;
    // mapping(address => mapping(address => Status)) gigToFreelancerStatus;

    //Events
    event DepositedEscrow(address indexed _client, uint indexed escrowAmount);
    event EscrowCancelled(address indexed _client, address indexed _freelancer);
    event ProjectSubmitted(address indexed _freelancer);
    event EscrowPaymentReleased(
        address indexed _freelancer,
        uint indexed amount
    );

    //modifiers
    // modifier onlyClientNFreelancer() {
    //     if (msg.sender != Escrow.client || msg.sender != Escrow.freelancer)
    //         revert BLANCE__NoUnAuthorisedAccess();

    //     _;
    // }
    modifier onlyFreelancer(bytes32 escrowId) {
        if (msg.sender != idToEscrow[escrowId].freelancer)
            revert BLANCE__OnlyFreelancerHaveAccess();
        _;
    }
    modifier onlyClient(bytes32 escrowId) {
        if (msg.sender != idToEscrow[escrowId].client) {
            revert BLance__OnlyClientCanAccess();
        }
        _;
    }
    modifier preDeadline(bytes32 escrowId) {
        if (block.timestamp <= idToEscrow[escrowId].deadline) {
            revert BLance__DelayedSubmissionNotPermissible();
        }
        _;
    }
    modifier onlyMediator() {
        if (msg.sender != i_mediator) {
            revert BLance__OnlymediatorCanResolveDispute();
        }
        _;
    }

    //constructor
    constructor() {
        i_owner = msg.sender;
        Status initialStatus = Status.Inactive;
    }

    //functions

    function createEscrow(
        address _client,
        address _freelancer,
        uint _deadline,
        uint _payRate
    ) public onlyClient {
        if (Escrow.status != Status.Inactive)
            revert BLANCE__EscrowAlreadyExists();
        if (_client == address(0) || _freelancer == address(0)) {
            revert BLance__ProvideAValidAddress();
        }
        bytes32 escrowId = keccak256(
            abi.encodePacked(_client, _freelancer, block.timestamp, nonce)
        );
        nonce++;
        idToEscrow[escrowId] = Escrow(
            _client,
            _freelancer,
            _payRate,
            0,
            block.timestamp + _deadline,
            Status.Active
        );
        gigDuration[_freelancer] = Escrow.deadline;
    }

    function acceptGig(
        bytes32 signature,
        bytes32 escrowId
    ) public onlyFreelancer(escrowId) returns (bool) {
        Escrow memory newEscrow = idToEscrow[escrowId];
        bytes32 hashGig = keccak256(abi.encodePacked(newEscrow));
        address signer = hashGig.recover(signature);
        if (signer != newEscrow.freelancer) revert BLANCE__GigRejected();
        return true;
    }

    function escrowDeposited(
        bytes32 escrowId
    ) public payable onlyClient(escrowId) {
        if (acceptGig != true) revert BLANCE__RejectedGig();
        if (idToEscrow[escrowId].escrowAmount > msg.value)
            revert BLANCE_InsufficientDeposit();
        if (idToEscrow[escrowId].status != Status.Active) {
            revert BLance__EscrowNeedsToBeActive();
        }
        if (msg.sender != idToEscrow[escrowId].client) {
            revert BLance__OnlyClientCanDepositEscrow();
        }
        // Escrow thisEscrow = idToEscrow[escrowId];
        // Escrow.escrowAmount = _escrowAmount;
        // require(
        //     _escrowAmount >= Escrow.s_payRate,
        //     "Escrow amount is insufficient"
        // );
        address(this).balance += idToEscrow[escrowId].escrowAmount;
        // Escrow.status = Status.Active;
        // gigToFreelancerStatus[_client][Escrow.freelancer] = Escrow.status;
        emit DepositedEscrow(msg.sender, idToEscrow[escrowId].escrowAmount);
    }

    function cancelContract(
        bytes32 escrowId
    ) public payable onlyFreelancer(escrowId) {
        if (idToEscrow[escrowId].status == Status.Active)
            revert BLance__EscrowNeedsToBeActive();
        if (address(this).balance >= idToEscrow[escrowId].escrowAmount)
            revert BLANCE__InsufficientEscrowBalance();
        // gigToFreelancerStatus[_client][_freelancer] = Status.Agree;

        uint amountToRefund = idToEscrow[escrowId].escrowAmount;
        idToEscrow[escrowId].escrowAmount = 0;
        idToEscrow[escrowId].status = Status.Inactive;

        if (
            payable(idToEscrow[escrowId].client).transfer(
                idToEscrow[escrowId].escrowAmount
            )
        ) revert BLANCE__GigCancellationFailed();
        emit EscrowCancelled(idToEscrow[escrowId].client, msg.sender);
    }

    function submitFinishedGig(
        bytes32 escrowId
    ) external preDeadline onlyFreelancer(escrowId) {
        if (idToEscrow[escrowId].status = Status.Active)
            revert BLance__EscrowNeedsToBeActive();

        emit ProjectSubmitted(msg.sender);

        if (haveDispute) {
            resolveDispute();
        } else {
            releaseFunds();
        }
    }

    function releaseFunds() public payable {
        require(
            Escrow.status == Status.Completed &&
                Escrow.status != Status.Dispute,
            "Invalid status to release funds"
        );
        require(
            address(this).balance >= Escrow.escrowAmount,
            "insufficient balance"
        );

        address _freelancer = Escrow.freelancer;
        address _client = Escrow.client;

        uint256 balance = Escrow.escrowAmount - Escrow.s_payRate;

        Escrow.freelancer = address(0);
        Escrow.client = address(0);

        require(_freelancer != address(0), "invalid address");

        require(_freelancer.send(Escrow.s_payRate), "Escrowpayment failed");
        if (balance > 0 && _client != address(0)) {
            _client.transfer(balance);
        }

        emit EscrowPaymentReleased(Escrow.freelancer, Escrow.s_payRate);
    }

    function resolveDispute(bytes32 escrowId) public onlyMediator {
        require(
            idToEscrow[escrowId].status == Status.Dispute,
            "No dispute raised"
        );
    }

    function haveDispute(
        bytes32 escrowId
    ) internal onlyClient(escrowId) returns (Status) {
        require(
            idToEscrow[escrowId].status == Status.Completed,
            "Gig is yet to be submitted"
        );

        return idToEscrow[escrowId].status = Status.Dispute;
    }
}
