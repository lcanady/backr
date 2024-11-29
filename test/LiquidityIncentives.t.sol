// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/LiquidityIncentives.sol";
import "../src/LiquidityPool.sol";
import "../src/PlatformToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockFlashLoanReceiver is IFlashLoanReceiver {
    PlatformToken public token;
    LiquidityIncentives public incentives;
    bool public shouldRepay;

    constructor(address _token, address _incentives) {
        token = PlatformToken(_token);
        incentives = LiquidityIncentives(_incentives);
        shouldRepay = true;
    }

    function executeOperation(uint256 amount, uint256 fee, bytes calldata) external {
        require(msg.sender == address(incentives), "Caller must be incentives contract");

        if (shouldRepay) {
            // Calculate total repayment
            uint256 totalRepayment = amount + fee;

            // Verify we have enough balance for repayment
            uint256 balance = token.balanceOf(address(this));
            require(balance >= totalRepayment, "Insufficient balance for repayment");

            // Approve and transfer the repayment
            token.approve(address(incentives), totalRepayment);
            require(token.transfer(address(incentives), totalRepayment), "Repayment transfer failed");
        }
        // If shouldRepay is false, we don't repay, which should cause the flash loan to fail
    }

    function setShouldRepay(bool _shouldRepay) external {
        shouldRepay = _shouldRepay;
    }

    receive() external payable {}
}

