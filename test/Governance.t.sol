// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Governance.sol";
import "../src/PlatformToken.sol";

contract GovernanceTest is Test {
    Governance public governance;
    PlatformToken public token;
    address public owner;
    address public alice;
    address public bob;

    function setUp() public {
        owner = address(this);
        alice = address(0x1);
        bob = address(0x2);

        // Deploy token and governance contracts
        token = new PlatformToken();
        governance = new Governance(address(token));

        // Mint some tokens for testing
        token.mint(alice, 1000 * 10**18);
        token.mint(bob, 500 * 10**18);
    }

    function testCreateProposal() public {
        vm.startPrank(alice);
        governance.createProposal("Test Proposal");
        
        (
            uint256 forVotes,
            uint256 againstVotes,
            uint256 startTime,
            uint256 endTime,
            bool executed
        ) = governance.getProposal(1);

        assertEq(forVotes, 0);
        assertEq(againstVotes, 0);
        assertEq(endTime - startTime, 7 days);
        assertEq(executed, false);
        vm.stopPrank();
    }

    function testVoting() public {
        // Create proposal
        vm.startPrank(alice);
        governance.createProposal("Test Proposal");
        
        // Alice votes in favor
        governance.castVote(1, true);
        
        vm.stopPrank();

        // Bob votes against
        vm.startPrank(bob);
        governance.castVote(1, false);
        
        (uint256 forVotes, uint256 againstVotes,,,,) = governance.getProposal(1);
        
        // Alice has 1000 tokens, Bob has 500 tokens
        assertEq(forVotes, 1000 * 10**18);
        assertEq(againstVotes, 500 * 10**18);
        vm.stopPrank();
    }

    function testExecuteProposal() public {
        // Create and vote on proposal
        vm.startPrank(alice);
        governance.createProposal("Test Proposal");
        governance.castVote(1, true);
        vm.stopPrank();

        // Fast forward past voting period
        vm.warp(block.timestamp + 8 days);
        
        // Execute proposal
        governance.executeProposal(1);
        
        (,,,,bool executed) = governance.getProposal(1);
        assertTrue(executed);
    }

    function testFailDoubleVote() public {
        vm.startPrank(alice);
        governance.createProposal("Test Proposal");
        governance.castVote(1, true);
        
        // This should fail
        governance.castVote(1, false);
        vm.stopPrank();
    }

    function testFailInsufficientTokens() public {
        // Charlie has no tokens
        address charlie = address(0x3);
        vm.startPrank(charlie);
        
        // This should fail
        governance.createProposal("Test Proposal");
        vm.stopPrank();
    }

    function testFailVoteAfterEnd() public {
        vm.startPrank(alice);
        governance.createProposal("Test Proposal");
        
        // Fast forward past voting period
        vm.warp(block.timestamp + 8 days);
        
        // This should fail
        governance.castVote(1, true);
        vm.stopPrank();
    }
}
