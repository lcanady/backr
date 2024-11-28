// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {LiquidityPool} from "../src/LiquidityPool.sol";
import {PlatformToken} from "../src/PlatformToken.sol";

contract LiquidityPoolTest is Test {
    LiquidityPool public pool;
    PlatformToken public token;
    address public owner;
    address public user1;
    address public user2;
    
    uint256 constant INITIAL_POOL_TOKENS = 100_000 * 10**18;
    uint256 constant MIN_LIQUIDITY = 1000;
    
    event LiquidityAdded(address indexed provider, uint256 ethAmount, uint256 tokenAmount, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 ethAmount, uint256 tokenAmount, uint256 liquidity);
    
    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        vm.startPrank(owner);
        // Deploy token and pool
        token = new PlatformToken();
        pool = new LiquidityPool(address(token), MIN_LIQUIDITY);
        
        // Transfer tokens to users for testing
        token.transfer(user1, 100_000 * 10**18);
        
        // Approve pool to spend owner's tokens
        token.approve(address(pool), type(uint256).max);
        vm.stopPrank();
        
        // Have user1 approve pool as well
        vm.prank(user1);
        token.approve(address(pool), type(uint256).max);
    }
    
    /// @notice Helper to add initial liquidity with default values
    function _addInitialLiquidity() internal returns (uint256 ethAmount, uint256 tokenAmount) {
        ethAmount = 10 ether;
        tokenAmount = 10_000 * 10**18;
        
        vm.startPrank(owner);
        pool.addLiquidity{value: ethAmount}(tokenAmount);
        vm.stopPrank();
        
        return (ethAmount, tokenAmount);
    }
    
    /// @notice Helper to calculate expected liquidity
    function _calculateExpectedLiquidity(uint256 ethAmount, uint256 tokenAmount) internal pure returns (uint256) {
        return _sqrt(ethAmount * tokenAmount);
    }
    
    function test_AddInitialLiquidity() public {
        vm.startPrank(owner);
        vm.deal(owner, 1000 ether); // Give owner some ETH
        
        uint256 ethAmount = 100 ether;
        uint256 tokenAmount = 100_000 * 10**18;
        
        uint256 expectedLiquidity = _sqrt(ethAmount * tokenAmount);
        uint256 providerLiquidity = expectedLiquidity - MIN_LIQUIDITY;
        
        vm.expectEmit(true, true, true, true);
        emit LiquidityAdded(owner, ethAmount, tokenAmount, providerLiquidity);
        
        pool.addLiquidity{value: ethAmount}(tokenAmount);
        
        assertEq(address(pool).balance, ethAmount, "Incorrect ETH balance");
        assertEq(token.balanceOf(address(pool)), tokenAmount, "Incorrect token balance");
        assertEq(pool.liquidityBalance(address(pool)), MIN_LIQUIDITY, "Incorrect pool liquidity balance");
        assertEq(pool.liquidityBalance(owner), providerLiquidity, "Incorrect owner liquidity balance");
        assertEq(pool.totalLiquidity(), expectedLiquidity, "Incorrect total liquidity");
        
        vm.stopPrank();
    }
    
    function test_AddLiquidityUnbalancedRatio() public {
        // First add initial liquidity
        vm.startPrank(owner);
        vm.deal(owner, 100 ether);
        
        uint256 initialEth = 10 ether;
        uint256 initialTokens = 10_000 * 10**18;
        pool.addLiquidity{value: initialEth}(initialTokens);
        vm.stopPrank();
        
        // Try to add unbalanced liquidity
        vm.startPrank(user1);
        vm.deal(user1, 100 ether);
        vm.expectRevert(abi.encodeWithSignature("UnbalancedLiquidityRatios()"));
        pool.addLiquidity{value: 5 ether}(15_000 * 10**18);
        vm.stopPrank();
    }
    
    function test_AddLiquidityInsufficientTokens() public {
        // First add initial liquidity
        vm.startPrank(owner);
        vm.deal(owner, 100 ether);
        
        uint256 initialEth = 10 ether;
        uint256 initialTokens = 10_000 * 10**18;
        pool.addLiquidity{value: initialEth}(initialTokens);
        vm.stopPrank();
        
        // Try to add with insufficient tokens
        vm.startPrank(user1);
        vm.deal(user1, 100 ether);
        
        // Calculate required tokens for 10 ETH based on current ratio
        uint256 requiredTokens = (10 ether * initialTokens) / initialEth;
        uint256 insufficientTokens = requiredTokens - 1000 * 10**18; // Less than required
        
        vm.expectRevert(abi.encodeWithSignature("InsufficientTokenAmount()"));
        pool.addLiquidity{value: 10 ether}(insufficientTokens);
        vm.stopPrank();
    }
    
    function test_SwapETHForTokens() public {
        // First add initial liquidity
        vm.startPrank(owner);
        vm.deal(owner, 100 ether);
        
        uint256 initialEth = 10 ether;
        uint256 initialTokens = 10_000 * 10**18;
        pool.addLiquidity{value: initialEth}(initialTokens);
        vm.stopPrank();
        
        // Now swap ETH for tokens
        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        
        // Calculate minimum tokens to receive (with 0.3% fee)
        uint256 expectedOutput = pool.getOutputAmount(
            1 ether,
            initialEth,
            initialTokens
        );
        uint256 minTokens = expectedOutput * 99 / 100; // 1% slippage tolerance
        
        // Store initial balances
        uint256 initialTokenBalance = token.balanceOf(user1);
        uint256 initialEthBalance = user1.balance;
        
        // Perform swap
        pool.swapETHForTokens{value: 1 ether}(minTokens);
        
        // Verify balances
        assertGe(token.balanceOf(user1) - initialTokenBalance, minTokens, "Received tokens less than minimum");
        assertEq(token.balanceOf(user1) - initialTokenBalance, expectedOutput, "Incorrect token output");
        assertEq(initialEthBalance - user1.balance, 1 ether, "Incorrect ETH spent");
        vm.stopPrank();
    }
    
    function test_SwapTokensForETH() public {
        // First add initial liquidity
        vm.startPrank(owner);
        vm.deal(owner, 100 ether);
        
        uint256 initialEth = 10 ether;
        uint256 initialTokens = 10_000 * 10**18;
        pool.addLiquidity{value: initialEth}(initialTokens);
        
        // Transfer some tokens to user1
        token.transfer(user1, 1_000 * 10**18);
        vm.stopPrank();
        
        // Now swap tokens for ETH
        vm.startPrank(user1);
        token.approve(address(pool), 1_000 * 10**18);
        uint256 minETH = 0.9 ether;
        uint256 initialETHBalance = user1.balance;
        
        uint256 expectedOutput = pool.getOutputAmount(
            1_000 * 10**18,
            initialTokens,
            initialEth
        );
        
        pool.swapTokensForETH(1_000 * 10**18, minETH);
        
        assertGe(user1.balance - initialETHBalance, minETH, "Received ETH less than minimum");
        assertEq(user1.balance - initialETHBalance, expectedOutput, "Incorrect ETH output");
        vm.stopPrank();
    }
    
    function test_RemoveLiquidity() public {
        vm.startPrank(owner);
        vm.deal(owner, 100 ether); // Give owner enough ETH
        uint256 ethAmount = 10 ether;
        uint256 tokenAmount = 10_000 * 10**18;
        
        // Add liquidity
        pool.addLiquidity{value: ethAmount}(tokenAmount);
        uint256 liquidity = pool.liquidityBalance(owner);
        
        // Store initial balances
        uint256 initialETHBalance = owner.balance;
        uint256 initialTokenBalance = token.balanceOf(owner);
        
        // Remove half of liquidity
        uint256 liquidityToRemove = liquidity / 2;
        pool.removeLiquidity(liquidityToRemove);
        
        // Calculate expected returns (approximately half of initial amounts)
        uint256 expectedETH = (ethAmount * liquidityToRemove) / liquidity;
        uint256 expectedTokens = (tokenAmount * liquidityToRemove) / liquidity;
        
        // Verify balances changed correctly
        assertApproxEqAbs(owner.balance - initialETHBalance, expectedETH, 100, "Incorrect ETH returned");
        assertApproxEqAbs(token.balanceOf(owner) - initialTokenBalance, expectedTokens, 100_000, "Incorrect tokens returned");
        
        // Verify remaining liquidity
        assertEq(pool.liquidityBalance(owner), liquidity - liquidityToRemove, "Incorrect remaining liquidity");
        vm.stopPrank();
    }
    
    function testFail_RemoveTooMuchLiquidity() public {
        vm.startPrank(owner);
        pool.addLiquidity{value: 10 ether}(10_000 * 10**18);
        uint256 liquidity = pool.liquidityBalance(owner);
        pool.removeLiquidity(liquidity + 1);
        vm.stopPrank();
    }
    
    function test_GetExchangeRate() public {
        // First add some initial liquidity to have a valid exchange rate
        vm.startPrank(owner);
        vm.deal(owner, 100 ether); // Give owner some ETH
        
        uint256 ethAmount = 10 ether;
        uint256 tokenAmount = 10_000 * 10**18; // 10,000 tokens
        
        // Add initial liquidity
        pool.addLiquidity{value: ethAmount}(tokenAmount);
        
        // Exchange rate should be 1000 tokens per ETH (10000/10)
        uint256 rate = pool.getExchangeRate();
        assertEq(rate, 1000 * 10**18, "Incorrect exchange rate");
        vm.stopPrank();
    }
    
    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}
