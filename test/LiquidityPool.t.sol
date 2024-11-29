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
        vm.stopPrank();

        // Deploy malicious contract that attempts reentrancy
        ReentrancyAttacker attacker = new ReentrancyAttacker(payable(address(pool)));

        // Give attacker some ETH and tokens
        vm.deal(address(attacker), 2 ether);
        vm.startPrank(owner);
        token.transfer(address(attacker), 1000 * 10 ** 18);
        vm.stopPrank();

        // Approve tokens for the attacker
        vm.startPrank(address(attacker));
        token.approve(address(pool), type(uint256).max);

        // Attempt attack (should fail with TransferFailed due to state changes)
        vm.expectRevert(abi.encodeWithSignature("TransferFailed()"));
        attacker.attack();
        vm.stopPrank();
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

        uint256 expectedOutput = pool.getOutputAmount(1_000 * 10 ** 18, initialTokens, initialEth);

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
}

contract ReentrancyAttacker {
    LiquidityPool public pool;
    bool public attacking;
    PlatformToken public token;

    constructor(address payable _pool) {
        pool = LiquidityPool(_pool);
        token = PlatformToken(pool.token());
    }

    receive() external payable {
        if (attacking) {
            attacking = false;
            // Try to reenter with another swap while still processing the first one
            // This will fail because the state has already been updated
            pool.swapTokensForETH(100 * 10 ** 18, 0);
        }
    }

    function attack() external {
        // First approve tokens
        token.approve(address(pool), type(uint256).max);

        // Then attempt swap that will trigger receive()
        attacking = true;
        pool.swapTokensForETH(100 * 10 ** 18, 0);
    }
}
