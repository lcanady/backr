// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {UserProfile} from "../src/UserProfile.sol";
import {QuadraticFunding} from "../src/QuadraticFunding.sol";
import {Project} from "../src/Project.sol";
import {PlatformToken} from "../src/PlatformToken.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy PlatformToken first
        PlatformToken token = new PlatformToken();
        console2.log("PlatformToken deployed to:", address(token));

        // Deploy UserProfile
        UserProfile userProfile = new UserProfile();
        console2.log("UserProfile deployed to:", address(userProfile));

        // Deploy Project contract with UserProfile dependency
        Project project = new Project(address(userProfile));
        console2.log("Project deployed to:", address(project));

        // Deploy QuadraticFunding with dependencies
        QuadraticFunding qf = new QuadraticFunding(payable(address(project)));
        console2.log("QuadraticFunding deployed to:", address(qf));

        vm.stopBroadcast();
    }
}
