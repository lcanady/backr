// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {UserProfile} from "../src/UserProfile.sol";
import {QuadraticFunding} from "../src/QuadraticFunding.sol";
import {Project} from "../src/Project.sol";
import {PlatformToken} from "../src/PlatformToken.sol";

contract SetupScript is Script {
    // Contract addresses from deployment
    address public platformToken = 0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82;
    address public userProfile = 0x9A676e781A523b5d0C0e43731313A708CB607508;
    address payable public project = payable(0x0B306BF915C4d645ff596e518fAf3F9669b97016);
    address public quadraticFunding = 0x959922bE3CAee4b8Cd9a407cc3ac1C251C2007B1;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        // 1. Setup UserProfile
        UserProfile userProfileContract = UserProfile(userProfile);
        
        // Create deployer's profile
        userProfileContract.createProfile(
            "Deployer",
            "A sample deployer bio",
            "IPFS://profile-metadata"
        );
        console2.log("Created profile for deployer:", deployer);

        // Grant roles
        bytes32 reputationManagerRole = userProfileContract.REPUTATION_MANAGER_ROLE();
        bytes32 verifierRole = userProfileContract.VERIFIER_ROLE();
        
        userProfileContract.grantRole(reputationManagerRole, deployer);
        userProfileContract.grantRole(verifierRole, deployer);
        console2.log("Granted reputation manager and verifier roles to deployer");

        // Set recovery address
        userProfileContract.setRecoveryAddress(deployer);
        console2.log("Set recovery address for deployer's profile");

        // Update reputation score
        userProfileContract.updateReputation(deployer, 100);
        console2.log("Updated deployer's reputation score to 100");

        // Verify the profile
        userProfileContract.verifyProfile(deployer);
        console2.log("Verified deployer's profile");

        // 2. Setup initial funding round in QuadraticFunding
        QuadraticFunding qf = QuadraticFunding(quadraticFunding);

        // Configure round parameters
        QuadraticFunding.RoundConfig memory config = QuadraticFunding.RoundConfig({
            startTime: block.timestamp,
            endTime: block.timestamp + 14 days,
            minContribution: 0.01 ether,
            maxContribution: 10 ether
        });

        // Create round with 10 ETH matching pool
        qf.createRound{value: 10 ether}(config);
        console2.log("Created initial funding round with 10 ETH matching pool");

        // 3. Create a sample project
        string[] memory descriptions = new string[](1);
        descriptions[0] = "First milestone";
        uint256[] memory funding = new uint256[](1);
        funding[0] = 1 ether;
        uint256[] memory votes = new uint256[](1);
        votes[0] = 10;

        Project(project).createProject("Sample Project", "A sample project description", descriptions, funding, votes);
        console2.log("Created sample project");

        // 4. Verify deployer as eligible participant
        qf.verifyParticipant(deployer, true);
        console2.log("Verified deployer as eligible participant");

        // 5. Make initial contribution to sample project
        qf.contribute{value: 1 ether}(0); // projectId 0
        console2.log("Made initial contribution of 1 ETH to sample project");

        vm.stopBroadcast();

        // Log final setup state
        console2.log("\nSetup Complete!");
        console2.log("=================");
        console2.log("PlatformToken:", platformToken);
        console2.log("UserProfile:", userProfile);
        console2.log("Project:", project);
        console2.log("QuadraticFunding:", quadraticFunding);
    }
}
