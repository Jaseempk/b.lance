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

import "forge-std/console.sol";

/**
 * 
library Escrow {
    
}
 */

//Errors
error BLANCE__NoUnAuthorisedAccess();
error BLANCE__ProvideAValidAddress();
error BLANCE__OnlyClientCanAccess();
error BLANCE__OnlyFreelancerHaveAccess();
error BLANCE__EscrowAlreadyExists();
error BLANCE__EscrowNeedsToBeActive();
error BLANCE__GigRejected();
error BLANCE__RejectedGig();
error BLANCE_InsufficientDeposit();
error BLANCE__InsufficientEscrowBalance();
error BLANCE__OnlyClientCanDepositEscrow();
error BLANCE__GigCancellationFailed();
error BLANCE__DelayedSubmissionNotPermissible();
error BLANCE__FundReleaseStillOnQueue();
error BLANCE__InvalidReleaseStatus();
error BLANCE__InsufficientReleaseBalance();
error BLANCE__GigNotCompletedYet();
error BLANCE__NoDisputeToResolve();
error BLANCE__OnlymediatorCanResolveDispute();
error BLANCE__OnlyClientCanRaiseDispute();

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
        uint256 gigStarted;
        uint deadline;
        Status status;
    }

    //state variables
    // address public immutable i_owner;
    address private immutable i_mediator;
    uint256 public releaseQueuePeriod;
    uint64 public reputationScore;
    uint64 nonce;

    //Mapping
    mapping(bytes32 => Escrow) public idToEscrow;
    mapping(address => uint) gigDuration;
    mapping(bytes32 => bool) public gigAccepted;
    mapping(address => uint256) public onChainReputation;
    // mapping(address => mapping(address => Status)) gigToFreelancerStatus;

    //Events
    event DepositedEscrow(address indexed _client, uint indexed escrowAmount);
    event GigAccepted(
        bytes32 _escrowId,
        bytes _signature,
        uint256 startingTime
    );
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
            revert BLANCE__OnlyClientCanAccess();
        }
        _;
    }
    modifier preDeadline(bytes32 escrowId) {
        if (block.timestamp <= idToEscrow[escrowId].deadline) {
            revert BLANCE__DelayedSubmissionNotPermissible();
        }
        _;
    }
    modifier onlyMediator() {
        if (msg.sender != i_mediator) {
            revert BLANCE__OnlymediatorCanResolveDispute();
        }
        _;
    }

    //constructor
    constructor() {
        // i_owner = msg.sender;
        // Status initialStatus = Status.Inactive;
    }

    //functions

    function createEscrow(
        address _freelancer,
        uint _deadline,
        uint _payRate,
        uint _escrowAmount
    ) public returns (bytes32) {
        // if (Escrow.status != Status.Inactive)
        //     revert BLANCE__EscrowAlreadyExists();
        if (_freelancer == address(0)) {
            revert BLANCE__ProvideAValidAddress();
        }
        bytes32 escrowId = keccak256(
            abi.encodePacked(msg.sender, _freelancer, block.timestamp, nonce)
        );
        nonce++;
        idToEscrow[escrowId] = Escrow(
            msg.sender,
            _freelancer,
            _payRate,
            _escrowAmount,
            0,
            block.timestamp + _deadline,
            Status.Active
        );

        return escrowId;
        // gigDuration[_freelancer] = Escrow.deadline;
    }

    function acceptGig(
        bytes memory signature,
        bytes32 escrowId
    ) public onlyFreelancer(escrowId) returns (bool) {
        Escrow memory newEscrow = idToEscrow[escrowId];

        bytes32 hashGig = (keccak256(abi.encode(newEscrow)))
            .toEthSignedMessageHash();

        address signer = hashGig.recover(signature);
        // console.log("Signer:", signer);
        // console.log("caller:", msg.sender);

        if (signer != newEscrow.freelancer) revert BLANCE__GigRejected();

        emit GigAccepted(escrowId, signature, block.timestamp);

        if (onChainReputation[msg.sender] == 0) {
            onChainReputation[msg.sender] += 100;
        }
        idToEscrow[escrowId].gigStarted = block.timestamp;

        return gigAccepted[escrowId] = true;
    }

    function escrowDeposited(
        bytes32 escrowId
    ) public payable onlyClient(escrowId) {
        // if (acceptGig != true) revert BLANCE__RejectedGig();
        // console.log("Caller:", msg.sender);
        // console.log("Client:", idToEscrow[escrowId].client);
        if (!gigAccepted[escrowId]) revert BLANCE__RejectedGig();

        if (idToEscrow[escrowId].escrowAmount > msg.value)
            revert BLANCE_InsufficientDeposit();

        if (idToEscrow[escrowId].status != Status.Active) {
            revert BLANCE__EscrowNeedsToBeActive();
        }
        if (msg.sender != idToEscrow[escrowId].client) {
            revert BLANCE__OnlyClientCanDepositEscrow();
        }
        //
        // Escrow thisEscrow = idToEscrow[escrowId];
        // Escrow.escrowAmount = _escrowAmount;
        // require(
        //     _escrowAmount >= Escrow.s_payRate,
        //     "Escrow amount is insufficient"
        // );
        uint256 currentContractBalance = address(this).balance;
        currentContractBalance += idToEscrow[escrowId].escrowAmount;
        // Escrow.status = Status.Active;
        // gigToFreelancerStatus[_client][Escrow.freelancer] = Escrow.status;
        emit DepositedEscrow(msg.sender, idToEscrow[escrowId].escrowAmount);
    }

    function cancelContract(
        bytes32 escrowId
    ) public payable onlyFreelancer(escrowId) {
        if (idToEscrow[escrowId].status == Status.Active)
            revert BLANCE__EscrowNeedsToBeActive();

        if (address(this).balance >= idToEscrow[escrowId].escrowAmount)
            revert BLANCE__InsufficientEscrowBalance();
        // gigToFreelancerStatus[_client][_freelancer] = Status.Agree;

        if ((block.timestamp - idToEscrow[escrowId].gigStarted) >= 4 days) {
            onChainReputation[msg.sender] -= 10;
        }

        uint amountToRefund = idToEscrow[escrowId].escrowAmount;
        address _client = idToEscrow[escrowId].client;
        idToEscrow[escrowId] = Escrow(
            address(0),
            address(0),
            0,
            0,
            0,
            0,
            Status.Inactive
        );
        idToEscrow[escrowId].escrowAmount = 0;
        idToEscrow[escrowId].status = Status.Inactive;

        payable(idToEscrow[escrowId].client).transfer(amountToRefund);
        // if (
        // ) revert BLANCE__GigCancellationFailed();
        emit EscrowCancelled(_client, msg.sender);
    }

    function submitFinishedGig(
        bytes32 escrowId
    ) external preDeadline(escrowId) onlyFreelancer(escrowId) {
        if (idToEscrow[escrowId].status != Status.Active)
            revert BLANCE__EscrowNeedsToBeActive();

        releaseQueuePeriod = block.timestamp + 2 days;

        idToEscrow[escrowId].status = Status.Completed;

        emit ProjectSubmitted(msg.sender);

        // if (haveDispute(escrowId)) {
        //     resolveDispute();
        // } else {
        //     releaseFunds();
        // }
    }

    function releaseFunds(bytes32 escrowId) public payable {
        if (block.timestamp < releaseQueuePeriod)
            revert BLANCE__FundReleaseStillOnQueue();

        if (
            idToEscrow[escrowId].status != Status.Completed ||
            idToEscrow[escrowId].status == Status.Dispute
        ) revert BLANCE__InvalidReleaseStatus();
        // require(
        //     idToEscrow[escrowId].status == Status.Completed &&
        //         idToEscrow[escrowId].status != Status.Dispute,
        //     "Invalid status to release funds"
        // );
        if (address(this).balance < idToEscrow[escrowId].escrowAmount)
            revert BLANCE__InsufficientReleaseBalance();

        address _freelancer = idToEscrow[escrowId].freelancer;
        address _client = idToEscrow[escrowId].client;

        uint256 balance = idToEscrow[escrowId].escrowAmount -
            idToEscrow[escrowId].s_payRate;

        idToEscrow[escrowId].freelancer = address(0);
        idToEscrow[escrowId].client = address(0);

        require(_freelancer != address(0), "invalid address");

        require(
            payable(_freelancer).send(idToEscrow[escrowId].s_payRate),
            "Escrowpayment failed"
        );
        if (balance > 0 && _client != address(0)) {
            payable(_client).transfer(balance);
        }

        emit EscrowPaymentReleased(
            idToEscrow[escrowId].freelancer,
            idToEscrow[escrowId].s_payRate
        );
    }

    function resolveDispute(bytes32 escrowId) public view onlyMediator {
        if (idToEscrow[escrowId].status != Status.Dispute)
            revert BLANCE__NoDisputeToResolve();
    }

    function haveDispute(
        bytes32 escrowId
    ) internal onlyClient(escrowId) returns (Status) {
        if (idToEscrow[escrowId].status != Status.Completed)
            revert BLANCE__GigNotCompletedYet();

        return idToEscrow[escrowId].status = Status.Dispute;
    }

    function getEscrowDetails(
        bytes32 escrowId
    ) public view returns (Escrow memory) {
        return idToEscrow[escrowId];
    }
}
