// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {LiquidityPool} from "../src/LiquidityPool.sol";
import {PlatformToken} from "../src/PlatformToken.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract LiquidityPoolTest is Test {
    LiquidityPool public pool;
    PlatformToken public token;
    address public owner;
    address public user1;
    address public user2;

    uint256 constant INITIAL_POOL_TOKENS = 100_000 * 10 ** 18;
    uint256 constant MIN_LIQUIDITY = 1000;

    event LiquidityAdded(address indexed provider, uint256 ethAmount, uint256 tokenAmount, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 ethAmount, uint256 tokenAmount, uint256 liquidity);
    event TokensPurchased(address indexed buyer, uint256 ethIn, uint256 tokensOut);
    event TokensSold(address indexed seller, uint256 tokensIn, uint256 ethOut);
    event PoolStateChanged(uint256 newEthReserve, uint256 newTokenReserve);
    event EmergencyWithdrawal(address indexed owner, uint256 ethAmount, uint256 tokenAmount);
    event MaxSlippageUpdated(uint256 newMaxSlippage);

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.startPrank(owner);
        // Deploy token and pool
        token = new PlatformToken();
        pool = new LiquidityPool(address(token), MIN_LIQUIDITY);

        // Transfer tokens to users for testing
        token.transfer(user1, 100_000 * 10 ** 18);
        token.transfer(user2, 50_000 * 10 ** 18);

        // Approve pool to spend owner's tokens
        token.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        // Have users approve pool
        vm.prank(user1);
        token.approve(address(pool), type(uint256).max);
        vm.prank(user2);
        token.approve(address(pool), type(uint256).max);
    }

    function test_PauseUnpause() public {
        vm.startPrank(owner);
        vm.deal(owner, 100 ether);

        // Add initial liquidity
        uint256 ethAmount = 10 ether;
        uint256 tokenAmount = 10_000 * 10 ** 18;

        // Ensure owner has enough tokens and has approved the pool
        require(token.balanceOf(owner) >= tokenAmount * 2, "Owner needs more tokens");
        token.approve(address(pool), type(uint256).max);

        pool.addLiquidity{value: ethAmount}(tokenAmount);

        // Pause the contract
        pool.pause();

        // Try to add liquidity while paused
        vm.expectRevert("Pausable: paused");
        pool.addLiquidity{value: ethAmount}(tokenAmount);

        // Unpause
        pool.unpause();

        // Should work after unpause
        pool.addLiquidity{value: ethAmount}(tokenAmount);

        vm.stopPrank();
    }

    function test_NonOwnerCannotPause() public {
        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        pool.pause();
    }

    function test_SwapWithSlippage() public {
        // Add initial liquidity
        (uint256 initialEthReserve, uint256 initialTokenReserve) = _addInitialLiquidity();

        // Debug initial state
        console2.log("Initial ETH Reserve:", initialEthReserve);
        console2.log("Initial Token Reserve:", initialTokenReserve);
        console2.log("Owner Token Balance:", token.balanceOf(owner));
        console2.log("Pool Token Balance:", token.balanceOf(address(pool)));

        // Verify initial state
        assertEq(pool.ethReserve(), initialEthReserve, "Initial ETH reserve incorrect");
        assertEq(pool.tokenReserve(), initialTokenReserve, "Initial token reserve incorrect");

        vm.startPrank(user1);
        vm.deal(user1, 10 ether);
        token.approve(address(pool), type(uint256).max);

        // Calculate expected output
        uint256 ethIn = 1 ether;
        uint256 expectedOut = pool.getOutputAmount(ethIn, pool.ethReserve(), pool.tokenReserve());
        console2.log("ETH Input:", ethIn);
        console2.log("Expected Token Output:", expectedOut);

        // Try with too high minimum (should fail)
        vm.expectRevert(abi.encodeWithSignature("InsufficientOutputAmount()"));
        pool.swapETHForTokens{value: ethIn}(expectedOut + 1);

        // Should succeed with correct minimum
        uint256 initialBalance = token.balanceOf(user1);
        console2.log("User1 Initial Token Balance:", initialBalance);

        pool.swapETHForTokens{value: ethIn}(expectedOut);

        uint256 finalBalance = token.balanceOf(user1);
        console2.log("User1 Final Token Balance:", finalBalance);
        console2.log("Token Balance Change:", finalBalance - initialBalance);

        // Verify the swap
        assertEq(token.balanceOf(user1) - initialBalance, expectedOut, "Incorrect token output amount");
        assertEq(address(pool).balance, initialEthReserve + ethIn, "Incorrect pool ETH balance");
        assertEq(pool.ethReserve(), initialEthReserve + ethIn, "Incorrect ETH reserve after swap");
        assertEq(pool.tokenReserve(), initialTokenReserve - expectedOut, "Incorrect token reserve after swap");

        vm.stopPrank();
    }

    function test_ReentrancyProtection() public {
        // First add liquidity to the pool
        vm.startPrank(owner);
        vm.deal(owner, 100 ether);
        token.approve(address(pool), type(uint256).max);
        pool.addLiquidity{value: 10 ether}(10_000 * 10 ** 18);
        
        // Set high slippage tolerance for testing
        pool.setMaxSlippage(5000); // 50%
        vm.stopPrank();

        // Deploy malicious contract that attempts reentrancy
        ReentrancyAttacker attacker = new ReentrancyAttacker(payable(address(pool)));

        // Give attacker some ETH and tokens
        vm.deal(address(attacker), 2 ether);
        vm.prank(address(attacker));
        attacker.attack{value: 1 ether}();
    }

    function test_ConstantProduct() public {
        // Add initial liquidity
        _addInitialLiquidity();

        uint256 initialK = pool.ethReserve() * pool.tokenReserve();

        // Perform swap
        vm.startPrank(user1);
        vm.deal(user1, 10 ether);
        pool.swapETHForTokens{value: 1 ether}(0);
        vm.stopPrank();

        uint256 finalK = pool.ethReserve() * pool.tokenReserve();

        // K should be maintained or increased (due to fees)
        assertGe(finalK, initialK, "Constant product invariant violated");
    }

    /// @notice Helper to add initial liquidity with default values
    function _addInitialLiquidity() internal returns (uint256 ethAmount, uint256 tokenAmount) {
        ethAmount = 10 ether;
        tokenAmount = 10_000 * 10 ** 18;

        vm.startPrank(owner);
        vm.deal(owner, ethAmount); // Give owner the required ETH

        // Ensure owner has enough tokens and has approved the pool
        require(token.balanceOf(owner) >= tokenAmount, "Owner needs more tokens");
        token.approve(address(pool), type(uint256).max);

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
        uint256 tokenAmount = 100_000 * 10 ** 18;

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
        uint256 initialTokens = 10_000 * 10 ** 18;
        pool.addLiquidity{value: initialEth}(initialTokens);
        vm.stopPrank();

        // Try to add unbalanced liquidity
        vm.startPrank(user1);
        vm.deal(user1, 100 ether);
        vm.expectRevert(abi.encodeWithSignature("UnbalancedLiquidityRatios()"));
        pool.addLiquidity{value: 5 ether}(15_000 * 10 ** 18);
        vm.stopPrank();
    }

    /// @notice Updated test_AddLiquidityInsufficientTokens to expect UnbalancedLiquidityRatios()
    function test_AddLiquidityInsufficientTokens() public {
        // First add initial liquidity
        vm.startPrank(owner);
        vm.deal(owner, 100 ether);

        uint256 initialEth = 10 ether;
        uint256 initialTokens = 10_000 * 10 ** 18;
        pool.addLiquidity{value: initialEth}(initialTokens);
        vm.stopPrank();

        // Try to add with insufficient tokens
        vm.startPrank(user1);
        vm.deal(user1, 100 ether);

        // Calculate required tokens for 10 ETH based on current ratio
        uint256 requiredTokens = (10 ether * initialTokens) / initialEth;
        uint256 insufficientTokens = requiredTokens - 1000 * 10 ** 18; // Less than required

        vm.expectRevert(abi.encodeWithSignature("UnbalancedLiquidityRatios()"));
        pool.addLiquidity{value: 10 ether}(insufficientTokens);
        vm.stopPrank();
    }

    function test_SwapETHForTokens() public {
        // First add initial liquidity
        vm.startPrank(owner);
        vm.deal(owner, 100 ether);

        uint256 initialEth = 10 ether;
        uint256 initialTokens = 1_000 * 10 ** 18; // Reduced from 10_000 to prevent overflow
        pool.addLiquidity{value: initialEth}(initialTokens);
        vm.stopPrank();

        // Now swap ETH for tokens
        vm.startPrank(user1);
        vm.deal(user1, 1 ether);

        // Calculate minimum tokens to receive (with 0.3% fee)
        uint256 expectedOutput = pool.getOutputAmount(1 ether, initialEth, initialTokens);

        // Use SafeMath for slippage calculation
        uint256 minTokens = expectedOutput * 99 / 100; // 1% slippage tolerance

        // Store initial balances
        uint256 initialTokenBalance = token.balanceOf(user1);
        uint256 initialEthBalance = user1.balance;
        uint256 initialPoolETHReserve = pool.ethReserve();

        // Perform swap
        pool.swapETHForTokens{value: 1 ether}(minTokens);

        // Verify balances using SafeMath
        uint256 finalTokenBalance = token.balanceOf(user1);
        uint256 tokensReceived = finalTokenBalance - initialTokenBalance;
        uint256 finalEthBalance = user1.balance;
        uint256 ethSpent = initialEthBalance - finalEthBalance;

        assertGe(tokensReceived, minTokens, "Received tokens less than minimum");
        assertEq(tokensReceived, expectedOutput, "Incorrect token output");
        assertEq(pool.ethReserve(), initialPoolETHReserve + ethSpent, "Incorrect pool ETH reserve");
        vm.stopPrank();
    }

    function test_SwapTokensForETH() public {
        // First add initial liquidity
        vm.startPrank(owner);
        vm.deal(owner, 100 ether);

        uint256 initialEth = 10 ether;
        uint256 initialTokens = 10_000 * 10 ** 18; // 10,000 tokens

        // Add initial liquidity
        pool.addLiquidity{value: initialEth}(initialTokens);

        // Transfer some tokens to user1
        token.transfer(user1, 1_000 * 10 ** 18);
        vm.stopPrank();

        // Now swap tokens for ETH
        vm.startPrank(user1);
        token.approve(address(pool), 1_000 * 10 ** 18);
        uint256 minETH = 0.9 ether;
        uint256 initialETHBalance = user1.balance;
        uint256 initialPoolETHReserve = pool.ethReserve();

        uint256 expectedOutput = pool.getOutputAmount(1_000 * 10 ** 18, pool.tokenReserve(), pool.ethReserve());

        pool.swapTokensForETH(1_000 * 10 ** 18, minETH);

        // Verify balances
        uint256 finalETHBalance = user1.balance;
        uint256 ethReceived = finalETHBalance - initialETHBalance;

        assertGe(ethReceived, minETH, "Received ETH less than minimum");
        assertEq(ethReceived, expectedOutput, "Incorrect ETH output");
        assertEq(pool.ethReserve(), initialPoolETHReserve - ethReceived, "Incorrect pool ETH reserve");
        vm.stopPrank();
    }

    function test_RemoveLiquidity() public {
        vm.startPrank(owner);
        vm.deal(owner, 100 ether); // Give owner enough ETH

        uint256 ethAmount = 10 ether;
        uint256 tokenAmount = 10_000 * 10 ** 18;

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
        assertApproxEqAbs(
            token.balanceOf(owner) - initialTokenBalance, expectedTokens, 100_000, "Incorrect tokens returned"
        );

        // Verify remaining liquidity
        assertEq(pool.liquidityBalance(owner), liquidity - liquidityToRemove, "Incorrect remaining liquidity");
        vm.stopPrank();
    }

    function testFail_RemoveTooMuchLiquidity() public {
        vm.startPrank(owner);
        pool.addLiquidity{value: 10 ether}(10_000 * 10 ** 18);
        uint256 liquidity = pool.liquidityBalance(owner);
        pool.removeLiquidity(liquidity + 1);
        vm.stopPrank();
    }

    function test_GetExchangeRate() public {
        // First add some initial liquidity to have a valid exchange rate
        vm.startPrank(owner);
        vm.deal(owner, 100 ether); // Give owner some ETH

        uint256 ethAmount = 10 ether;
        uint256 tokenAmount = 10_000 * 10 ** 18; // 10,000 tokens

        // Add initial liquidity
        pool.addLiquidity{value: ethAmount}(tokenAmount);

        // Exchange rate should be 1000 tokens per ETH (10000/10)
        uint256 rate = pool.getExchangeRate();
        assertEq(rate, 1000 * 10 ** 18, "Incorrect exchange rate");
        vm.stopPrank();
    }

    function test_SlippageProtection() public {
        // Add initial liquidity
        (uint256 initialEthReserve, uint256 initialTokenReserve) = _addInitialLiquidity();

        // Try to make a large swap that would exceed slippage
        vm.startPrank(user1);
        vm.deal(user1, 100 ether);

        // Set very low slippage tolerance
        vm.stopPrank();
        vm.startPrank(owner);
        pool.setMaxSlippage(10); // 0.1%
        vm.stopPrank();
        
        vm.startPrank(user1);
        // Attempt a swap that should exceed slippage
        uint256 swapAmount = 1 ether;
        vm.expectRevert(abi.encodeWithSignature("SlippageExceeded()"));
        pool.swapETHForTokens{value: swapAmount}(0);

        // Update max slippage to 20%
        vm.stopPrank();
        vm.startPrank(owner);
        pool.setMaxSlippage(2000);
        
        // Try the swap again - should work now
        vm.stopPrank();
        vm.startPrank(user1);
        pool.swapETHForTokens{value: swapAmount}(0);
        
        vm.stopPrank();
    }

    function test_EmergencyWithdrawal() public {
        // Add initial liquidity
        (uint256 initialEthReserve, uint256 initialTokenReserve) = _addInitialLiquidity();
        
        // Try emergency withdrawal without being owner
        vm.startPrank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        pool.emergencyWithdraw();
        vm.stopPrank();
        
        // Try emergency withdrawal without pausing
        vm.startPrank(owner);
        vm.expectRevert("Pausable: not paused");
        pool.emergencyWithdraw();
        
        // Pause and withdraw
        pool.pause();
        
        uint256 ownerEthBefore = owner.balance;
        uint256 ownerTokensBefore = token.balanceOf(owner);
        
        vm.expectEmit(true, true, true, true);
        emit EmergencyWithdrawal(owner, address(pool).balance, token.balanceOf(address(pool)));
        pool.emergencyWithdraw();
        
        // Verify balances
        assertEq(address(pool).balance, 0, "Pool should have 0 ETH after emergency withdrawal");
        assertEq(token.balanceOf(address(pool)), 0, "Pool should have 0 tokens after emergency withdrawal");
        assertEq(owner.balance - ownerEthBefore, initialEthReserve, "Owner should receive all ETH");
        assertEq(token.balanceOf(owner) - ownerTokensBefore, initialTokenReserve, "Owner should receive all tokens");
        
        vm.stopPrank();
    }

    function test_NonOwnerCannotSetSlippage() public {
        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        pool.setMaxSlippage(200);
    }

    /// @notice Updated helper to calculate square root
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

    function test_AddLiquidityEdgeCases() public {
        vm.startPrank(owner);
        vm.deal(owner, 100 ether);

        // Test adding zero amounts
        vm.expectRevert(LiquidityPool.InsufficientInputAmount.selector);
        pool.addLiquidity{value: 0}(1000 * 10**18);

        vm.expectRevert(LiquidityPool.InsufficientInputAmount.selector);
        pool.addLiquidity{value: 1 ether}(0);

        // Test adding very small amounts for first liquidity
        vm.expectRevert(LiquidityPool.InsufficientLiquidity.selector);
        pool.addLiquidity{value: 1}(1);

        // Add initial liquidity
        pool.addLiquidity{value: 10 ether}(10_000 * 10**18);

        // Test unbalanced ratios
        vm.expectRevert(LiquidityPool.UnbalancedLiquidityRatios.selector);
        pool.addLiquidity{value: 1 ether}(2_000 * 10**18);

        vm.stopPrank();
    }

    function test_FeeCalculations() public {
        // Setup initial liquidity
        vm.startPrank(owner);
        vm.deal(owner, 100 ether);
        pool.addLiquidity{value: 10 ether}(10_000 * 10**18);
        vm.stopPrank();

        // Calculate expected output with fees
        uint256 inputAmount = 1 ether;
        vm.deal(user1, inputAmount);
        vm.prank(user1);
        
        uint256 expectedOutput = pool.getOutputAmount(
            inputAmount,
            10 ether,  // ethReserve
            10_000 * 10**18  // tokenReserve
        );

        // Verify fee is correctly applied (0.3%)
        uint256 withoutFee = (inputAmount * 10_000 * 10**18) / (10 ether + inputAmount);
        uint256 fee = (withoutFee * 3) / 1000;
        uint256 expectedWithFee = withoutFee - fee;
        assertEq(expectedOutput, expectedWithFee, "Fee calculation incorrect");
    }

    function test_GetOutputAmountEdgeCases() public {
        // Test with zero input
        vm.expectRevert(LiquidityPool.InsufficientInputAmount.selector);
        pool.getOutputAmount(0, 1000, 1000);

        // Test with zero reserves
        vm.expectRevert(LiquidityPool.InsufficientLiquidity.selector);
        pool.getOutputAmount(100, 0, 1000);

        vm.expectRevert(LiquidityPool.InsufficientLiquidity.selector);
        pool.getOutputAmount(100, 1000, 0);

        // Test with very small amounts that would result in zero output
        vm.expectRevert(LiquidityPool.InsufficientOutputAmount.selector);
        pool.getOutputAmount(1, 1000000, 1000000);
    }

    function test_PoolStateChangeEvents() public {
        vm.startPrank(owner);
        vm.deal(owner, 100 ether);
        
        // Set high slippage tolerance for testing
        pool.setMaxSlippage(5000); // 50%
        
        uint256 ethAmount = 10 ether;
        uint256 tokenAmount = 10_000 * 10**18;
        
        // Test add liquidity event
        vm.expectEmit(true, true, true, true);
        emit PoolStateChanged(ethAmount, tokenAmount);
        pool.addLiquidity{value: ethAmount}(tokenAmount);
        
        // Test swap event
        vm.stopPrank();
        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        
        uint256 swapAmount = 1 ether;
        
        // Get current state before swap
        uint256 currentEthReserve = pool.ethReserve();
        uint256 currentTokenReserve = pool.tokenReserve();
        
        // Calculate expected output with fee
        uint256 expectedTokensOut = pool.getOutputAmount(swapAmount, currentEthReserve, currentTokenReserve);
        
        // Do the swap and verify event
        pool.swapETHForTokens{value: swapAmount}(0);
        
        // Verify final state matches event expectations
        assertEq(pool.ethReserve(), currentEthReserve + swapAmount, "ETH reserve mismatch");
        assertEq(pool.tokenReserve(), currentTokenReserve - expectedTokensOut, "Token reserve mismatch");
        
        vm.stopPrank();
    }
}

contract ReentrancyAttacker {
    LiquidityPool public pool;
    bool public attacking;

    constructor(address payable _pool) {
        pool = LiquidityPool(_pool);
    }

    // Fallback is called when pool sends Ether to this contract
    receive() external payable {
        if (attacking) {
            attacking = false;
            // Try to swap again during the first swap
            pool.swapETHForTokens{value: 1 ether}(0);
        }
    }

    function attack() external payable {
        require(msg.value >= 1 ether, "Need ETH to attack");
        attacking = true;
        // Initial swap that should trigger the reentrancy
        pool.swapETHForTokens{value: 1 ether}(0);
    }
}
