// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {UserProfile} from "../src/UserProfile.sol";
import {QuadraticFunding} from "../src/QuadraticFunding.sol";
import {Project} from "../src/Project.sol";
import {PlatformToken} from "../src/PlatformToken.sol";
import {LiquidityPool} from "../src/LiquidityPool.sol";
import {LiquidityIncentives} from "../src/LiquidityIncentives.sol";
import {Badge} from "../src/Badge.sol";
import {BadgeMarketplace} from "../src/BadgeMarketplace.sol";

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

        // Deploy liquidity incentives contract
        LiquidityIncentives incentives = new LiquidityIncentives(
            address(token),
            address(0) // Will be updated after LiquidityPool deployment
        );

        // Deploy liquidity pool with incentives
        LiquidityPool pool = new LiquidityPool(
            address(token),
            1000, // Minimum liquidity
            address(incentives)
        );

        // Update liquidity pool address in incentives contract
        incentives.updateLiquidityPool(address(pool));

        // Initialize pools in incentives contract
        incentives.createPool(1, 100); // Pool 1: 100 tokens per second
        incentives.createPool(2, 200); // Pool 2: 200 tokens per second
        incentives.createPool(3, 300); // Pool 3: 300 tokens per second

        // Deploy Badge contract
        Badge badge = new Badge();
        console2.log("Badge deployed to:", address(badge));

        // Deploy BadgeMarketplace with Badge contract dependency
        BadgeMarketplace marketplace = new BadgeMarketplace(address(badge));
        console2.log("BadgeMarketplace deployed to:", address(marketplace));

        // Set BadgeMarketplace as an authorized operator for Badge contract
        badge.transferOwnership(address(marketplace));

        vm.stopBroadcast();
    }
}
