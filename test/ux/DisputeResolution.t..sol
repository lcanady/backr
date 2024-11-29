// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DisputeResolution} from "../../src/ux/DisputeResolution.sol";

contract DisputeResolutionTest is Test {
    DisputeResolution public disputeResolution;
    address public projectAddress;
    address public initiator;
    address public respondent;
    address public mediator;

    function setUp() public {
        disputeResolution = new DisputeResolution();
        projectAddress = makeAddr("testProject");
        initiator = makeAddr("initiator");
        respondent = makeAddr("respondent");
        mediator = makeAddr("mediator");

        // Add mediator
        disputeResolution.addMediator(mediator);
    }

    function testInitiateDispute() public {
        // Initiate dispute
        vm.prank(initiator);
        uint256 disputeId = disputeResolution.initiateDispute(
            projectAddress, respondent, DisputeResolution.DisputeCategory.Funding, "Dispute over funding allocation"
        );

        // Retrieve and verify dispute details
        (
            uint256 id,
            address project,
            address disputeInitiator,
            address disputeRespondent,
            DisputeResolution.DisputeCategory category,
            string memory description,
            DisputeResolution.DisputeStatus status,
            uint256 createdAt,
            uint256 resolvedAt,
            address disputeMediator,
            string memory resolution
        ) = disputeResolution.disputes(disputeId);

        assertEq(id, disputeId);
        assertEq(project, projectAddress);
        assertEq(disputeInitiator, initiator);
        assertEq(disputeRespondent, respondent);
        assertEq(uint256(category), uint256(DisputeResolution.DisputeCategory.Funding));
        assertEq(description, "Dispute over funding allocation");
        assertEq(uint256(status), uint256(DisputeResolution.DisputeStatus.Initiated));
        assertGt(createdAt, 0);
        assertEq(resolvedAt, 0);
        assertEq(disputeMediator, address(0));
        assertEq(resolution, "");

        // Verify project disputes
        uint256[] memory projectDisputes = disputeResolution.getProjectDisputes(projectAddress);
        assertEq(projectDisputes.length, 1);
        assertEq(projectDisputes[0], disputeId);
    }

    function testUpdateDisputeStatus() public {
        // Initiate dispute
        vm.prank(initiator);
        uint256 disputeId = disputeResolution.initiateDispute(
            projectAddress, respondent, DisputeResolution.DisputeCategory.Funding, "Dispute over funding allocation"
        );

        // Update dispute status by mediator
        vm.prank(mediator);
        disputeResolution.updateDisputeStatus(disputeId, DisputeResolution.DisputeStatus.UnderReview);

        // Verify status update
        (
            uint256 id,
            address project,
            address initiator,
            address respondent,
            DisputeResolution.DisputeCategory category,
            string memory description,
            DisputeResolution.DisputeStatus status,
            uint256 createdAt,
            uint256 resolvedAt,
            address mediator,
            string memory resolution
        ) = disputeResolution.disputes(disputeId);
        assertEq(uint256(status), uint256(DisputeResolution.DisputeStatus.UnderReview));
    }

    function testResolveDispute() public {
        // Initiate dispute
        vm.prank(initiator);
        uint256 disputeId = disputeResolution.initiateDispute(
            projectAddress, respondent, DisputeResolution.DisputeCategory.Funding, "Dispute over funding allocation"
        );

        // Resolve dispute by mediator
        vm.prank(mediator);
        disputeResolution.resolveDispute(disputeId, "Funding to be split equally between parties");

        // Verify dispute resolution
        (
            uint256 id,
            address project,
            address initiator,
            address respondent,
            DisputeResolution.DisputeCategory category,
            string memory description,
            DisputeResolution.DisputeStatus status,
            uint256 createdAt,
            uint256 resolvedAt,
            address mediator,
            string memory resolution
        ) = disputeResolution.disputes(disputeId);

        assertEq(uint256(status), uint256(DisputeResolution.DisputeStatus.Resolved));
        assertGt(resolvedAt, 0);
        assertEq(resolution, "Funding to be split equally between parties");
    }

    function testCannotUpdateStatusByNonMediator() public {
        // Initiate dispute
        vm.prank(initiator);
        uint256 disputeId = disputeResolution.initiateDispute(
            projectAddress, respondent, DisputeResolution.DisputeCategory.Funding, "Dispute over funding allocation"
        );

        // Try to update status by non-mediator
        vm.expectRevert("Not an approved mediator");
        disputeResolution.updateDisputeStatus(disputeId, DisputeResolution.DisputeStatus.UnderReview);
    }
}
