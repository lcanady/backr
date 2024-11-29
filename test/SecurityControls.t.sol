// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SecurityControls.sol";

contract SecurityControlsTest is Test {
    SecurityControls public securityControls;
    address public admin;
    address public operator;
    address public emergency;
    address public user;

    bytes32 public constant TEST_OPERATION = keccak256("TEST_OPERATION");
    bytes32 public constant TEST_TX_HASH = keccak256("TEST_TX_HASH");

    event RateLimitConfigured(bytes32 indexed operation, uint256 limit, uint256 window);
    event RateLimitExceeded(bytes32 indexed operation, address indexed caller);
    event MultiSigConfigured(bytes32 indexed operation, uint256 requiredApprovals);
    event MultiSigApproval(bytes32 indexed operation, bytes32 indexed txHash, address indexed approver);
    event MultiSigExecuted(bytes32 indexed operation, bytes32 indexed txHash);
    event EmergencyActionTriggered(address indexed triggeredBy, string reason);
    event CircuitBreakerStatusChanged(bool enabled);

    function setUp() public {
        admin = makeAddr("admin");
        operator = makeAddr("operator");
        emergency = makeAddr("emergency");
        user = makeAddr("user");

        vm.startPrank(admin);
        securityControls = new SecurityControls();

        securityControls.grantRole(securityControls.OPERATOR_ROLE(), operator);
        securityControls.grantRole(securityControls.EMERGENCY_ROLE(), emergency);

        // Set very short cooldown for testing
        securityControls.setEmergencyCooldownPeriod(1 seconds);
        vm.stopPrank();
    }

    function test_ConfigureRateLimit() public {
        vm.startPrank(admin);

        vm.expectEmit(true, false, false, true);
        emit RateLimitConfigured(TEST_OPERATION, 5, 1 days);

        securityControls.configureRateLimit(TEST_OPERATION, 5, 1 days);
        vm.stopPrank();
    }

    function test_RateLimitEnforcement() public {
        // Create test contract that uses rate limiting
        TestRateLimitedContract testContract = new TestRateLimitedContract();

        // First two calls should succeed
        testContract.rateLimitedOperation();
        testContract.rateLimitedOperation();

        // Third call should fail
        vm.expectRevert("Rate limit exceeded");
        testContract.rateLimitedOperation();

        // After time window, should work again
        vm.warp(block.timestamp + 1 hours + 1);
        testContract.rateLimitedOperation();
    }

    function test_ConfigureMultiSig() public {
        vm.startPrank(admin);

        address[] memory approvers = new address[](3);
        approvers[0] = makeAddr("approver1");
        approvers[1] = makeAddr("approver2");
        approvers[2] = makeAddr("approver3");

        vm.expectEmit(true, false, false, true);
        emit MultiSigConfigured(TEST_OPERATION, 2);

        securityControls.configureMultiSig(TEST_OPERATION, 2, approvers);
        vm.stopPrank();
    }

    function test_ConfigureMultiSig_VerifyConfig() public {
        vm.startPrank(admin);
        address[] memory approvers = new address[](1);
        approvers[0] = admin;

        securityControls.configureMultiSig(TEST_OPERATION, 1, approvers);

        // Verify that the multi-sig configuration is set correctly
        (uint256 requiredApprovals, address[] memory configuredApprovers) =
            securityControls.getMultiSigConfig(TEST_OPERATION);
        assertEq(requiredApprovals, 1);
        assertEq(configuredApprovers[0], admin);
        vm.stopPrank();
    }

    function test_MultiSigApprovalFlow() public {
        // Setup multi-sig configuration
        vm.startPrank(admin);
        address[] memory approvers = new address[](3);
        approvers[0] = makeAddr("approver1");
        approvers[1] = makeAddr("approver2");
        approvers[2] = makeAddr("approver3");
        securityControls.configureMultiSig(TEST_OPERATION, 2, approvers);
        vm.stopPrank();

        // First approval
        vm.prank(approvers[0]);
        vm.expectEmit(true, true, true, true);
        emit MultiSigApproval(TEST_OPERATION, TEST_TX_HASH, approvers[0]);
        securityControls.approveOperation(TEST_OPERATION, TEST_TX_HASH);

        // Second approval should trigger execution
        vm.prank(approvers[1]);
        vm.expectEmit(true, true, false, true);
        emit MultiSigExecuted(TEST_OPERATION, TEST_TX_HASH);
        securityControls.approveOperation(TEST_OPERATION, TEST_TX_HASH);
    }

    function test_EmergencyTrigger() public {
        vm.startPrank(emergency);

        // Trigger emergency
        securityControls.triggerEmergency("Security breach");
        assertTrue(securityControls.paused());
        vm.stopPrank();
    }

    function test_EmergencyResolve() public {
        vm.prank(emergency);
        securityControls.triggerEmergency("Security breach");
        vm.warp(block.timestamp + 1 seconds);
        vm.prank(emergency);
        securityControls.resolveEmergency();
        assertFalse(securityControls.paused());
    }

    function test_EmergencyCooldown() public {
        vm.prank(emergency);
        securityControls.triggerEmergency("First emergency");
        assertTrue(securityControls.paused());

        vm.warp(block.timestamp + 1 seconds);
        vm.prank(emergency);
        securityControls.triggerEmergency("Second emergency");
        assertTrue(securityControls.paused());
    }

    function test_OnlyAdminCanConfigureRateLimit() public {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint160(user), 20),
                " is missing role ",
                "0x0000000000000000000000000000000000000000000000000000000000000000"
            )
        );
        vm.prank(user);
        securityControls.configureRateLimit(TEST_OPERATION, 5, 1 days);
    }

    function test_OnlyEmergencyRoleCanTriggerEmergency() public {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint160(user), 20),
                " is missing role ",
                Strings.toHexString(uint256(securityControls.EMERGENCY_ROLE()), 32)
            )
        );
        vm.prank(user);
        securityControls.triggerEmergency("Unauthorized");
    }
}

// Helper contract for testing rate limiting
contract TestRateLimitedContract is SecurityControls {
    bytes32 public constant TEST_OPERATION = keccak256("TEST_OPERATION");

    constructor() {
        // Initialize with default settings
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _configureRateLimit(TEST_OPERATION, 2, 1 hours);
    }

    function rateLimitedOperation() external rateLimitGuard(TEST_OPERATION) {
        // Function just tests the rate limit
    }
}
