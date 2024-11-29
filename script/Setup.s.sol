// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {UserProfile} from "../src/UserProfile.sol";
import {QuadraticFunding} from "../src/QuadraticFunding.sol";
import {Project} from "../src/Project.sol";
import {PlatformToken} from "../src/PlatformToken.sol";

contract SetupScript is Script {
    // Contract addresses from deployment
    address public platformToken = 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9;
    address public userProfile = 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707;
    address payable public project = payable(0x0165878A594ca255338adfa4d48449f69242Eb8F);
    address public quadraticFunding = 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        // 1. Setup UserProfile
        UserProfile(userProfile).createProfile("Deployer", "A sample deployer bio", "IPFS://profile-metadata");
        console2.log("Created profile for deployer:", deployer);

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

        Project(project).createProject(
            "Sample Project",
            "A sample project description",
            descriptions,
            funding,
            votes
        );
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
