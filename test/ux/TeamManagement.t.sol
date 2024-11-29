// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TeamManagement} from "../../src/ux/TeamManagement.sol";

contract TeamManagementTest is Test {
    TeamManagement public teamManagement;
    address public projectAddress;
    address public teamMember1;
    address public teamMember2;

    function setUp() public {
        teamManagement = new TeamManagement();
        projectAddress = makeAddr("testProject");
        teamMember1 = makeAddr("teamMember1");
        teamMember2 = makeAddr("teamMember2");
    }

    function testAddTeamMember() public {
        // Add team member
        teamManagement.addTeamMember(
            projectAddress, teamMember1, "John Doe", "john@example.com", TeamManagement.TeamRole.Admin
        );

        // Retrieve team members for the project
        TeamManagement.TeamMember[] memory teamMembers = teamManagement.getProjectTeamMembers(projectAddress);

        // Verify team member details
        assertEq(teamMembers.length, 1);
        assertEq(teamMembers[0].memberAddress, teamMember1);
        assertEq(teamMembers[0].name, "John Doe");
        assertEq(teamMembers[0].email, "john@example.com");
        assertEq(uint256(teamMembers[0].role), uint256(TeamManagement.TeamRole.Admin));
        assertTrue(teamMembers[0].isActive);
    }

    function testCannotAddDuplicateTeamMember() public {
        // First addition should succeed
        teamManagement.addTeamMember(
            projectAddress, teamMember1, "John Doe", "john@example.com", TeamManagement.TeamRole.Admin
        );

        // Second addition with same address should revert
        vm.expectRevert("Member already exists");
        teamManagement.addTeamMember(
            projectAddress, teamMember1, "John Doe Duplicate", "john2@example.com", TeamManagement.TeamRole.Member
        );
    }

    function testCreateAndRevokeDelegation() public {
        // Create delegation
        uint256 validUntil = block.timestamp + 1 days;
        vm.prank(teamMember1);
        teamManagement.createDelegation(teamMember2, validUntil);

        // Verify delegation
        assertTrue(teamManagement.isDelegationActive(teamMember1));
        assertEq(teamManagement.getDelegatee(teamMember1), teamMember2);

        // Revoke delegation
        vm.prank(teamMember1);
        teamManagement.revokeDelegation();

        // Verify revocation
        assertFalse(teamManagement.isDelegationActive(teamMember1));
        assertEq(teamManagement.getDelegatee(teamMember1), teamMember1);
    }

    function testDelegationExpiration() public {
        // Create delegation that will expire soon
        uint256 validUntil = block.timestamp + 1;
        vm.prank(teamMember1);
        teamManagement.createDelegation(teamMember2, validUntil);

        // Fast forward time
        vm.warp(block.timestamp + 2);

        // Delegation should no longer be active
        assertFalse(teamManagement.isDelegationActive(teamMember1));
        assertEq(teamManagement.getDelegatee(teamMember1), teamMember1);
    }

    function testCannotCreateInvalidDelegation() public {
        // Try to create delegation in the past
        vm.expectRevert("Invalid delegation period");
        vm.prank(teamMember1);
        teamManagement.createDelegation(teamMember2, block.timestamp - 1);
    }
}