contract LiquidityIncentivesTest is Test {
    LiquidityIncentives public incentives;
    LiquidityPool public pool;
    PlatformToken public token;
    MockFlashLoanReceiver public flashLoanReceiver;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public carol = address(0x3);

    function setUp() public {
        // Deploy contracts
        token = new PlatformToken();
        incentives = new LiquidityIncentives(address(token), address(0));

        // Transfer ownership of both contracts to the test contract
        token.transferOwnership(address(this));
        incentives.transferOwnership(address(this));

        pool = new LiquidityPool(address(token), 1000, address(incentives));
        incentives.updateLiquidityPool(address(pool));

        flashLoanReceiver = new MockFlashLoanReceiver(address(token), address(incentives));

        // Mint initial tokens with larger amounts
        token.mint(alice, 1000000e18);
        token.mint(bob, 1000000e18);
        token.mint(carol, 1000000e18);
        token.mint(address(incentives), 10000000e18); // Much larger amount for incentives

        // Setup approvals
        vm.startPrank(alice);
        token.approve(address(pool), type(uint256).max);
        token.approve(address(incentives), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(address(pool), type(uint256).max);
        token.approve(address(incentives), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(carol);
        token.approve(address(pool), type(uint256).max);
        token.approve(address(incentives), type(uint256).max);
        vm.stopPrank();

        // Setup initial pools
        incentives.createPool(1, 10e18); // 10 tokens per second
        incentives.createPool(2, 20e18); // 20 tokens per second

        // Initialize pool with some liquidity
        vm.startPrank(address(this));
        token.mint(address(this), 1000000e18);
        token.approve(address(pool), type(uint256).max);
        pool.addLiquidity{value: 100 ether}(100000e18);
        vm.stopPrank();

        // Deal ETH to test addresses
        vm.deal(alice, 1000 ether);
        vm.deal(bob, 1000 ether);
        vm.deal(carol, 1000 ether);
    }

    function testTierSystem() public {
        // Start with tier 0
        vm.startPrank(alice);

        // Test tier 1 (0.001 tokens minimum)
        token.approve(address(pool), type(uint256).max);
        pool.addLiquidity{value: 1 ether}(1000e15);
        vm.stopPrank();

        incentives.manualUpdateUserTier(alice, 1000e15);
        uint256 aliceTier = incentives.userTiers(alice);
        assertEq(aliceTier, 1, "Should be tier 1");

        // Test tier 2 (0.01 tokens minimum)
        vm.startPrank(alice);
        pool.addLiquidity{value: 1 ether}(10000e15);
        vm.stopPrank();

        incentives.manualUpdateUserTier(alice, 11000e15);
        aliceTier = incentives.userTiers(alice);
        assertEq(aliceTier, 2, "Should be tier 2");

        // Test tier 3 (0.1 tokens minimum)
        vm.startPrank(alice);
        pool.addLiquidity{value: 1 ether}(100000e15);
        vm.stopPrank();

        incentives.manualUpdateUserTier(alice, 111000e15);
        aliceTier = incentives.userTiers(alice);
        assertEq(aliceTier, 3, "Should be tier 3");

        // Test tier downgrade
        vm.startPrank(alice);
        pool.removeLiquidity(110000e15);
        vm.stopPrank();

        incentives.manualUpdateUserTier(alice, 1000e15);
        aliceTier = incentives.userTiers(alice);
        assertEq(aliceTier, 1, "Should downgrade to tier 1");
    }

    function testFlashLoan() public {
        uint256 loanAmount = 100e18;
        uint256 flashLoanFee = (loanAmount * 30) / 10000; // 0.3% fee for tier 1
        uint256 totalRequired = loanAmount + flashLoanFee;

        // Setup flash loan receiver with enough tokens for repayment and liquidity
        token.mint(address(flashLoanReceiver), totalRequired + 2000e18); // Extra tokens for liquidity

        // Deal ETH to the receiver for adding liquidity
        vm.deal(address(flashLoanReceiver), 10 ether);

        // Setup flash loan receiver's tier by providing liquidity
        vm.startPrank(address(flashLoanReceiver));
        token.approve(address(pool), type(uint256).max);
        pool.addLiquidity{value: 1 ether}(2000e18); // Match the ETH:token ratio
        vm.stopPrank();

        // Update tier
        incentives.manualUpdateUserTier(address(flashLoanReceiver), 1000e15);

        // Verify tier
        uint256 receiverTier = incentives.userTiers(address(flashLoanReceiver));
        assertEq(receiverTier, 1, "Should have tier 1");

        // Log initial state
        console.log("Initial state:");
        console.log("Receiver tier:", receiverTier);
        console.log("Receiver balance:", token.balanceOf(address(flashLoanReceiver)));
        console.log("Incentives balance:", token.balanceOf(address(incentives)));
        console.log("Loan amount:", loanAmount);
        console.log("Flash loan fee:", flashLoanFee);
        console.log("Total required:", totalRequired);

        // Record initial balances
        uint256 initialReceiverBalance = token.balanceOf(address(flashLoanReceiver));
        uint256 initialIncentivesBalance = token.balanceOf(address(incentives));

        // Execute flash loan
        vm.startPrank(address(flashLoanReceiver));
        incentives.flashLoan(loanAmount, "");
        vm.stopPrank();

        // Log final state
        console.log("\nFinal state:");
        console.log("Receiver balance:", token.balanceOf(address(flashLoanReceiver)));
        console.log("Incentives balance:", token.balanceOf(address(incentives)));

        // Verify flash loan was repaid with fee
        assertEq(
            token.balanceOf(address(flashLoanReceiver)),
            initialReceiverBalance - flashLoanFee,
            "Incorrect receiver balance after flash loan"
        );
        assertEq(
            token.balanceOf(address(incentives)),
            initialIncentivesBalance + flashLoanFee,
            "Incorrect incentives balance after flash loan"
        );
    }

    function testFailedFlashLoan() public {
        uint256 loanAmount = 100e18;
        uint256 flashLoanFee = (loanAmount * 30) / 10000; // 0.3% fee for tier 1

        // Setup flash loan receiver with enough tokens for liquidity but not enough for repayment
        token.mint(address(flashLoanReceiver), 2000e18); // Only mint enough for liquidity

        // Deal ETH to the receiver for adding liquidity
        vm.deal(address(flashLoanReceiver), 10 ether);

        // Setup flash loan receiver's tier by providing liquidity
        vm.startPrank(address(flashLoanReceiver));
        token.approve(address(pool), type(uint256).max);
        pool.addLiquidity{value: 1 ether}(2000e18);
        vm.stopPrank();

        // Update tier
        incentives.manualUpdateUserTier(address(flashLoanReceiver), 1000e15);

        // Record initial balances
        uint256 initialReceiverBalance = token.balanceOf(address(flashLoanReceiver));
        uint256 initialIncentivesBalance = token.balanceOf(address(incentives));

        console.log("Initial state:");
        console.log("Receiver balance:", initialReceiverBalance);
        console.log("Incentives balance:", initialIncentivesBalance);
        console.log("Loan amount:", loanAmount);
        console.log("Flash loan fee:", flashLoanFee);

        // Take flash loan - should revert with FlashLoanRepaymentFailed
        vm.expectRevert(LiquidityIncentives.FlashLoanRepaymentFailed.selector);
        vm.prank(address(flashLoanReceiver));
        incentives.flashLoan(loanAmount, "");
    }

    function testYieldFarming() public {
        vm.startPrank(alice);
        incentives.stake(1, 1000e18);

        vm.warp(block.timestamp + 1 days);

        uint256 expectedRewards = 10e18 * 86400;

        uint256 balanceBefore = token.balanceOf(alice);
        incentives.claimRewards(1);
        uint256 balanceAfter = token.balanceOf(alice);

        assertApproxEqRel(balanceAfter - balanceBefore, expectedRewards, 0.01e18);
        vm.stopPrank();
    }

    function testMultiplePoolStaking() public {
        vm.startPrank(alice);
        incentives.stake(1, 1000e18);
        incentives.stake(2, 2000e18);

        vm.warp(block.timestamp + 1 days);

        uint256 balanceBefore = token.balanceOf(alice);
        incentives.claimRewards(1);
        incentives.claimRewards(2);
        uint256 balanceAfter = token.balanceOf(alice);

        uint256 expectedRewards = (10e18 * 86400) + (20e18 * 86400);

        assertApproxEqRel(balanceAfter - balanceBefore, expectedRewards, 0.01e18);
        vm.stopPrank();
    }

    function testPauseUnpause() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        incentives.pause();

        incentives.pause();
        assertTrue(incentives.paused());

        vm.startPrank(alice);
        vm.expectRevert("Pausable: paused");
        incentives.stake(1, 1000e18);
        vm.stopPrank();

        incentives.unpause();
        assertFalse(incentives.paused());

        vm.startPrank(alice);
        incentives.stake(1, 1000e18);
        (uint256 stakedAmount,,) = incentives.userPoolInfo(alice, 1);
        assertEq(stakedAmount, 1000e18);
        vm.stopPrank();
    }

    receive() external payable {}
}
