// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/CommitteeGovernance.sol";
import "../src/Governance.sol";
import "../src/PlatformToken.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract CommitteeGovernanceTest is Test {
    CommitteeGovernance public committeeGov;
    Governance public governance;
    PlatformToken public token;
    address public owner;
    address public alice;
    address public bob;

    bytes4 constant TEST_FUNCTION = bytes4(keccak256("test()"));
    bytes32 constant COMMITTEE_ADMIN_ROLE = keccak256("COMMITTEE_ADMIN_ROLE");

    function setUp() public {
        owner = address(this);
        alice = address(0x1);
        bob = address(0x2);

        // Deploy contracts
        token = new PlatformToken();
        governance = new Governance(address(token));
        committeeGov = new CommitteeGovernance(address(governance));

        // Setup roles
        committeeGov.grantRole(COMMITTEE_ADMIN_ROLE, owner);
    }

    function testCreateCommittee() public {
        string memory name = "Technical Committee";
        string memory description = "Reviews technical proposals";
        uint256 multiplier = 500; // 5x voting power

        committeeGov.createCommittee(name, description, multiplier);

        // Verify committee creation
        (string memory storedName,, uint256 storedMultiplier, bool active) = committeeGov.committees(0);

        assertEq(storedName, name, "Committee name mismatch");
        assertEq(storedMultiplier, multiplier, "Multiplier mismatch");
        assertTrue(active, "Committee should be active");
    }

    function testAddMember() public {
        // Create committee
        committeeGov.createCommittee("Test Committee", "Test Description", 500);

        // Add member
        committeeGov.addMember(0, alice);

        // Verify membership
        assertTrue(committeeGov.isMember(0, alice), "Member not added");
        assertEq(committeeGov.getVotingPowerMultiplier(0, alice), 500, "Wrong voting power multiplier");
    }

    function testRemoveMember() public {
        // Create committee and add member
        committeeGov.createCommittee("Test Committee", "Test Description", 500);
        committeeGov.addMember(0, alice);

        // Remove member
        committeeGov.removeMember(0, alice);

        // Verify membership removed
        assertFalse(committeeGov.isMember(0, alice), "Member not removed");
        assertEq(committeeGov.getVotingPowerMultiplier(0, alice), 0, "Voting power should be 0");
    }

    function testAllowFunction() public {
        // Create committee
        committeeGov.createCommittee("Test Committee", "Test Description", 500);

        // Allow function
        committeeGov.allowFunction(0, TEST_FUNCTION);

        // Verify function allowed
        assertTrue(committeeGov.isFunctionAllowed(0, TEST_FUNCTION), "Function not allowed");
    }

    function testOnlyAdminCanCreateCommittee() public {
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(alice),
                " is missing role ",
                Strings.toHexString(uint256(COMMITTEE_ADMIN_ROLE), 32)
            )
        );
        committeeGov.createCommittee("Test Committee", "Test Description", 500);
        vm.stopPrank();
    }

    function testInvalidCommitteeId() public {
        vm.expectRevert("Committee does not exist");
        committeeGov.addMember(999, alice);
    }

    function testDuplicateMember() public {
        // Create committee and add member
        committeeGov.createCommittee("Test Committee", "Test Description", 500);
        committeeGov.addMember(0, alice);

        // Try to add same member again
        vm.expectRevert("Already a member");
        committeeGov.addMember(0, alice);
    }

    function testRemoveNonMember() public {
        // Create committee
        committeeGov.createCommittee("Test Committee", "Test Description", 500);

        // Try to remove non-member
        vm.expectRevert("Not a member");
        committeeGov.removeMember(0, alice);
    }

    function testMaxVotingPowerMultiplier() public {
        // Try to create committee with too high multiplier
        vm.expectRevert("Multiplier cannot exceed 100x");
        committeeGov.createCommittee("Test Committee", "Test Description", 10001);
    }
}
