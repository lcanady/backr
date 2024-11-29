// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/access/AccessControl.sol";
import "openzeppelin-contracts/contracts/security/Pausable.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

/**
 * @title SecurityControls
 * @dev Implements rate limiting, multi-sig requirements, and emergency controls
 */
contract SecurityControls is AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // Rate limiting
    struct RateLimitConfig {
        uint256 limit; // Maximum calls within window
        uint256 window; // Time window in seconds
        uint256 currentCount; // Current number of calls
        uint256 windowStart; // Start time of current window
    }

    // Multi-sig configuration
    struct MultiSigConfig {
        uint256 requiredApprovals;
        address[] approvers;
        mapping(bytes32 => mapping(address => bool)) approvals;
        mapping(bytes32 => bool) executed;
        mapping(bytes32 => uint256) approvalCount;
    }

    // Emergency settings
    struct EmergencyConfig {
        bool circuitBreakerEnabled;
        uint256 lastEmergencyAction;
        uint256 cooldownPeriod;
    }

    // Mappings
    mapping(bytes32 => RateLimitConfig) public rateLimits;
    mapping(bytes32 => MultiSigConfig) public multiSigConfigs;
    EmergencyConfig public emergencyConfig;

    // Events
    event RateLimitConfigured(bytes32 indexed operation, uint256 limit, uint256 window);
    event RateLimitExceeded(bytes32 indexed operation, address indexed caller);
    event MultiSigConfigured(bytes32 indexed operation, uint256 requiredApprovals);
    event MultiSigApproval(bytes32 indexed operation, bytes32 indexed txHash, address indexed approver);
    event MultiSigExecuted(bytes32 indexed operation, bytes32 indexed txHash);
    event EmergencyActionTriggered(address indexed triggeredBy, string reason);
    event EmergencyCooldownUpdated(uint256 newCooldownPeriod);
    event CircuitBreakerStatusChanged(bool enabled);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);

        // Initialize emergency config with default values
        emergencyConfig.circuitBreakerEnabled = false;
        emergencyConfig.lastEmergencyAction = 0;
        emergencyConfig.cooldownPeriod = 24 hours;
    }

    // Rate limiting functions
    function _configureRateLimit(bytes32 operation, uint256 limit, uint256 window) internal {
        require(window > 0, "Window must be positive");
        require(limit > 0, "Limit must be positive");

        rateLimits[operation] =
            RateLimitConfig({limit: limit, window: window, currentCount: 0, windowStart: block.timestamp});

        emit RateLimitConfigured(operation, limit, window);
    }

    function configureRateLimit(bytes32 operation, uint256 limit, uint256 window)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _configureRateLimit(operation, limit, window);
    }

    function checkAndUpdateRateLimit(bytes32 operation) internal {
        RateLimitConfig storage rateLimit = rateLimits[operation];
        if (rateLimit.limit == 0) return; // Rate limiting not configured

        // Reset window if needed
        if (block.timestamp >= rateLimit.windowStart + rateLimit.window) {
            rateLimit.windowStart = block.timestamp;
            rateLimit.currentCount = 0;
        }

        require(rateLimit.currentCount < rateLimit.limit, "Rate limit exceeded");
        rateLimit.currentCount++;
    }

    // Multi-sig functions
    function configureMultiSig(bytes32 operation, uint256 requiredApprovals, address[] memory approvers)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _configureMultiSig(operation, requiredApprovals, approvers);
    }

    function _configureMultiSig(bytes32 operation, uint256 requiredApprovals, address[] memory approvers) internal {
        require(requiredApprovals > 0, "Required approvals must be positive");
        require(requiredApprovals <= approvers.length, "Required approvals exceeds approvers");

        MultiSigConfig storage config = multiSigConfigs[operation];
        config.requiredApprovals = requiredApprovals;

        // Clear existing approvers and copy new approvers
        delete config.approvers;
        for (uint256 i = 0; i < approvers.length; i++) {
            config.approvers.push(approvers[i]);
        }

        emit MultiSigConfigured(operation, requiredApprovals);
    }

    function approveOperation(bytes32 operation, bytes32 txHash) external {
        MultiSigConfig storage config = multiSigConfigs[operation];
        require(!config.executed[txHash], "Transaction already executed");

        // Check if the sender is an approver
        bool isApprover = false;
        for (uint256 i = 0; i < config.approvers.length; i++) {
            if (config.approvers[i] == msg.sender) {
                isApprover = true;
                break;
            }
        }
        require(isApprover, "Not an approver");

        // Record approval
        require(!config.approvals[txHash][msg.sender], "Already approved");
        config.approvals[txHash][msg.sender] = true;
        config.approvalCount[txHash]++;

        emit MultiSigApproval(operation, txHash, msg.sender);

        // Check if transaction is approved
        if (config.approvalCount[txHash] >= config.requiredApprovals) {
            config.executed[txHash] = true;
            emit MultiSigExecuted(operation, txHash);
        }
    }

    function getMultiSigConfig(bytes32 operation) external view returns (uint256, address[] memory) {
        MultiSigConfig storage config = multiSigConfigs[operation];
        return (config.requiredApprovals, config.approvers);
    }

    // Emergency control functions
    function triggerEmergency(string calldata reason) external onlyRole(EMERGENCY_ROLE) {
        // Always pause when triggering emergency, even if already paused
        if (!paused()) {
            _pause();
        }

        emergencyConfig.circuitBreakerEnabled = true;
        emergencyConfig.lastEmergencyAction = block.timestamp;

        emit EmergencyActionTriggered(msg.sender, reason);
        emit CircuitBreakerStatusChanged(true);
    }

    function resolveEmergency() external onlyRole(EMERGENCY_ROLE) {
        require(emergencyConfig.circuitBreakerEnabled, "No active emergency");

        emergencyConfig.circuitBreakerEnabled = false;
        _unpause();

        emit CircuitBreakerStatusChanged(false);
    }

    function setEmergencyCooldownPeriod(uint256 cooldownPeriod) external onlyRole(DEFAULT_ADMIN_ROLE) {
        emergencyConfig.cooldownPeriod = cooldownPeriod;
    }

    // Modifiers
    modifier rateLimitGuard(bytes32 operation) {
        checkAndUpdateRateLimit(operation);
        _;
    }

    modifier requiresApproval(bytes32 operation, bytes32 txHash) {
        MultiSigConfig storage config = multiSigConfigs[operation];
        require(config.executed[txHash], "Requires multi-sig approval");
        _;
    }

    modifier whenCircuitBreakerOff() {
        require(!emergencyConfig.circuitBreakerEnabled, "Circuit breaker is active");
        _;
    }
}
