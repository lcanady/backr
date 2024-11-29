// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Governance.sol";
import "../src/PlatformToken.sol";

// Mock contract for testing proposal execution
contract MockTarget {
    uint256 public value;

    function setValue(uint256 _value) external {
        value = _value;
    }
}

contract GovernanceTest is Test {
    Governance public governance;
    PlatformToken public token;
    address public owner;
    address public alice;
    address public bob;
    MockTarget public mockTarget;
    uint256 public constant EXECUTION_DELAY = 2 days;

    function setUp() public {
        owner = address(this);
        alice = address(0x1);
        bob = address(0x2);

        // Deploy token and governance contracts
        token = new PlatformToken();
        governance = new Governance(address(token));
        mockTarget = new MockTarget();

        // Transfer some tokens for testing
        vm.startPrank(owner);
        token.transfer(alice, 1000 * 10 ** 18);
        token.transfer(bob, 500 * 10 ** 18);
        vm.stopPrank();
    }

    function testCreateProposal() public {
        vm.startPrank(alice);
        token.approve(address(governance), type(uint256).max);
        bytes memory callData = abi.encodeWithSignature("setValue(uint256)", 42);
        governance.createProposal("Test Proposal", address(mockTarget), callData);

        (uint256 forVotes, uint256 againstVotes, uint256 _startTime, uint256 _endTime, bool executed) =
            governance.getProposal(1);

        assertEq(forVotes, 0);
        assertEq(againstVotes, 0);
        assertEq(_endTime - _startTime, 7 days);
        assertEq(executed, false);
        vm.stopPrank();
    }

    function testVotingPowerSnapshot() public {
        // Create proposal
        vm.startPrank(alice);
        token.approve(address(governance), type(uint256).max);
        bytes memory callData = abi.encodeWithSignature("setValue(uint256)", 42);
        governance.createProposal("Test Proposal", address(mockTarget), callData);

        // Alice votes with 1000 tokens
        governance.castVote(1, true);

        // Transfer 500 tokens to bob after voting
        token.transfer(bob, 500 * 10 ** 18);
        vm.stopPrank();

        // Check that Alice's vote still counts as 1000 tokens despite transfer
        (uint256 forVotes, uint256 againstVotes,,,) = governance.getProposal(1);
        assertEq(forVotes, 1000 * 10 ** 18);
        assertEq(againstVotes, 0);
    }

    function testVoting() public {
        // Create proposal
        bytes memory callData = abi.encodeWithSignature("setValue(uint256)", 42);
        vm.startPrank(alice);
        token.approve(address(governance), type(uint256).max);
        governance.createProposal("Test Proposal", address(mockTarget), callData);

        // Alice votes in favor
        governance.castVote(1, true);
        vm.stopPrank();

        // Bob votes against
        vm.startPrank(bob);
        token.approve(address(governance), type(uint256).max);
        governance.castVote(1, false);

        (uint256 forVotes, uint256 againstVotes,,,) = governance.getProposal(1);

        // Alice has 1000 tokens, Bob has 500 tokens
        assertEq(forVotes, 1000 * 10 ** 18);
        assertEq(againstVotes, 500 * 10 ** 18);
        vm.stopPrank();
    }

    function testExecutionDelay() public {
        // Create proposal
        bytes memory callData = abi.encodeWithSignature("setValue(uint256)", 42);
        vm.startPrank(alice);
        token.approve(address(governance), type(uint256).max);
        governance.createProposal("Test Proposal", address(mockTarget), callData);
        governance.castVote(1, true);
        vm.stopPrank();

        // Fast forward past voting period
        vm.warp(block.timestamp + 8 days);

        // Try to execute immediately (should set execution time)
        governance.executeProposal(1);

        // Verify not executed yet
        (,,,, bool executed) = governance.getProposal(1);
        assertEq(executed, false);

        // Fast forward past execution delay
        vm.warp(block.timestamp + EXECUTION_DELAY + 1);

        // Execute proposal
        governance.executeProposal(1);

        // Verify executed
        (,,,, executed) = governance.getProposal(1);
        assertEq(executed, true);
        assertEq(mockTarget.value(), 42);
    }

    function testFailDoubleVote() public {
        // Create proposal
        bytes memory callData = abi.encodeWithSignature("setValue(uint256)", 42);
        vm.startPrank(alice);
        token.approve(address(governance), type(uint256).max);
        governance.createProposal("Test Proposal", address(mockTarget), callData);

        // Vote once
        governance.castVote(1, true);

        // Try to vote again (should fail)
        governance.castVote(1, true);
    }

    function testFailEarlyExecution() public {
        // Create proposal
        bytes memory callData = abi.encodeWithSignature("setValue(uint256)", 42);
        vm.startPrank(alice);
        token.approve(address(governance), type(uint256).max);
        governance.createProposal("Test Proposal", address(mockTarget), callData);
        governance.castVote(1, true);
        vm.stopPrank();

        // Try to execute before voting period ends
        governance.executeProposal(1);
    }

    function testFailExecuteBeforeDelay() public {
        // Create proposal
        bytes memory callData = abi.encodeWithSignature("setValue(uint256)", 42);
        vm.startPrank(alice);
        token.approve(address(governance), type(uint256).max);
        governance.createProposal("Test Proposal", address(mockTarget), callData);
        governance.castVote(1, true);
        vm.stopPrank();

        // Fast forward past voting period
        vm.warp(block.timestamp + 8 days);

        // Set execution time
        governance.executeProposal(1);

        // Try to execute before delay (should fail)
        governance.executeProposal(1);
    }

    function testDelegateVoting() public {
        // Initial setup for delegation
        vm.startPrank(bob);
        token.approve(address(governance), type(uint256).max);
        governance.delegate(alice);
        vm.stopPrank();

        // Verify delegation
        assertEq(governance.delegates(bob), alice);
        assertEq(governance.getVotingPower(alice), 1500 * 10 ** 18); // Alice's 1000 + Bob's 500
        assertEq(governance.getVotingPower(bob), 0);

        // Create and vote on proposal
        bytes memory callData = abi.encodeWithSignature("setValue(uint256)", 42);
        vm.startPrank(alice);
        token.approve(address(governance), type(uint256).max);
        governance.createProposal("Test Proposal", address(mockTarget), callData);
        governance.castVote(1, true);
        vm.stopPrank();

        // Check voting power reflects delegation
        (uint256 forVotes, uint256 againstVotes,,,) = governance.getProposal(1);
        assertEq(forVotes, 1500 * 10 ** 18); // Alice's vote includes Bob's delegated power
        assertEq(againstVotes, 0);
    }

    function testChangeDelegation() public {
        // Initial delegation from Bob to Alice
        vm.startPrank(bob);
        token.approve(address(governance), type(uint256).max);
        governance.delegate(alice);

        // Debug logs
        console.log("After delegating to Alice:");
        console.log("Alice's voting power:", governance.getVotingPower(alice));
        console.log("Bob's voting power:", governance.getVotingPower(bob));
        console.log("Alice's token balance:", token.balanceOf(alice));
        console.log("Bob's token balance:", token.balanceOf(bob));
        console.log("Delegated amount to Alice:", governance.delegatedAmount(alice));

        assertEq(governance.getVotingPower(alice), 1500 * 10 ** 18);

        // Change delegation to owner
        governance.delegate(owner);
        vm.stopPrank();

        // Debug logs
        console.log("\nAfter delegating to owner:");
        console.log("Alice's voting power:", governance.getVotingPower(alice));
        console.log("Bob's voting power:", governance.getVotingPower(bob));
        console.log("Owner's voting power:", governance.getVotingPower(owner));
        console.log("Alice's token balance:", token.balanceOf(alice));
        console.log("Bob's token balance:", token.balanceOf(bob));
        console.log("Owner's token balance:", token.balanceOf(owner));
        console.log("Delegated amount to Alice:", governance.delegatedAmount(alice));
        console.log("Delegated amount to owner:", governance.delegatedAmount(owner));

        // Verify delegation change
        assertEq(governance.delegates(bob), owner);
        assertEq(governance.getVotingPower(alice), 1000 * 10 ** 18); // Alice's original balance
        assertEq(governance.getVotingPower(owner), token.balanceOf(owner) + 500 * 10 ** 18); // Owner's balance + Bob's delegated amount
    }

    function testFailSelfDelegation() public {
        vm.prank(alice);
        governance.delegate(alice); // Should fail
    }

    function testProposalCancellation() public {
        // Create proposal
        bytes memory callData = abi.encodeWithSignature("setValue(uint256)", 42);
        vm.startPrank(alice);
        token.approve(address(governance), type(uint256).max);
        governance.createProposal("Test Proposal", address(mockTarget), callData);

        // Vote on proposal
        governance.castVote(1, true);
        vm.stopPrank();

        vm.prank(bob);
        token.approve(address(governance), type(uint256).max);
        governance.castVote(1, false);

        // Cancel proposal
        vm.prank(alice);
        governance.cancelProposal(1);

        // Verify proposal is cancelled (marked as executed with votes reset)
        (uint256 forVotes, uint256 againstVotes,,,bool executed) = governance.getProposal(1);
        assertEq(forVotes, 0);
        assertEq(againstVotes, 0);
        assertTrue(executed);
    }

    function testOwnerCanCancelProposal() public {
        // Create proposal as Alice
        bytes memory callData = abi.encodeWithSignature("setValue(uint256)", 42);
        vm.startPrank(alice);
        token.approve(address(governance), type(uint256).max);
        governance.createProposal("Test Proposal", address(mockTarget), callData);
        vm.stopPrank();

        // Owner cancels proposal
        governance.cancelProposal(1);

        // Verify proposal is cancelled
        (uint256 forVotes, uint256 againstVotes,,,bool executed) = governance.getProposal(1);
        assertEq(forVotes, 0);
        assertEq(againstVotes, 0);
        assertTrue(executed);
    }

    function testFailNonOwnerNonProposerCancelProposal() public {
        // Create proposal as Alice
        bytes memory callData = abi.encodeWithSignature("setValue(uint256)", 42);
        vm.startPrank(alice);
        token.approve(address(governance), type(uint256).max);
        governance.createProposal("Test Proposal", address(mockTarget), callData);
        vm.stopPrank();

        // Bob tries to cancel (should fail)
        vm.prank(bob);
        governance.cancelProposal(1);
    }

    function testFailCancelExecutedProposal() public {
        // Create and execute proposal
        bytes memory callData = abi.encodeWithSignature("setValue(uint256)", 42);
        vm.startPrank(alice);
        token.approve(address(governance), type(uint256).max);
        governance.createProposal("Test Proposal", address(mockTarget), callData);
        governance.castVote(1, true);
        vm.stopPrank();

        // Fast forward past voting period and execution delay
        vm.warp(block.timestamp + 8 days);
        governance.executeProposal(1);
        vm.warp(block.timestamp + EXECUTION_DELAY + 1);
        governance.executeProposal(1);

        // Try to cancel executed proposal (should fail)
        vm.prank(alice);
        governance.cancelProposal(1);
    }
}
