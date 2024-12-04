// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {UserProfile} from "../src/UserProfile.sol";
import {QuadraticFunding} from "../src/QuadraticFunding.sol";
import {Project} from "../src/Project.sol";
import {PlatformToken} from "../src/PlatformToken.sol";
import {Badge} from "../src/Badge.sol";
import {BadgeMarketplace} from "../src/BadgeMarketplace.sol";
import {Governance} from "../src/Governance.sol";
import {SecurityControls} from "../src/SecurityControls.sol";

contract DeployMVP is Script {
    // Contract instances
    PlatformToken public token;
    UserProfile public userProfile;
    Project public project;
    QuadraticFunding public qf;
    Badge public badge;
    BadgeMarketplace public marketplace;
    Governance public governance;
    SecurityControls public securityControls;

    // Funding constants
    uint256 public constant INITIAL_QF_POOL = 10 ether;
    uint256 public constant INITIAL_GOVERNANCE_TOKENS = 1_000_000 ether;

    // Security constants
    uint256 public constant RATE_LIMIT_WINDOW = 1 days;
    uint256 public constant PROJECT_CREATION_LIMIT = 10;
    uint256 public constant QF_CONTRIBUTION_LIMIT = 100;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy core contracts
        token = new PlatformToken();
        console2.log("PlatformToken deployed to:", address(token));

        userProfile = new UserProfile();
        console2.log("UserProfile deployed to:", address(userProfile));

        project = new Project(address(userProfile));
        console2.log("Project deployed to:", address(project));

        qf = new QuadraticFunding(payable(address(project)));
        console2.log("QuadraticFunding deployed to:", address(qf));

        // 2. Deploy badge system
        badge = new Badge();
        console2.log("Badge deployed to:", address(badge));

        marketplace = new BadgeMarketplace(address(badge));
        console2.log("BadgeMarketplace deployed to:", address(marketplace));

        // 3. Deploy governance and security
        governance = new Governance(address(token));
        console2.log("Governance deployed to:", address(governance));

        securityControls = new SecurityControls();
        console2.log("SecurityControls deployed to:", address(securityControls));

        // 4. Setup permissions and configurations

        // 4.1 Badge permissions
        badge.transferOwnership(address(marketplace));
        console2.log("Transferred Badge ownership to marketplace");

        // 4.2 Security controls setup
        // Setup rate limits for key operations
        bytes32 projectCreationOp = keccak256("PROJECT_CREATION");
        bytes32 qfContributionOp = keccak256("QF_CONTRIBUTION");
        
        securityControls.configureRateLimit(
            projectCreationOp,
            PROJECT_CREATION_LIMIT,
            RATE_LIMIT_WINDOW
        );
        securityControls.configureRateLimit(
            qfContributionOp,
            QF_CONTRIBUTION_LIMIT,
            RATE_LIMIT_WINDOW
        );

        // Setup multi-sig configuration for emergency actions
        address[] memory emergencyApprovers = new address[](3);
        emergencyApprovers[0] = deployer;
        emergencyApprovers[1] = address(governance);
        emergencyApprovers[2] = address(project);
        
        securityControls.configureMultiSig(
            keccak256("EMERGENCY_ACTION"),
            2, // Require 2 out of 3 approvals
            emergencyApprovers
        );

        // Grant roles
        securityControls.grantRole(securityControls.OPERATOR_ROLE(), address(project));
        securityControls.grantRole(securityControls.OPERATOR_ROLE(), address(qf));
        securityControls.grantRole(securityControls.EMERGENCY_ROLE(), address(governance));
        
        console2.log("Setup security controls and permissions");

        // 5. Initial funding and setup

        // 5.1 Setup UserProfile
        userProfile.createProfile("Deployer", "Protocol Deployer", "IPFS://deployer-profile");
        userProfile.grantRole(userProfile.REPUTATION_MANAGER_ROLE(), deployer);
        userProfile.grantRole(userProfile.VERIFIER_ROLE(), deployer);
        userProfile.setRecoveryAddress(deployer);
        userProfile.updateReputation(deployer, 100);
        userProfile.verifyProfile(deployer);
        console2.log("Setup deployer profile and permissions");

        // 5.2 Setup initial QF round
        QuadraticFunding.RoundConfig memory config = QuadraticFunding.RoundConfig({
            startTime: block.timestamp,
            endTime: block.timestamp + 14 days,
            minContribution: 0.01 ether,
            maxContribution: 10 ether
        });
        qf.createRound{value: INITIAL_QF_POOL}(config);
        qf.verifyParticipant(deployer, true);
        console2.log("Created initial funding round with", INITIAL_QF_POOL/1e18, "ETH");

        // 5.3 Fund governance treasury
        token.transfer(address(governance), INITIAL_GOVERNANCE_TOKENS);
        console2.log("Funded governance treasury with", INITIAL_GOVERNANCE_TOKENS/1e18, "tokens");

        // 5.4 Create sample project
        string[] memory descriptions = new string[](1);
        descriptions[0] = "Initial milestone";
        uint256[] memory funding = new uint256[](1);
        funding[0] = 1 ether;
        uint256[] memory votes = new uint256[](1);
        votes[0] = 10;

        project.createProject(
            "Sample Project",
            "A demonstration project for the Backr protocol",
            descriptions,
            funding,
            votes
        );
        console2.log("Created sample project");

        vm.stopBroadcast();

        // Log final deployment state
        console2.log("\nDeployment Complete!");
        console2.log("===================");
        console2.log("Core Contracts:");
        console2.log("- PlatformToken:", address(token));
        console2.log("- UserProfile:", address(userProfile));
        console2.log("- Project:", address(project));
        console2.log("- QuadraticFunding:", address(qf));
        console2.log("\nBadge System:");
        console2.log("- Badge:", address(badge));
        console2.log("- BadgeMarketplace:", address(marketplace));
        console2.log("\nGovernance & Security:");
        console2.log("- Governance:", address(governance));
        console2.log("- SecurityControls:", address(securityControls));
    }
}
