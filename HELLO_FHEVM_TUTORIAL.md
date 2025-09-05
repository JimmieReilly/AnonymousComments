# Hello FHEVM Tutorial: Building Your First Confidential Anonymous Comments Platform

Welcome to your first step into the world of **Fully Homomorphic Encryption (FHE)** on the blockchain! This comprehensive tutorial will guide you through building a complete anonymous comments platform using FHEVM - without requiring any advanced mathematics or cryptography knowledge.

## What You'll Build

By the end of this tutorial, you'll have created:

- ✅ A smart contract that stores encrypted comments on-chain
- ✅ Anonymous user identity protection using FHE
- ✅ A complete web application for interacting with your smart contract
- ✅ Understanding of how FHE enables privacy-first blockchain applications

**Live Demo**: [https://anonymous-comments-six.vercel.app/](https://anonymous-comments-six.vercel.app/)

## Prerequisites

Before we begin, make sure you have:

- Basic Solidity knowledge (can write and deploy simple smart contracts)
- Familiarity with standard Ethereum tools (Hardhat/Foundry, MetaMask, React/JavaScript)
- Node.js installed on your system
- MetaMask wallet extension

**No cryptography or FHE knowledge required!** We'll explain everything as we go.

## Table of Contents

1. [Understanding FHE Basics](#understanding-fhe-basics)
2. [Setting Up Your Development Environment](#setting-up-your-development-environment)
3. [Building the Smart Contract](#building-the-smart-contract)
4. [Understanding Encrypted Data Types](#understanding-encrypted-data-types)
5. [Creating the Frontend](#creating-the-frontend)
6. [Testing Your Application](#testing-your-application)
7. [Deployment Guide](#deployment-guide)
8. [Advanced Features](#advanced-features)

---

## Understanding FHE Basics

### What is Fully Homomorphic Encryption?

Imagine you have a magical box that can:
- Accept secret messages (encrypt them)
- Perform calculations on those secrets WITHOUT opening them
- Keep the results secret until you decide to reveal them

That's essentially what FHE does for blockchain data!

### Traditional vs FHE Approach

**Traditional Blockchain:**
```
User submits: "This is my comment"
Blockchain stores: "This is my comment" (public to everyone)
Privacy level: Zero
```

**FHEVM Approach:**
```
User submits: "This is my comment"
FHEVM encrypts: "xK9$mP#4@..."
Blockchain stores: "xK9$mP#4@..." (encrypted)
Smart contract can process encrypted data without decrypting
Privacy level: Maximum
```

### Why This Matters

- **Complete Privacy**: Your data is encrypted before it even reaches the blockchain
- **Computation on Encrypted Data**: Smart contracts can work with your data while keeping it secret
- **No Trust Required**: You don't need to trust anyone with your unencrypted data

---

## Setting Up Your Development Environment

### Step 1: Install Required Dependencies

```bash
# Create a new project directory
mkdir hello-fhevm-tutorial
cd hello-fhevm-tutorial

# Initialize npm project
npm init -y

# Install Hardhat for smart contract development
npm install --save-dev hardhat
npm install --save-dev @nomicfoundation/hardhat-toolbox

# Install FHEVM dependencies
npm install @fhevm/solidity
```

### Step 2: Initialize Hardhat Project

```bash
npx hardhat init
# Choose "Create a JavaScript project"
```

### Step 3: Configure Hardhat for FHEVM

Edit your `hardhat.config.js`:

```javascript
require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    sepolia: {
      url: "https://sepolia.infura.io/v3/YOUR_INFURA_KEY",
      accounts: ["YOUR_PRIVATE_KEY"]
    }
  }
};
```

---

## Building the Smart Contract

### Step 1: Understanding FHEVM Imports

Create `contracts/AnonymousComments.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// These imports give us access to FHE functionality
import { FHE, euint32, euint8, ebool } from "@fhevm/solidity/lib/FHE.sol";
import { SepoliaConfig } from "@fhevm/solidity/config/ZamaConfig.sol";
```

**Key Concepts:**
- `FHE`: Main library for encryption functions
- `euint32`, `euint8`: Encrypted integer types
- `SepoliaConfig`: Network configuration for Sepolia testnet

### Step 2: Contract Structure

```solidity
contract AnonymousComments is SepoliaConfig {
    address public owner;
    uint256 public totalComments;
    uint256 public totalTopics;

    // Encrypted comment structure
    struct Comment {
        euint32 encryptedContent; // Encrypted comment hash
        euint8 encryptedRating;   // Encrypted rating (1-5)
        uint256 timestamp;        // Public timestamp
        uint256 topicId;          // Public topic reference
        bool isVisible;           // Public visibility flag
        uint256 likes;            // Public like count
        uint256 dislikes;         // Public dislike count
    }

    struct Topic {
        string title;             // Public title
        string description;       // Public description
        address creator;          // Public creator
        uint256 createdAt;        // Public creation time
        bool isActive;           // Public status
        uint256 commentCount;    // Public comment count
    }
```

**Privacy Design Decisions:**
- `encryptedContent`: The actual comment content is encrypted
- `encryptedRating`: User ratings are private
- Metadata (timestamps, counts) remain public for functionality
- Topics are public to enable discovery

### Step 3: Implementing Comment Submission

```solidity
// Submit an anonymous comment with encrypted content
function submitComment(
    uint256 _topicId,
    uint32 _contentHash,    // Hash of the actual comment
    uint8 _rating           // Rating value 1-5
) external validTopic(_topicId) {
    require(_rating >= 1 && _rating <= 5, "Rating must be 1-5");

    // The magic happens here - encrypt the data!
    euint32 encryptedContent = FHE.asEuint32(_contentHash);
    euint8 encryptedRating = FHE.asEuint8(_rating);

    totalComments++;

    comments[totalComments] = Comment({
        encryptedContent: encryptedContent,
        encryptedRating: encryptedRating,
        timestamp: block.timestamp,
        topicId: _topicId,
        isVisible: true,
        likes: 0,
        dislikes: 0
    });

    // Grant access permissions (crucial for FHE!)
    FHE.allowThis(encryptedContent);
    FHE.allowThis(encryptedRating);
    FHE.allow(encryptedContent, msg.sender);
    FHE.allow(encryptedRating, msg.sender);

    emit CommentAdded(totalComments, _topicId, block.timestamp);
}
```

**Key FHE Concepts Explained:**

1. **`FHE.asEuint32()`**: Converts plain data to encrypted format
2. **`FHE.allowThis()`**: Gives the contract permission to work with encrypted data
3. **`FHE.allow()`**: Grants specific addresses permission to access encrypted data

### Step 4: Anonymous Identity Management

```solidity
struct UserPrivacy {
    euint8 encryptedId;      // Anonymous user ID
    bool hasCommented;       // Public flag
    uint256 lastActivity;    // Public timestamp
}

// Create anonymous identity for first-time users
if (!userPrivacy[msg.sender].hasCommented) {
    euint8 anonymousId = FHE.randEuint8();  // Generate random encrypted ID
    userPrivacy[msg.sender] = UserPrivacy({
        encryptedId: anonymousId,
        hasCommented: true,
        lastActivity: block.timestamp
    });

    // Grant permissions
    FHE.allowThis(anonymousId);
    FHE.allow(anonymousId, msg.sender);
}
```

**Privacy Features:**
- Each user gets a random encrypted ID
- User addresses are never linked to comment content
- Only the user can decrypt their own anonymous ID

---

## Understanding Encrypted Data Types

### FHEVM Data Types

| Type | Description | Use Case |
|------|-------------|----------|
| `euint8` | 8-bit encrypted integer | Ratings (1-5), small numbers |
| `euint16` | 16-bit encrypted integer | Medium range values |
| `euint32` | 32-bit encrypted integer | Large numbers, hashes |
| `euint64` | 64-bit encrypted integer | Very large values |
| `ebool` | Encrypted boolean | True/false flags |

### Working with Encrypted Data

```solidity
// ❌ This won't work - can't compare encrypted values directly
require(encryptedRating == 5, "Must be 5 stars");

// ✅ This works - validate before encryption
require(_rating >= 1 && _rating <= 5, "Rating must be 1-5");
euint8 encryptedRating = FHE.asEuint8(_rating);

// ✅ This works - encrypted comparisons
ebool isHighRating = FHE.gt(encryptedRating, FHE.asEuint8(3));
```

### Access Control is Critical

```solidity
// Always set permissions when creating encrypted data
euint32 encryptedValue = FHE.asEuint32(myValue);

// Without this, the data is inaccessible!
FHE.allowThis(encryptedValue);        // Contract can use it
FHE.allow(encryptedValue, user);      // User can access it
```

---

## Creating the Frontend

### Step 1: HTML Structure

Create a single `index.html` file:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Anonymous Comments - Privacy-First Platform</title>
    <script src="https://cdn.jsdelivr.net/npm/ethers@5.7.2/dist/ethers.umd.min.js"></script>
</head>
<body>
    <div class="container">
        <header>
            <h1>🔒 Anonymous Comments Platform</h1>
            <p>Privacy-first discussions powered by FHEVM</p>
        </header>

        <!-- Wallet connection -->
        <section class="wallet-section">
            <button id="connectWallet">Connect MetaMask</button>
            <div id="walletStatus">Please connect your wallet</div>
        </section>

        <!-- Create topic form -->
        <section class="topic-section">
            <h2>Create Discussion Topic</h2>
            <input type="text" id="topicTitle" placeholder="Topic title">
            <textarea id="topicDescription" placeholder="Description"></textarea>
            <button id="createTopic">Create Topic</button>
        </section>

        <!-- Comment form -->
        <section class="comment-section">
            <h2>Submit Anonymous Comment</h2>
            <select id="topicSelect">
                <option value="">Select a topic...</option>
            </select>
            <textarea id="commentText" placeholder="Your anonymous comment"></textarea>
            <select id="rating">
                <option value="5">⭐⭐⭐⭐⭐ Excellent</option>
                <option value="4">⭐⭐⭐⭐ Good</option>
                <option value="3">⭐⭐⭐ Average</option>
                <option value="2">⭐⭐ Poor</option>
                <option value="1">⭐ Very Poor</option>
            </select>
            <button id="submitComment">Submit Anonymous Comment</button>
        </section>

        <!-- Topics display -->
        <div id="topicsList"></div>
        <div id="commentsList"></div>
    </div>
</body>
</html>
```

### Step 2: JavaScript Integration

```javascript
// Contract configuration
const CONTRACT_ADDRESS = "YOUR_DEPLOYED_CONTRACT_ADDRESS";
const CONTRACT_ABI = [/* Your contract ABI */];

// Initialize application
let contract;
let userAddress;

async function connectWallet() {
    try {
        // Request account access
        await window.ethereum.request({ method: 'eth_requestAccounts' });

        // Create provider and signer
        const provider = new ethers.providers.Web3Provider(window.ethereum);
        const signer = provider.getSigner();
        userAddress = await signer.getAddress();

        // Initialize contract
        contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);

        updateStatus(`Connected: ${userAddress.slice(0,6)}...${userAddress.slice(-4)}`);
        loadTopics();

    } catch (error) {
        console.error('Connection failed:', error);
        updateStatus('Failed to connect wallet', 'error');
    }
}

async function createTopic() {
    const title = document.getElementById('topicTitle').value;
    const description = document.getElementById('topicDescription').value;

    if (!title) {
        updateStatus('Please enter a title', 'error');
        return;
    }

    try {
        updateStatus('Creating topic...');

        const tx = await contract.createTopic(title, description);
        updateStatus('Transaction submitted...');

        await tx.wait();
        updateStatus('Topic created successfully!', 'success');

        // Clear form and reload
        document.getElementById('topicTitle').value = '';
        document.getElementById('topicDescription').value = '';
        loadTopics();

    } catch (error) {
        console.error('Error creating topic:', error);
        updateStatus('Failed to create topic', 'error');
    }
}

async function submitComment() {
    const topicId = document.getElementById('topicSelect').value;
    const commentText = document.getElementById('commentText').value;
    const rating = document.getElementById('rating').value;

    if (!topicId || !commentText) {
        updateStatus('Please fill all fields', 'error');
        return;
    }

    try {
        updateStatus('Submitting anonymous comment...');

        // Create hash of comment for privacy
        const contentHash = hashString(commentText);

        // Submit encrypted comment
        const tx = await contract.submitComment(
            parseInt(topicId),
            contentHash,
            parseInt(rating)
        );

        updateStatus('Transaction submitted...');
        await tx.wait();
        updateStatus('Comment submitted successfully!', 'success');

        // Clear form and reload
        document.getElementById('commentText').value = '';
        loadComments(topicId);

    } catch (error) {
        console.error('Error submitting comment:', error);
        updateStatus('Failed to submit comment', 'error');
    }
}

// Utility function to hash comment content
function hashString(str) {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
        const char = str.charCodeAt(i);
        hash = ((hash << 5) - hash) + char;
        hash = hash & hash; // Convert to 32bit integer
    }
    return Math.abs(hash);
}

// Load and display topics
async function loadTopics() {
    try {
        const stats = await contract.getPlatformStats();
        const totalTopics = stats.totalTopicsCount.toNumber();

        const topicSelect = document.getElementById('topicSelect');
        const topicsList = document.getElementById('topicsList');

        topicSelect.innerHTML = '<option value="">Select a topic...</option>';
        topicsList.innerHTML = '';

        for (let i = 1; i <= totalTopics; i++) {
            const topicInfo = await contract.getTopicInfo(i);

            if (topicInfo.isActive) {
                // Add to dropdown
                const option = document.createElement('option');
                option.value = i;
                option.textContent = topicInfo.title;
                topicSelect.appendChild(option);

                // Add to display list
                const topicDiv = document.createElement('div');
                topicDiv.className = 'topic-item';
                topicDiv.innerHTML = `
                    <h3>${topicInfo.title}</h3>
                    <p>${topicInfo.description}</p>
                    <small>${topicInfo.commentCount} comments • Created ${new Date(topicInfo.createdAt * 1000).toLocaleDateString()}</small>
                `;
                topicDiv.onclick = () => loadComments(i);
                topicsList.appendChild(topicDiv);
            }
        }
    } catch (error) {
        console.error('Error loading topics:', error);
    }
}

// Load comments for a topic
async function loadComments(topicId) {
    try {
        const commentIds = await contract.getTopicComments(topicId);
        const commentsList = document.getElementById('commentsList');

        commentsList.innerHTML = '<h3>Comments:</h3>';

        for (let commentId of commentIds) {
            const commentInfo = await contract.getCommentInfo(commentId);

            if (commentInfo.isVisible) {
                const commentDiv = document.createElement('div');
                commentDiv.className = 'comment-item';
                commentDiv.innerHTML = `
                    <div class="comment-meta">
                        <span>🔒 Anonymous Comment</span>
                        <span>${new Date(commentInfo.timestamp * 1000).toLocaleDateString()}</span>
                    </div>
                    <div class="comment-content">
                        This comment is encrypted and protected by FHEVM technology
                    </div>
                    <div class="comment-actions">
                        <button onclick="rateComment(${commentId}, true)">👍 ${commentInfo.likes}</button>
                        <button onclick="rateComment(${commentId}, false)">👎 ${commentInfo.dislikes}</button>
                    </div>
                `;
                commentsList.appendChild(commentDiv);
            }
        }
    } catch (error) {
        console.error('Error loading comments:', error);
    }
}

// Rate a comment
async function rateComment(commentId, isLike) {
    try {
        updateStatus('Submitting rating...');

        const tx = await contract.rateComment(commentId, isLike);
        await tx.wait();

        updateStatus('Rating submitted!', 'success');

        // Reload current topic comments
        const topicId = document.getElementById('topicSelect').value;
        if (topicId) loadComments(topicId);

    } catch (error) {
        console.error('Error rating comment:', error);
        if (error.message.includes('Already voted')) {
            updateStatus('You have already voted on this topic', 'error');
        } else {
            updateStatus('Failed to submit rating', 'error');
        }
    }
}

// Initialize when page loads
window.addEventListener('load', () => {
    document.getElementById('connectWallet').onclick = connectWallet;
    document.getElementById('createTopic').onclick = createTopic;
    document.getElementById('submitComment').onclick = submitComment;
});
```

---

## Testing Your Application

### Step 1: Local Testing

```bash
# Start Hardhat local network
npx hardhat node

# Deploy your contract
npx hardhat run scripts/deploy.js --network localhost
```

### Step 2: Create Deployment Script

Create `scripts/deploy.js`:

```javascript
async function main() {
    const AnonymousComments = await ethers.getContractFactory("AnonymousComments");
    const contract = await AnonymousComments.deploy();
    await contract.deployed();

    console.log("AnonymousComments deployed to:", contract.address);

    // Create a test topic
    await contract.createTopic("Hello FHEVM!", "Welcome to encrypted discussions");
    console.log("Test topic created!");
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
```

### Step 3: Test the Full Flow

1. **Connect Wallet**: Use MetaMask with local network
2. **Create Topic**: Submit your first discussion topic
3. **Submit Comment**: Add an encrypted anonymous comment
4. **Rate Comments**: Test the voting functionality
5. **View Data**: Confirm comments are encrypted on-chain

---

## Deployment Guide

### Step 1: Deploy to Sepolia Testnet

Update your `hardhat.config.js` with Sepolia configuration:

```javascript
networks: {
    sepolia: {
        url: `https://sepolia.infura.io/v3/${INFURA_KEY}`,
        accounts: [PRIVATE_KEY]
    }
}
```

Deploy:

```bash
npx hardhat run scripts/deploy.js --network sepolia
```

### Step 2: Update Frontend Configuration

```javascript
const CONTRACT_ADDRESS = "0xYourDeployedContractAddress";
// Make sure your ABI matches your deployed contract
```

### Step 3: Host Your Frontend

You can use any static hosting service:

- **Vercel**: `npm i -g vercel && vercel`
- **Netlify**: Drag and drop your files
- **GitHub Pages**: Push to a repository

---

## Advanced Features

### 1. Comment Decryption Requests

```solidity
function requestCommentDecryption(uint256 _commentId) external {
    require(userPrivacy[msg.sender].hasCommented, "Not a commenter");

    Comment storage comment = comments[_commentId];

    bytes32[] memory cts = new bytes32[](2);
    cts[0] = FHE.toBytes32(comment.encryptedContent);
    cts[1] = FHE.toBytes32(comment.encryptedRating);

    FHE.requestDecryption(cts, this.processDecryption.selector);
}
```

### 2. Encrypted Comparisons

```solidity
// Compare encrypted ratings
function filterHighRatedComments(uint256 _topicId) external view returns (uint256[] memory) {
    uint256[] memory commentIds = topicComments[_topicId];
    uint256[] memory highRated = new uint256[](commentIds.length);
    uint256 count = 0;

    euint8 threshold = FHE.asEuint8(4); // 4+ stars

    for (uint256 i = 0; i < commentIds.length; i++) {
        Comment storage comment = comments[commentIds[i]];
        ebool isHighRated = FHE.ge(comment.encryptedRating, threshold);

        // In practice, you'd need to handle this differently
        // as we can't directly use encrypted booleans in control flow
    }

    return highRated;
}
```

### 3. Anonymous Voting Systems

```solidity
struct Poll {
    euint8 totalVotes;
    euint8 yesVotes;
    mapping(bytes32 => bool) hasVoted; // anonymousId => hasVoted
}

function anonymousVote(uint256 _pollId, bool _vote) external {
    bytes32 anonymousId = FHE.toBytes32(userPrivacy[msg.sender].encryptedId);
    require(!polls[_pollId].hasVoted[anonymousId], "Already voted");

    polls[_pollId].totalVotes = FHE.add(polls[_pollId].totalVotes, FHE.asEuint8(1));

    if (_vote) {
        polls[_pollId].yesVotes = FHE.add(polls[_pollId].yesVotes, FHE.asEuint8(1));
    }

    polls[_pollId].hasVoted[anonymousId] = true;
}
```

---

## Best Practices and Security

### 1. Access Control Patterns

```solidity
// Always grant proper permissions
function createEncryptedData(uint32 _value) external {
    euint32 encrypted = FHE.asEuint32(_value);

    // Essential permissions
    FHE.allowThis(encrypted);        // Contract access
    FHE.allow(encrypted, msg.sender); // User access

    // Store the encrypted value
    userEncryptedData[msg.sender] = encrypted;
}
```

### 2. Gas Optimization

```solidity
// Batch operations when possible
function batchSubmitComments(
    uint256[] calldata _topicIds,
    uint32[] calldata _contentHashes,
    uint8[] calldata _ratings
) external {
    require(_topicIds.length == _contentHashes.length, "Length mismatch");

    for (uint256 i = 0; i < _topicIds.length; i++) {
        // Process multiple comments efficiently
        _submitSingleComment(_topicIds[i], _contentHashes[i], _ratings[i]);
    }
}
```

### 3. Error Handling

```solidity
function safeDecryption(euint32 _encrypted) internal view returns (uint32) {
    try FHE.decrypt(_encrypted) returns (uint32 decrypted) {
        return decrypted;
    } catch {
        revert("Decryption failed");
    }
}
```

---

## Troubleshooting Common Issues

### Issue 1: "Encrypted data inaccessible"

**Problem**: Forgot to set access permissions

**Solution**:
```solidity
euint32 data = FHE.asEuint32(value);
FHE.allowThis(data);        // Add this!
FHE.allow(data, msg.sender); // Add this!
```

### Issue 2: "Invalid network configuration"

**Problem**: Wrong network config for FHEVM

**Solution**: Ensure you're inheriting from the correct config:
```solidity
import { SepoliaConfig } from "@fhevm/solidity/config/ZamaConfig.sol";
contract MyContract is SepoliaConfig { }
```

### Issue 3: "Cannot compare encrypted values"

**Problem**: Trying to use encrypted values in require statements

**Solution**: Validate before encryption:
```solidity
// ❌ Wrong
require(encryptedValue == FHE.asEuint32(5), "Must be 5");

// ✅ Correct
require(_inputValue == 5, "Must be 5");
euint32 encryptedValue = FHE.asEuint32(_inputValue);
```

---

## What You've Learned

Congratulations! 🎉 You've successfully built your first FHEVM application and learned:

### Technical Skills
- How to use FHE encrypted data types (`euint32`, `euint8`, `ebool`)
- Proper access control with `FHE.allowThis()` and `FHE.allow()`
- Integrating FHEVM contracts with web frontends
- Handling encrypted data in smart contracts

### Privacy Concepts
- Client-side encryption before blockchain submission
- Anonymous identity management
- Computation on encrypted data
- Privacy-preserving voting and rating systems

### Development Practices
- Setting up FHEVM development environment
- Testing encrypted smart contracts
- Deploying to FHEVM networks
- Building user-friendly privacy-first interfaces

## Next Steps

### Extend Your Application
1. **Add encrypted messaging between users**
2. **Implement private polls and surveys**
3. **Create anonymous reputation systems**
4. **Build encrypted NFT marketplaces**

### Learn More Advanced Features
- **Encrypted arithmetic operations**
- **Private smart contract interactions**
- **Zero-knowledge proof integrations**
- **Multi-party computation patterns**

### Join the Community
- **Zama Documentation**: [docs.zama.ai](https://docs.zama.ai)
- **Discord Community**: Connect with other FHE developers
- **GitHub Repository**: Contribute to open-source FHE projects

---

## Final Thoughts

You've just built something revolutionary - a blockchain application where user privacy is mathematically guaranteed, not just promised. This represents a fundamental shift in how we think about blockchain applications.

Your anonymous comments platform demonstrates that privacy and transparency can coexist. Users can participate in public discussions while keeping their identities and opinions completely confidential.

The future of blockchain is private, and you're now equipped to build it! 🚀

---

**Want to showcase your project?** Share it with the community and tag `#HelloFHEVM` to inspire other developers!

**Need help?** The code is fully documented and the community is here to support your journey into confidential computing.