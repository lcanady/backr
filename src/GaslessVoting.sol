// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/**
 * @title GaslessVoting
 * @dev Implements meta-transactions for gasless voting in governance
 */
contract GaslessVoting is EIP712 {
    using ECDSA for bytes32;

    // Typed struct for EIP-712
    struct VotePermit {
        address voter;
        uint256 proposalId;
        bool support;
        uint256 nonce;
        uint256 deadline;
    }

    // Mapping of voter nonces for replay protection
    mapping(address => uint256) public nonces;

    // EIP-712 type hash
    bytes32 public constant VOTE_PERMIT_TYPEHASH =
        keccak256("VotePermit(address voter,uint256 proposalId,bool support,uint256 nonce,uint256 deadline)");

    constructor() EIP712("Backr Governance", "1") {}

    /**
     * @dev Returns the current nonce for an address
     * @param voter Address to get nonce for
     */
    function getNonce(address voter) public view returns (uint256) {
        return nonces[voter];
    }

    /**
     * @dev Returns the domain separator used in the encoding of the signature for permits, as defined by EIP712
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @dev Verifies vote permit signature and returns the signer
     * @param permit Vote permit struct
     * @param signature Signature bytes
     */
    function verifyVotePermit(VotePermit memory permit, bytes memory signature) public view returns (address) {
        bytes32 structHash = keccak256(
            abi.encode(
                VOTE_PERMIT_TYPEHASH, permit.voter, permit.proposalId, permit.support, permit.nonce, permit.deadline
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = hash.recover(signature);

        require(signer == permit.voter, "GaslessVoting: invalid signature");
        require(block.timestamp <= permit.deadline, "GaslessVoting: expired deadline");
        require(nonces[permit.voter] == permit.nonce, "GaslessVoting: invalid nonce");

        return signer;
    }

    /**
     * @dev Processes a vote permit, incrementing nonce if valid
     * @param permit Vote permit struct
     * @param signature Signature bytes
     */
    function _processVotePermit(VotePermit memory permit, bytes memory signature) internal {
        verifyVotePermit(permit, signature);
        nonces[permit.voter]++;
    }
}
