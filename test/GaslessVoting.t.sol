// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/GaslessVoting.sol";
import "../src/Governance.sol";
import "../src/PlatformToken.sol";

contract GaslessVotingTest is Test {
    Governance public governance;
    PlatformToken public token;
    address public owner;
    address public alice;
    address public bob;

    // Test private key and address
    uint256 constant VOTER_PRIVATE_KEY = 0xA11CE;
    address voter;

    function setUp() public {
        owner = address(this);
        alice = address(0x1);
        bob = address(0x2);
        voter = vm.addr(VOTER_PRIVATE_KEY);

        // Deploy token and governance
        token = new PlatformToken();
        governance = new Governance(address(token));

        // Setup initial token balances
        token.transfer(alice, 1000 * 10 ** 18);
        token.transfer(bob, 1000 * 10 ** 18);
        token.transfer(voter, 1000 * 10 ** 18);
    }

    function testGaslessVoting() public {
        // Create a proposal
        vm.startPrank(alice);
        governance.createProposal(
            "Test Proposal", address(token), abi.encodeWithSignature("transfer(address,uint256)", bob, 100)
        );
        vm.stopPrank();

        // Prepare vote permit
        GaslessVoting.VotePermit memory permit = GaslessVoting.VotePermit({
            voter: voter,
            proposalId: 1,
            support: true,
            nonce: governance.getNonce(voter),
            deadline: block.timestamp + 1 days
        });

        // Sign the permit
        bytes32 structHash = keccak256(
            abi.encode(
                governance.VOTE_PERMIT_TYPEHASH(),
                permit.voter,
                permit.proposalId,
                permit.support,
                permit.nonce,
                permit.deadline
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", governance.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(VOTER_PRIVATE_KEY, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Submit gasless vote
        governance.castVoteWithPermit(permit, signature);

        // Verify vote was counted
        (uint256 forVotes, uint256 againstVotes,,,) = governance.getProposal(1);
        assertEq(forVotes, token.balanceOf(voter), "Vote not counted correctly");
        assertEq(againstVotes, 0, "Against votes should be 0");
    }

    function testInvalidSignature() public {
        // Create a proposal
        vm.startPrank(alice);
        governance.createProposal(
            "Test Proposal", address(token), abi.encodeWithSignature("transfer(address,uint256)", bob, 100)
        );
        vm.stopPrank();

        // Prepare vote permit with wrong signer
        GaslessVoting.VotePermit memory permit = GaslessVoting.VotePermit({
            voter: voter,
            proposalId: 1,
            support: true,
            nonce: governance.getNonce(voter),
            deadline: block.timestamp + 1 days
        });

        // Sign with wrong key
        bytes32 structHash = keccak256(
            abi.encode(
                governance.VOTE_PERMIT_TYPEHASH(),
                permit.voter,
                permit.proposalId,
                permit.support,
                permit.nonce,
                permit.deadline
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", governance.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xBAD, digest); // Wrong private key
        bytes memory signature = abi.encodePacked(r, s, v);

        // Expect revert on invalid signature
        vm.expectRevert("GaslessVoting: invalid signature");
        governance.castVoteWithPermit(permit, signature);
    }

    function testExpiredPermit() public {
        // Create a proposal
        vm.startPrank(alice);
        governance.createProposal(
            "Test Proposal", address(token), abi.encodeWithSignature("transfer(address,uint256)", bob, 100)
        );
        vm.stopPrank();

        // Prepare expired vote permit
        GaslessVoting.VotePermit memory permit = GaslessVoting.VotePermit({
            voter: voter,
            proposalId: 1,
            support: true,
            nonce: governance.getNonce(voter),
            deadline: block.timestamp - 1 // Expired
        });

        // Sign the permit
        bytes32 structHash = keccak256(
            abi.encode(
                governance.VOTE_PERMIT_TYPEHASH(),
                permit.voter,
                permit.proposalId,
                permit.support,
                permit.nonce,
                permit.deadline
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", governance.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(VOTER_PRIVATE_KEY, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Expect revert on expired permit
        vm.expectRevert("GaslessVoting: expired deadline");
        governance.castVoteWithPermit(permit, signature);
    }

    function testReplayProtection() public {
        // Create a proposal
        vm.startPrank(alice);
        governance.createProposal(
            "Test Proposal", address(token), abi.encodeWithSignature("transfer(address,uint256)", bob, 100)
        );
        vm.stopPrank();

        // Prepare vote permit
        GaslessVoting.VotePermit memory permit = GaslessVoting.VotePermit({
            voter: voter,
            proposalId: 1,
            support: true,
            nonce: governance.getNonce(voter),
            deadline: block.timestamp + 1 days
        });

        // Sign the permit
        bytes32 structHash = keccak256(
            abi.encode(
                governance.VOTE_PERMIT_TYPEHASH(),
                permit.voter,
                permit.proposalId,
                permit.support,
                permit.nonce,
                permit.deadline
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", governance.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(VOTER_PRIVATE_KEY, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Submit first vote
        governance.castVoteWithPermit(permit, signature);

        // Attempt replay attack
        vm.expectRevert("GaslessVoting: invalid nonce");
        governance.castVoteWithPermit(permit, signature);
    }
}
