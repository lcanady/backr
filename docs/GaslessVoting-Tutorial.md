# Gasless Voting Tutorial

This tutorial explains how to use the GaslessVoting contract, which implements meta-transactions to enable gas-free voting in the Backr governance system.

## Overview

GaslessVoting enables users to vote on governance proposals without paying gas fees by using meta-transactions. This is achieved through EIP-712 signed messages that can be submitted to the blockchain by anyone on behalf of the voter.

## Core Concepts

### Vote Permits
A vote permit contains:
- Voter address
- Proposal ID
- Support (true/false)
- Nonce (for replay protection)
- Deadline (timestamp)

### EIP-712 Typing
The contract uses EIP-712 for structured data signing with the following domain:
- Name: "Backr Governance"
- Version: "1"

## Creating and Signing Vote Permits

### 1. Creating a Vote Permit

```javascript
// Using ethers.js
const permit = {
    voter: voterAddress,
    proposalId: proposalId,
    support: true,  // true for support, false against
    nonce: await governance.getNonce(voterAddress),
    deadline: Math.floor(Date.now() / 1000) + 3600 // 1 hour from now
};
```

### 2. Signing the Permit

```javascript
// Using ethers.js
const domain = {
    name: 'Backr Governance',
    version: '1',
    chainId: await signer.getChainId(),
    verifyingContract: governanceAddress
};

const types = {
    VotePermit: [
        { name: 'voter', type: 'address' },
        { name: 'proposalId', type: 'uint256' },
        { name: 'support', type: 'bool' },
        { name: 'nonce', type: 'uint256' },
        { name: 'deadline', type: 'uint256' }
    ]
};

const signature = await signer._signTypedData(domain, types, permit);
```

## Submitting Vote Permits

### On-Chain Verification

The contract verifies:
1. Signature validity
2. Deadline not expired
3. Correct nonce
4. Signer matches voter

```solidity
// Submit vote with permit
governance.castVoteWithPermit(permit, signature);
```

### Checking Nonces

```solidity
// Get current nonce for an address
uint256 nonce = governance.getNonce(voterAddress);
```

## Complete Implementation Example

Here's a full example using ethers.js:

```javascript
async function submitGaslessVote(
    signer,
    governanceContract,
    proposalId,
    support
) {
    // 1. Get current nonce
    const nonce = await governanceContract.getNonce(await signer.getAddress());
    
    // 2. Create permit
    const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour
    const permit = {
        voter: await signer.getAddress(),
        proposalId: proposalId,
        support: support,
        nonce: nonce,
        deadline: deadline
    };

    // 3. Prepare EIP-712 signature
    const domain = {
        name: 'Backr Governance',
        version: '1',
        chainId: await signer.getChainId(),
        verifyingContract: governanceContract.address
    };

    const types = {
        VotePermit: [
            { name: 'voter', type: 'address' },
            { name: 'proposalId', type: 'uint256' },
            { name: 'support', type: 'bool' },
            { name: 'nonce', type: 'uint256' },
            { name: 'deadline', type: 'uint256' }
        ]
    };

    // 4. Sign the permit
    const signature = await signer._signTypedData(domain, types, permit);

    // 5. Submit the vote
    // This can be done by anyone, not necessarily the signer
    return governanceContract.castVoteWithPermit(permit, signature);
}
```

## Frontend Integration Example

```javascript
// React component example
function GaslessVoteButton({ proposalId, support }) {
    const { signer } = useEthers();
    const governanceContract = useGovernanceContract();

    async function handleVote() {
        try {
            const tx = await submitGaslessVote(
                signer,
                governanceContract,
                proposalId,
                support
            );
            await tx.wait();
            console.log('Vote submitted successfully');
        } catch (error) {
            console.error('Error submitting vote:', error);
        }
    }

    return (
        <button onClick={handleVote}>
            Vote {support ? 'For' : 'Against'}
        </button>
    );
}
```

## Relay Server Implementation

To fully enable gasless voting, you'll need a relay server to submit transactions:

```javascript
// Relay server example (Node.js)
const ethers = require('ethers');
const express = require('express');

const app = express();
const provider = new ethers.providers.JsonRpcProvider(RPC_URL);
const relayerWallet = new ethers.Wallet(PRIVATE_KEY, provider);
const governanceContract = new ethers.Contract(
    GOVERNANCE_ADDRESS,
    GOVERNANCE_ABI,
    relayerWallet
);

app.post('/relay-vote', async (req, res) => {
    try {
        const { permit, signature } = req.body;
        
        // Verify permit before submitting
        const signer = await governanceContract.verifyVotePermit(
            permit,
            signature
        );
        
        if (signer.toLowerCase() !== permit.voter.toLowerCase()) {
            throw new Error('Invalid signature');
        }

        // Submit the vote
        const tx = await governanceContract.castVoteWithPermit(
            permit,
            signature
        );
        await tx.wait();

        res.json({ txHash: tx.hash });
    } catch (error) {
        res.status(400).json({ error: error.message });
    }
});
```

## Security Considerations

1. **Signature Verification**
   - Always verify signatures server-side
   - Check deadline hasn't expired
   - Verify nonce matches expected value

2. **Nonce Management**
   - Track nonces carefully
   - Handle nonce conflicts
   - Consider nonce recovery mechanisms

3. **Relay Server**
   - Implement rate limiting
   - Verify all parameters
   - Monitor gas prices
   - Handle transaction failures

4. **Frontend**
   - Validate all inputs
   - Handle signature rejections
   - Show clear transaction status
   - Implement proper error handling

## Best Practices

1. **Permit Creation**
   - Use reasonable deadlines
   - Verify nonce before signing
   - Include clear metadata

2. **Signature Handling**
   - Store signatures securely
   - Clear signatures after use
   - Handle signature errors gracefully

3. **Transaction Submission**
   - Implement proper retries
   - Monitor transaction status
   - Handle reversion cases
   - Provide clear user feedback

4. **Error Handling**
   - Implement proper error messages
   - Handle network issues
   - Provide recovery mechanisms
   - Log errors for debugging

## Testing

Example test cases using Hardhat:

```javascript
describe("GaslessVoting", function() {
    it("Should accept valid vote permit", async function() {
        const [voter] = await ethers.getSigners();
        const proposalId = 1;
        const support = true;
        
        // Create and sign permit
        const permit = {
            voter: voter.address,
            proposalId: proposalId,
            support: support,
            nonce: await governance.getNonce(voter.address),
            deadline: Math.floor(Date.now() / 1000) + 3600
        };
        
        const signature = await createPermitSignature(
            voter,
            governance,
            permit
        );
        
        // Submit vote
        await expect(
            governance.castVoteWithPermit(permit, signature)
        ).to.not.be.reverted;
    });

    it("Should reject expired permit", async function() {
        // Test implementation
    });

    it("Should reject invalid signature", async function() {
        // Test implementation
    });

    it("Should reject reused nonce", async function() {
        // Test implementation
    });
});
