//SPDX-License-Identifier:MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/BLance.sol";

contract BLanceTest is Test {
    using ECDSA for bytes32;

    BLance bLance;

    address public freelancer = 0xE6F3889C8EbB361Fa914Ee78fa4e55b1BBed3A96;
    address public client = makeAddr("client");
    uint256 escrowAmount = 40;
    uint256 minAmount = 69;
    uint256 freelancerPrivKey = vm.envUint("OWNER_PRIVATE_KEY");

    enum Status {
        Inactive,
        Active,
        Agree,
        Completed,
        Dispute,
        Resolved,
        Released
    }

    struct Escrow {
        address client;
        address freelancer;
        uint s_payRate;
        uint escrowAmount;
        uint256 gigStarted;
        uint deadline;
        Status status;
    }

    event EscrowInitiated(address indexed sender, uint256 indexed amount);

    function setUp() public {
        bLance = new BLance();
    }

    function testToCheckEscrow() public {
        vm.prank(client);
        bLance.createEscrow(freelancer, 30 days, 1 ether, 2 ether);
    }

    function testGigAcceptance() public {
        testToCheckEscrow();

        bytes32 escrowId = bLance.createEscrow(
            freelancer,
            30 days,
            0.01 ether,
            0.02 ether
        );
        // Escrow memory newEscrow = bLance.getEscrowDetails(escrowId);
        bytes32 digest = (
            keccak256(abi.encode(bLance.getEscrowDetails(escrowId)))
        ).toEthSignedMessageHash();

        bytes memory signature = signSale(digest, freelancerPrivKey);
        vm.prank(freelancer);
        bLance.acceptGig(signature, escrowId);
    }

    function testForInvalidFreelancer() public {
        bytes4 customError = bytes4(
            keccak256("BLANCE__ProvideAValidAddress()")
        );
        vm.expectRevert(customError);
        vm.prank(client);
        bLance.createEscrow(address(0), 30 days, 1 ether, 2 ether);
    }

    function testInvalidUserAcceptance() public {
        testToCheckEscrow();

        bytes32 escrowId = bLance.createEscrow(
            freelancer,
            30 days,
            0.01 ether,
            0.02 ether
        );
        // Escrow memory newEscrow = bLance.getEscrowDetails(escrowId);
        bytes32 digest = (
            keccak256(abi.encode(bLance.getEscrowDetails(escrowId)))
        ).toEthSignedMessageHash();

        bytes memory signature = signSale(digest, freelancerPrivKey);
        bytes4 customError = bytes4(
            keccak256("BLANCE__OnlyFreelancerHaveAccess()")
        );

        vm.expectRevert(customError);

        vm.prank(client);
        bLance.acceptGig(signature, escrowId);
    }

    function testEscrowDeposit() public {
        testToCheckEscrow();

        vm.prank(client);
        bytes32 escrowId = bLance.createEscrow(
            freelancer,
            30 days,
            0.01 ether,
            0.02 ether
        );
        // Escrow memory newEscrow = bLance.getEscrowDetails(escrowId);
        bytes32 digest = (
            keccak256(abi.encode(bLance.getEscrowDetails(escrowId)))
        ).toEthSignedMessageHash();

        bytes memory signature = signSale(digest, freelancerPrivKey);
        vm.prank(freelancer);
        bLance.acceptGig(signature, escrowId);

        // bytes32 escrowId = bLance.createEscrow(
        //     freelancer,
        //     30 days,
        //     1 ether,
        //     2 ether
        // );
        vm.startPrank(client);
        vm.deal(client, 10 ether);
        console.log("client:", client);
        bLance.escrowDeposited{value: 0.03 ether}(escrowId);
        vm.stopPrank();
    }

    function signSale(
        bytes32 digest,
        uint256 privateKey
    ) internal pure returns (bytes memory) {
        // Simulate the signing using Foundry's vm.sign, which returns (v, r, s)
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        // Combine v, r, and s components into a single bytes signature
        return abi.encodePacked(r, s, v);
    }

    function test_expectEmit() public {
        vm.expectEmit(true, true, true, true);
        emit EscrowInitiated(msg.sender, escrowAmount);
    }
}
