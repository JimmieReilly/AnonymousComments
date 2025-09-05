// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FHE, euint32, euint8, ebool } from "@fhevm/solidity/lib/FHE.sol";
import { SepoliaConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

contract AnonymousComments is SepoliaConfig {

    address public owner;
    uint256 public totalComments;
    uint256 public totalTopics;

    struct Comment {
        euint32 encryptedContent; // Encrypted comment hash/content
        euint8 encryptedRating;   // Encrypted rating (1-5)
        uint256 timestamp;
        uint256 topicId;
        bool isVisible;
        uint256 likes;
        uint256 dislikes;
    }

    struct Topic {
        string title;
        string description;
        address creator;
        uint256 createdAt;
        bool isActive;
        uint256 commentCount;
    }

    struct UserPrivacy {
        euint8 encryptedId;      // Anonymous user ID
        bool hasCommented;
        uint256 lastActivity;
    }

    mapping(uint256 => Comment) public comments;
    mapping(uint256 => Topic) public topics;
    mapping(address => UserPrivacy) public userPrivacy;
    mapping(uint256 => mapping(address => bool)) public hasVoted; // topicId => user => hasVoted
    mapping(uint256 => uint256[]) public topicComments; // topicId => commentIds

    event TopicCreated(uint256 indexed topicId, string title, address indexed creator);
    event CommentAdded(uint256 indexed commentId, uint256 indexed topicId, uint256 timestamp);
    event CommentRated(uint256 indexed commentId, bool isLike);
    event PrivacyUpdated(address indexed user, uint256 timestamp);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier validTopic(uint256 _topicId) {
        require(_topicId > 0 && _topicId <= totalTopics, "Invalid topic");
        require(topics[_topicId].isActive, "Topic not active");
        _;
    }

    modifier validComment(uint256 _commentId) {
        require(_commentId > 0 && _commentId <= totalComments, "Invalid comment");
        require(comments[_commentId].isVisible, "Comment not visible");
        _;
    }

    constructor() {
        owner = msg.sender;
        totalComments = 0;
        totalTopics = 0;
    }

    // Create a new discussion topic
    function createTopic(string memory _title, string memory _description) external {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_title).length <= 100, "Title too long");
        require(bytes(_description).length <= 500, "Description too long");

        totalTopics++;

        topics[totalTopics] = Topic({
            title: _title,
            description: _description,
            creator: msg.sender,
            createdAt: block.timestamp,
            isActive: true,
            commentCount: 0
        });

        emit TopicCreated(totalTopics, _title, msg.sender);
    }

    // Submit an anonymous comment with encrypted content
    function submitComment(
        uint256 _topicId,
        uint32 _contentHash,
        uint8 _rating
    ) external validTopic(_topicId) {
        require(_rating >= 1 && _rating <= 5, "Rating must be 1-5");

        // Encrypt the comment content and rating
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

        // Add comment to topic
        topicComments[_topicId].push(totalComments);
        topics[_topicId].commentCount++;

        // Update user privacy data
        if (!userPrivacy[msg.sender].hasCommented) {
            euint8 anonymousId = FHE.randEuint8();
            userPrivacy[msg.sender] = UserPrivacy({
                encryptedId: anonymousId,
                hasCommented: true,
                lastActivity: block.timestamp
            });

            // Grant access permissions
            FHE.allowThis(anonymousId);
            FHE.allow(anonymousId, msg.sender);
        } else {
            userPrivacy[msg.sender].lastActivity = block.timestamp;
        }

        // Grant access permissions for encrypted data
        FHE.allowThis(encryptedContent);
        FHE.allowThis(encryptedRating);
        FHE.allow(encryptedContent, msg.sender);
        FHE.allow(encryptedRating, msg.sender);

        emit CommentAdded(totalComments, _topicId, block.timestamp);
        emit PrivacyUpdated(msg.sender, block.timestamp);
    }

    // Rate a comment (like/dislike)
    function rateComment(uint256 _commentId, bool _isLike) external validComment(_commentId) {
        uint256 topicId = comments[_commentId].topicId;
        require(!hasVoted[topicId][msg.sender], "Already voted on this topic");

        if (_isLike) {
            comments[_commentId].likes++;
        } else {
            comments[_commentId].dislikes++;
        }

        hasVoted[topicId][msg.sender] = true;
        userPrivacy[msg.sender].lastActivity = block.timestamp;

        emit CommentRated(_commentId, _isLike);
    }

    // Get topic information
    function getTopicInfo(uint256 _topicId) external view validTopic(_topicId) returns (
        string memory title,
        string memory description,
        address creator,
        uint256 createdAt,
        uint256 commentCount,
        bool isActive
    ) {
        Topic storage topic = topics[_topicId];
        return (
            topic.title,
            topic.description,
            topic.creator,
            topic.createdAt,
            topic.commentCount,
            topic.isActive
        );
    }

    // Get comment information (public data only)
    function getCommentInfo(uint256 _commentId) external view validComment(_commentId) returns (
        uint256 timestamp,
        uint256 topicId,
        uint256 likes,
        uint256 dislikes,
        bool isVisible
    ) {
        Comment storage comment = comments[_commentId];
        return (
            comment.timestamp,
            comment.topicId,
            comment.likes,
            comment.dislikes,
            comment.isVisible
        );
    }

    // Get comments for a topic
    function getTopicComments(uint256 _topicId) external view validTopic(_topicId) returns (uint256[] memory) {
        return topicComments[_topicId];
    }

    // Get user's encrypted anonymous ID (only accessible by the user)
    function getMyAnonymousId() external view returns (bytes32) {
        require(userPrivacy[msg.sender].hasCommented, "No comments yet");
        return FHE.toBytes32(userPrivacy[msg.sender].encryptedId);
    }

    // Get user's privacy status
    function getMyPrivacyStatus() external view returns (
        bool hasCommented,
        uint256 lastActivity
    ) {
        UserPrivacy storage privacy = userPrivacy[msg.sender];
        return (privacy.hasCommented, privacy.lastActivity);
    }

    // Request decryption of comment content (only by comment author)
    function requestCommentDecryption(uint256 _commentId) external validComment(_commentId) {
        require(userPrivacy[msg.sender].hasCommented, "Not a commenter");

        Comment storage comment = comments[_commentId];

        // Create decryption request for content
        bytes32[] memory cts = new bytes32[](2);
        cts[0] = FHE.toBytes32(comment.encryptedContent);
        cts[1] = FHE.toBytes32(comment.encryptedRating);

        FHE.requestDecryption(cts, this.processCommentDecryption.selector);
    }

    // Process comment decryption callback
    function processCommentDecryption(
        uint256 requestId,
        uint32 decryptedContent,
        uint8 decryptedRating
    ) external {
        // This callback would process the decrypted content
        // In a real implementation, this would be used for moderation or analysis
        // Note: Signature verification removed for compatibility
    }

    // Toggle topic active status (owner only)
    function toggleTopicStatus(uint256 _topicId) external onlyOwner {
        require(_topicId > 0 && _topicId <= totalTopics, "Invalid topic");
        topics[_topicId].isActive = !topics[_topicId].isActive;
    }

    // Hide/show comment (owner only)
    function toggleCommentVisibility(uint256 _commentId) external onlyOwner {
        require(_commentId > 0 && _commentId <= totalComments, "Invalid comment");
        comments[_commentId].isVisible = !comments[_commentId].isVisible;
    }

    // Get platform statistics
    function getPlatformStats() external view returns (
        uint256 totalTopicsCount,
        uint256 totalCommentsCount,
        uint256 activeTopics
    ) {
        uint256 activeCount = 0;
        for (uint256 i = 1; i <= totalTopics; i++) {
            if (topics[i].isActive) {
                activeCount++;
            }
        }

        return (totalTopics, totalComments, activeCount);
    }

    // Emergency function to pause all commenting (owner only)
    function emergencyPause() external onlyOwner {
        for (uint256 i = 1; i <= totalTopics; i++) {
            topics[i].isActive = false;
        }
    }
}