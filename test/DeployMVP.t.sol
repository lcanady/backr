// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../script/DeployMVP.s.sol";

contract DeployMVPTest is Test {
    DeployMVP public deployer;
    address public constant DEPLOYER = address(1);
    uint256 public constant INITIAL_ETH = 1000 ether;

    function setUp() public {
        deployer = new DeployMVP();
        vm.deal(DEPLOYER, INITIAL_ETH);
        vm.startPrank(DEPLOYER);
    }

    function testDeployment() public {
        // Set environment variable for deployment
        vm.setEnv("PRIVATE_KEY", "1"); // Corresponds to DEPLOYER address

        // Run deployment
        deployer.run();

        // Get deployed contracts
        PlatformToken token = deployer.token();
        UserProfile userProfile = deployer.userProfile();
        Project project = deployer.project();
        QuadraticFunding qf = deployer.qf();
        Badge badge = deployer.badge();
        BadgeMarketplace marketplace = deployer.marketplace();
        Governance governance = deployer.governance();
        SecurityControls securityControls = deployer.securityControls();

        // Test 1: Verify all contracts are deployed
        assertTrue(address(token) != address(0), "Token not deployed");
        assertTrue(address(userProfile) != address(0), "UserProfile not deployed");
        assertTrue(address(project) != address(0), "Project not deployed");
        assertTrue(address(qf) != address(0), "QuadraticFunding not deployed");
        assertTrue(address(badge) != address(0), "Badge not deployed");
        assertTrue(address(marketplace) != address(0), "BadgeMarketplace not deployed");
        assertTrue(address(governance) != address(0), "Governance not deployed");
        assertTrue(address(securityControls) != address(0), "SecurityControls not deployed");

        // Test 2: Verify UserProfile setup
        assertTrue(userProfile.hasProfile(DEPLOYER), "Deployer profile not created");
        UserProfile.Profile memory profile = userProfile.getProfile(DEPLOYER);
        assertTrue(profile.isVerified, "Deployer profile not verified");
        assertTrue(
            userProfile.hasRole(userProfile.REPUTATION_MANAGER_ROLE(), DEPLOYER), "Missing reputation manager role"
        );
        assertTrue(userProfile.hasRole(userProfile.VERIFIER_ROLE(), DEPLOYER), "Missing verifier role");
        assertEq(profile.reputationScore, 100, "Incorrect reputation score");

        // Test 3: Verify Security Controls setup
        // Check rate limits
        bytes32 projectCreationOp = keccak256("PROJECT_CREATION");
        bytes32 qfContributionOp = keccak256("QF_CONTRIBUTION");

        (uint256 projectLimit, uint256 projectWindow,,) = securityControls.rateLimits(projectCreationOp);
        (uint256 qfLimit, uint256 qfWindow,,) = securityControls.rateLimits(qfContributionOp);

        assertEq(projectLimit, deployer.PROJECT_CREATION_LIMIT(), "Incorrect project creation limit");
        assertEq(qfLimit, deployer.QF_CONTRIBUTION_LIMIT(), "Incorrect QF contribution limit");
        assertEq(projectWindow, deployer.RATE_LIMIT_WINDOW(), "Incorrect project window");
        assertEq(qfWindow, deployer.RATE_LIMIT_WINDOW(), "Incorrect QF window");

        // Check roles
        assertTrue(
            securityControls.hasRole(securityControls.OPERATOR_ROLE(), address(project)),
            "Project missing operator role"
        );
        assertTrue(securityControls.hasRole(securityControls.OPERATOR_ROLE(), address(qf)), "QF missing operator role");
        assertTrue(
            securityControls.hasRole(securityControls.EMERGENCY_ROLE(), address(governance)),
            "Governance missing emergency role"
        );

        // Test 4: Verify Badge setup
        assertEq(badge.owner(), address(marketplace), "Incorrect badge owner");

        // Test 5: Verify QuadraticFunding setup
        assertEq(address(qf).balance, deployer.INITIAL_QF_POOL(), "Incorrect QF pool balance");
        assertTrue(qf.currentRound() > 0, "No QF round created");

        // Test 6: Verify Governance setup
        assertEq(
            token.balanceOf(address(governance)),
            deployer.INITIAL_GOVERNANCE_TOKENS(),
            "Incorrect governance token balance"
        );

        // Test 7: Verify Project setup
        (
            address creator,
            string memory title,
            string memory description,
            ,
            ,
            , // Skip unused variables
            bool isActive,
        ) = project.projects(0);

        assertTrue(isActive, "Sample project not active");
        assertEq(creator, DEPLOYER, "Incorrect project creator");
        assertEq(title, "Sample Project", "Incorrect project title");
        assertEq(description, "A demonstration project for the Backr protocol", "Incorrect project description");
        assertEq(project.totalProjects(), 1, "Incorrect total projects");
    }

    function testDeploymentRevert() public {
        // Test deployment without private key should revert
        vm.expectRevert();
        deployer.run();
    }

    function testEmergencyControls() public {
        vm.setEnv("PRIVATE_KEY", "1");
        deployer.run();

        SecurityControls securityControls = deployer.securityControls();

        // Get multi-sig config for emergency actions
        bytes32 emergencyAction = keccak256("EMERGENCY_ACTION");
        (uint256 requiredApprovals, address[] memory approvers) = securityControls.getMultiSigConfig(emergencyAction);

        // Verify multi-sig configuration
        assertEq(requiredApprovals, 2, "Incorrect required approvals");
        assertEq(approvers.length, 3, "Incorrect number of approvers");
        assertEq(approvers[0], DEPLOYER, "Incorrect approver 0");
        assertEq(approvers[1], address(deployer.governance()), "Incorrect approver 1");
        assertEq(approvers[2], address(deployer.project()), "Incorrect approver 2");
    }
}
