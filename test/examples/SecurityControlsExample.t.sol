// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/SecurityControls.sol";

/**
 * @title Example Secure Vault Contract
 * @notice This contract demonstrates how to implement SecurityControls
 */
contract SecureVault is SecurityControls {
    bytes32 public constant WITHDRAWAL = keccak256("WITHDRAWAL");
    bytes32 public constant LARGE_WITHDRAWAL = keccak256("LARGE_WITHDRAWAL");

    uint256 public constant LARGE_AMOUNT = 100 ether;
    mapping(address => uint256) public balances;

    constructor() {
        // Configure rate limiting for regular withdrawals
        _configureRateLimit(WITHDRAWAL, 10, 1 days); // 10 withdrawals per day

        // Configure multi-sig for large withdrawals
        address[] memory approvers = new address[](3);
        approvers[0] = address(0x1);
        approvers[1] = address(0x2);
        approvers[2] = address(0x3);
        _configureMultiSig(LARGE_WITHDRAWAL, 2, approvers);
    }

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external rateLimitGuard(WITHDRAWAL) whenCircuitBreakerOff {
        require(amount < LARGE_AMOUNT, "Use largeWithdraw for large amounts");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }

    function largeWithdraw(uint256 amount, bytes32 txHash)
        external
        requiresApproval(LARGE_WITHDRAWAL, txHash)
        whenCircuitBreakerOff
    {
        require(amount >= LARGE_AMOUNT, "Use regular withdraw for small amounts");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }
}

/**
 * @title SecureVault Test Contract
 * @notice Comprehensive tests for SecureVault implementation
 */
contract SecureVaultTest is Test {
    SecureVault public vault;
    address public admin;
    address public user1;
    address public user2;
    address[] public approvers;

    function setUp() public {
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Setup approvers
        approvers = new address[](3);
        approvers[0] = makeAddr("approver1");
        approvers[1] = makeAddr("approver2");
        approvers[2] = makeAddr("approver3");

        // Deploy vault
        vm.startPrank(admin);
        vault = new SecureVault();

        // Fund the vault
        vm.deal(address(vault), 1000 ether);

        // Setup roles
        vault.grantRole(vault.EMERGENCY_ROLE(), admin);
        vault.grantRole(vault.OPERATOR_ROLE(), admin);
        vm.stopPrank();

        // Setup test users with balances
        vm.deal(user1, 200 ether);
        vm.deal(user2, 200 ether);

        vm.prank(user1);
        vault.deposit{value: 150 ether}();

        vm.prank(user2);
        vault.deposit{value: 150 ether}();
    }

    function test_RegularWithdrawal() public {
        vm.startPrank(user1);

        // Should be able to withdraw small amounts
        uint256 initialBalance = user1.balance;
        vault.withdraw(1 ether);
        assertEq(user1.balance, initialBalance + 1 ether);

        // Should be able to make multiple withdrawals within limit
        for (uint256 i = 0; i < 8; i++) {
            vault.withdraw(1 ether);
        }

        // Should fail on exceeding rate limit
        vm.expectRevert("Rate limit exceeded");
        vault.withdraw(1 ether);

        vm.stopPrank();
    }

    function test_LargeWithdrawalFlow() public {
        bytes32 txHash = keccak256("large_withdrawal_1");

        // First approval
        vm.prank(approvers[0]);
        vault.approveOperation(vault.LARGE_WITHDRAWAL(), txHash);

        // Second approval
        vm.prank(approvers[1]);
        vault.approveOperation(vault.LARGE_WITHDRAWAL(), txHash);

        // Now user can execute large withdrawal
        vm.prank(user1);
        uint256 initialBalance = user1.balance;
        vault.largeWithdraw(100 ether, txHash);
        assertEq(user1.balance, initialBalance + 100 ether);
    }

    function test_EmergencyControls() public {
        // Trigger emergency
        vm.prank(admin);
        vault.triggerEmergency("Potential exploit detected");

        // Withdrawals should be blocked
        vm.expectRevert("Pausable: paused");
        vm.prank(user1);
        vault.withdraw(1 ether);

        // Resolve emergency
        vm.prank(admin);
        vault.resolveEmergency();

        // Withdrawals should work again
        vm.prank(user1);
        vault.withdraw(1 ether);
    }

    function test_RateLimitReset() public {
        vm.startPrank(user1);

        // Make max withdrawals
        for (uint256 i = 0; i < 10; i++) {
            vault.withdraw(1 ether);
        }

        // Should fail
        vm.expectRevert("Rate limit exceeded");
        vault.withdraw(1 ether);

        // Advance time by 1 day
        vm.warp(block.timestamp + 1 days + 1);

        // Should work again
        vault.withdraw(1 ether);

        vm.stopPrank();
    }

    function test_UnauthorizedEmergencyControl() public {
        // User without EMERGENCY_ROLE should not be able to trigger emergency
        vm.prank(user1);
        vm.expectRevert();
        vault.triggerEmergency("Unauthorized attempt");
    }

    function test_InvalidMultiSigApproval() public {
        bytes32 txHash = keccak256("invalid_tx");

        // Non-approver should not be able to approve
        vm.prank(user1);
        vm.expectRevert("Not an approver");
        vault.approveOperation(vault.LARGE_WITHDRAWAL(), txHash);
    }

    function test_CircuitBreakerBlock() public {
        // Trigger emergency
        vm.prank(admin);
        vault.triggerEmergency("Test emergency");

        // Large withdrawals should be blocked
        bytes32 txHash = keccak256("blocked_tx");

        // Get approvals
        vm.prank(approvers[0]);
        vault.approveOperation(vault.LARGE_WITHDRAWAL(), txHash);
        vm.prank(approvers[1]);
        vault.approveOperation(vault.LARGE_WITHDRAWAL(), txHash);

        // Should still be blocked due to circuit breaker
        vm.expectRevert("Pausable: paused");
        vm.prank(user1);
        vault.largeWithdraw(100 ether, txHash);
    }
}
