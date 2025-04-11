// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Vandelay Bounties and Rewards
 * @dev Implementation of a decentralized bounties and rewards system
 * @author DeFi-Vandelay for Vandelay Technologies
 * @notice This contract allows users to create bounties, claim them, and receive rewards upon completion
 */

contract VandelayBountiesAndRewards {
    // Structs
    struct Bounty {
        address creator;
        string title;
        string description;
        uint256 reward;
        uint256 deadline;
        address claimer;
        bool isActive;
        bool isCompleted;
        bool isCancelled;
        uint256 createdAt;
    }

    // State variables
    uint256 private _bountyCounter;
    mapping(uint256 => Bounty) private _bounties;
    mapping(address => uint256[]) private _userBounties;
    mapping(address => uint256[]) private _userClaims;
    
    // Events
    event BountyCreated(uint256 indexed bountyId, address indexed creator, string title, uint256 reward, uint256 deadline);
    event BountyClaimed(uint256 indexed bountyId, address indexed claimer);
    event BountyCompleted(uint256 indexed bountyId, address indexed claimer);
    event BountyCancelled(uint256 indexed bountyId, address indexed creator);
    event RewardPaid(uint256 indexed bountyId, address indexed claimer, uint256 amount);

    /**
     * @dev Creates a new bounty
     * @param title The title of the bounty
     * @param description The description of the bounty
     * @param deadline The deadline for completing the bounty (in seconds from now)
     */
    function createBounty(string memory title, string memory description, uint256 deadline) external payable {
        require(msg.value > 0, "Reward must be greater than 0");
        require(deadline > block.timestamp, "Deadline must be in the future");
        
        uint256 bountyId = _bountyCounter++;
        
        _bounties[bountyId] = Bounty({
            creator: msg.sender,
            title: title,
            description: description,
            reward: msg.value,
            deadline: deadline,
            claimer: address(0),
            isActive: true,
            isCompleted: false,
            isCancelled: false,
            createdAt: block.timestamp
        });
        
        _userBounties[msg.sender].push(bountyId);
        
        emit BountyCreated(bountyId, msg.sender, title, msg.value, deadline);
    }

    /**
     * @dev Claims a bounty
     * @param bountyId The ID of the bounty to claim
     */
    function claimBounty(uint256 bountyId) external {
        Bounty storage bounty = _bounties[bountyId];
        require(bounty.isActive, "Bounty is not active");
        require(bounty.claimer == address(0), "Bounty already claimed");
        require(block.timestamp <= bounty.deadline, "Bounty deadline has passed");
        require(msg.sender != bounty.creator, "Creator cannot claim their own bounty");
        
        bounty.claimer = msg.sender;
        _userClaims[msg.sender].push(bountyId);
        
        emit BountyClaimed(bountyId, msg.sender);
    }

    /**
     * @dev Marks a bounty as completed and pays the reward
     * @param bountyId The ID of the bounty to complete
     */
    function completeBounty(uint256 bountyId) external {
        Bounty storage bounty = _bounties[bountyId];
        require(bounty.isActive, "Bounty is not active");
        require(bounty.claimer == msg.sender, "Only claimer can complete the bounty");
        require(!bounty.isCompleted, "Bounty already completed");
        require(block.timestamp <= bounty.deadline, "Bounty deadline has passed");
        
        bounty.isActive = false;
        bounty.isCompleted = true;
        
        uint256 reward = bounty.reward;
        bounty.reward = 0;
        
        (bool success, ) = msg.sender.call{value: reward}("");
        require(success, "Transfer failed");
        
        emit BountyCompleted(bountyId, msg.sender);
        emit RewardPaid(bountyId, msg.sender, reward);
    }

    /**
     * @dev Cancels a bounty and refunds the creator
     * @param bountyId The ID of the bounty to cancel
     */
    function cancelBounty(uint256 bountyId) external {
        Bounty storage bounty = _bounties[bountyId];
        require(bounty.creator == msg.sender, "Only creator can cancel the bounty");
        require(bounty.isActive, "Bounty is not active");
        require(!bounty.isCompleted, "Bounty already completed");
        require(bounty.claimer == address(0), "Cannot cancel claimed bounty");
        
        bounty.isActive = false;
        bounty.isCancelled = true;
        
        uint256 refund = bounty.reward;
        bounty.reward = 0;
        
        (bool success, ) = msg.sender.call{value: refund}("");
        require(success, "Transfer failed");
        
        emit BountyCancelled(bountyId, msg.sender);
    }

    /**
     * @dev Returns the details of a bounty
     * @param bountyId The ID of the bounty to query
     * @return creator The address of the bounty creator
     * @return title The title of the bounty
     * @return description The description of the bounty
     * @return reward The reward amount
     * @return deadline The deadline for completing the bounty
     * @return claimer The address of the claimer
     * @return isActive Whether the bounty is active
     * @return isCompleted Whether the bounty is completed
     * @return isCancelled Whether the bounty is cancelled
     * @return createdAt The timestamp when the bounty was created
     */
    function getBounty(uint256 bountyId) external view returns (
        address creator,
        string memory title,
        string memory description,
        uint256 reward,
        uint256 deadline,
        address claimer,
        bool isActive,
        bool isCompleted,
        bool isCancelled,
        uint256 createdAt
    ) {
        Bounty storage bounty = _bounties[bountyId];
        return (
            bounty.creator,
            bounty.title,
            bounty.description,
            bounty.reward,
            bounty.deadline,
            bounty.claimer,
            bounty.isActive,
            bounty.isCompleted,
            bounty.isCancelled,
            bounty.createdAt
        );
    }

    /**
     * @dev Returns the IDs of all bounties created by a user
     * @param user The address of the user
     * @return An array of bounty IDs
     */
    function getUserBounties(address user) external view returns (uint256[] memory) {
        return _userBounties[user];
    }

    /**
     * @dev Returns the IDs of all bounties claimed by a user
     * @param user The address of the user
     * @return An array of bounty IDs
     */
    function getUserClaims(address user) external view returns (uint256[] memory) {
        return _userClaims[user];
    }

    /**
     * @dev Returns the total number of bounties
     * @return The total number of bounties
     */
    function getBountyCount() external view returns (uint256) {
        return _bountyCounter;
    }

    /**
     * @dev Allows the contract to receive ETH
     */
    receive() external payable {}
} 