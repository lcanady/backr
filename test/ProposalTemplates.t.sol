// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/ProposalTemplates.sol";

contract ProposalTemplatesTest is Test {
    ProposalTemplates public templates;
    address public owner;
    address public alice;
    address public mockContract;

    bytes32 constant TEMPLATE_ADMIN_ROLE = keccak256("TEMPLATE_ADMIN_ROLE");
    bytes4 constant TEST_FUNCTION = bytes4(keccak256("test(uint256,address)"));

    function setUp() public {
        owner = address(this);
        alice = address(0x1);
        mockContract = address(0x2);

        templates = new ProposalTemplates();
        templates.grantRole(TEMPLATE_ADMIN_ROLE, owner);
    }

    function testCreateTemplate() public {
        string memory name = "Test Template";
        string memory description = "A test template";
        string[] memory paramNames = new string[](2);
        paramNames[0] = "amount";
        paramNames[1] = "recipient";

        string[] memory paramTypes = new string[](2);
        paramTypes[0] = "uint256";
        paramTypes[1] = "address";

        templates.createTemplate(name, description, mockContract, TEST_FUNCTION, paramNames, paramTypes);

        // Verify template creation
        (
            string memory storedName,
            string memory storedDescription,
            address storedContract,
            bytes4 storedSelector,
            string[] memory storedParamNames,
            string[] memory storedParamTypes,
            bool active
        ) = templates.getTemplate(0);

        assertEq(storedName, name, "Template name mismatch");
        assertEq(storedDescription, description, "Template description mismatch");
        assertEq(storedContract, mockContract, "Target contract mismatch");
        assertEq(storedSelector, TEST_FUNCTION, "Function selector mismatch");
        assertEq(storedParamNames.length, paramNames.length, "Parameter names length mismatch");
        assertEq(storedParamTypes.length, paramTypes.length, "Parameter types length mismatch");
        assertTrue(active, "Template should be active");
    }

    function testDeactivateTemplate() public {
        // Create template
        string[] memory paramNames = new string[](0);
        string[] memory paramTypes = new string[](0);

        templates.createTemplate(
            "Test Template", "A test template", mockContract, TEST_FUNCTION, paramNames, paramTypes
        );

        // Deactivate template
        templates.deactivateTemplate(0);

        // Verify template is deactivated
        (,,,,,, bool active) = templates.getTemplate(0);
        assertFalse(active, "Template should be deactivated");
    }

    function testGenerateDescription() public {
        // Create template
        string[] memory paramNames = new string[](2);
        paramNames[0] = "amount";
        paramNames[1] = "recipient";

        string[] memory paramTypes = new string[](2);
        paramTypes[0] = "uint256";
        paramTypes[1] = "address";

        templates.createTemplate(
            "Transfer Template", "Transfer tokens to recipient", mockContract, TEST_FUNCTION, paramNames, paramTypes
        );

        // Generate description
        string[] memory params = new string[](2);
        params[0] = "1000";
        params[1] = "0x1234567890123456789012345678901234567890";

        string memory description = templates.generateDescription(0, params);
        assertTrue(bytes(description).length > 0, "Description should not be empty");
    }

    function testEncodeProposalCall() public {
        // Create template
        string[] memory paramNames = new string[](2);
        paramNames[0] = "amount";
        paramNames[1] = "recipient";

        string[] memory paramTypes = new string[](2);
        paramTypes[0] = "uint256";
        paramTypes[1] = "address";

        templates.createTemplate(
            "Transfer Template", "Transfer tokens to recipient", mockContract, TEST_FUNCTION, paramNames, paramTypes
        );

        // Encode call
        bytes memory params = abi.encode(1000, alice);
        (address target, bytes memory callData) = templates.encodeProposalCall(0, params);

        assertEq(target, mockContract, "Target contract mismatch");
        assertEq(bytes4(callData), TEST_FUNCTION, "Function selector mismatch");
    }

    function testOnlyAdminCanCreateTemplate() public {
        string[] memory paramNames = new string[](0);
        string[] memory paramTypes = new string[](0);

        vm.startPrank(alice);
        vm.expectRevert(
            hex"e2517d3f000000000000000000000000000000000000000000000000000000000000000160a76a0b70eaebb9f781b27a8b41cd86da9ad7659595aff5cd32f3d522fa85ba"
        );
        templates.createTemplate(
            "Test Template", "A test template", mockContract, TEST_FUNCTION, paramNames, paramTypes
        );
        vm.stopPrank();
    }

    function testParameterMismatch() public {
        string[] memory paramNames = new string[](2);
        paramNames[0] = "param1";
        paramNames[1] = "param2";

        string[] memory paramTypes = new string[](1);
        paramTypes[0] = "uint256";

        vm.expectRevert("Parameter mismatch");
        templates.createTemplate(
            "Test Template", "A test template", mockContract, TEST_FUNCTION, paramNames, paramTypes
        );
    }

    function testInvalidTemplateId() public {
        vm.expectRevert("Template does not exist");
        templates.getTemplate(999);
    }

    function testGenerateDescriptionParameterCountMismatch() public {
        // Create template
        string[] memory paramNames = new string[](2);
        paramNames[0] = "param1";
        paramNames[1] = "param2";

        string[] memory paramTypes = new string[](2);
        paramTypes[0] = "uint256";
        paramTypes[1] = "uint256";

        templates.createTemplate(
            "Test Template", "A test template", mockContract, TEST_FUNCTION, paramNames, paramTypes
        );

        // Try to generate description with wrong parameter count
        string[] memory params = new string[](1);
        params[0] = "100";

        vm.expectRevert("Parameter count mismatch");
        templates.generateDescription(0, params);
    }
}
