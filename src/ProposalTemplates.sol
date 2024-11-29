// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title ProposalTemplates
 * @dev Manages templates for common governance proposals
 */
contract ProposalTemplates is AccessControl {
    using Strings for uint256;

    bytes32 public constant TEMPLATE_ADMIN_ROLE = keccak256("TEMPLATE_ADMIN_ROLE");

    struct Template {
        string name;
        string description;
        address targetContract;
        bytes4 functionSelector;
        string[] parameterNames;
        string[] parameterTypes;
        bool active;
    }

    // Mapping of template ID to Template
    mapping(uint256 => Template) public templates;
    uint256 public templateCount;

    event TemplateCreated(uint256 indexed templateId, string name);
    event TemplateUpdated(uint256 indexed templateId);
    event TemplateDeactivated(uint256 indexed templateId);

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(TEMPLATE_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Create a new proposal template
     * @param name Template name
     * @param description Template description
     * @param targetContract Contract address that the proposal will interact with
     * @param functionSelector Function selector for the proposal
     * @param parameterNames Names of the parameters
     * @param parameterTypes Solidity types of the parameters (e.g., "uint256", "address")
     */
    function createTemplate(
        string memory name,
        string memory description,
        address targetContract,
        bytes4 functionSelector,
        string[] memory parameterNames,
        string[] memory parameterTypes
    ) external onlyRole(TEMPLATE_ADMIN_ROLE) {
        require(parameterNames.length == parameterTypes.length, "Parameter mismatch");

        uint256 templateId = templateCount++;
        Template storage template = templates[templateId];

        template.name = name;
        template.description = description;
        template.targetContract = targetContract;
        template.functionSelector = functionSelector;
        template.parameterNames = parameterNames;
        template.parameterTypes = parameterTypes;
        template.active = true;

        emit TemplateCreated(templateId, name);
    }

    /**
     * @dev Deactivate a template
     * @param templateId ID of the template to deactivate
     */
    function deactivateTemplate(uint256 templateId) external onlyRole(TEMPLATE_ADMIN_ROLE) {
        require(templateId < templateCount, "Template does not exist");
        templates[templateId].active = false;
        emit TemplateDeactivated(templateId);
    }

    /**
     * @dev Get template details
     * @param templateId ID of the template
     */
    function getTemplate(uint256 templateId)
        external
        view
        returns (
            string memory name,
            string memory description,
            address targetContract,
            bytes4 functionSelector,
            string[] memory parameterNames,
            string[] memory parameterTypes,
            bool active
        )
    {
        require(templateId < templateCount, "Template does not exist");
        Template storage template = templates[templateId];
        return (
            template.name,
            template.description,
            template.targetContract,
            template.functionSelector,
            template.parameterNames,
            template.parameterTypes,
            template.active
        );
    }

    /**
     * @dev Generate proposal description from template and parameters
     * @param templateId ID of the template
     * @param parameters Array of parameter values as strings
     */
    function generateDescription(uint256 templateId, string[] memory parameters) public view returns (string memory) {
        require(templateId < templateCount, "Template does not exist");
        Template storage template = templates[templateId];
        require(parameters.length == template.parameterNames.length, "Parameter count mismatch");

        string memory description = template.description;
        for (uint256 i = 0; i < parameters.length; i++) {
            description = string(abi.encodePacked(description, "\n", template.parameterNames[i], ": ", parameters[i]));
        }
        return description;
    }

    /**
     * @dev Encode function call from template and parameters
     * @param templateId ID of the template
     * @param parameters ABI encoded parameters
     */
    function encodeProposalCall(uint256 templateId, bytes memory parameters)
        public
        view
        returns (address, bytes memory)
    {
        require(templateId < templateCount, "Template does not exist");
        Template storage template = templates[templateId];

        return (template.targetContract, abi.encodePacked(template.functionSelector, parameters));
    }
}
