// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Vandelay Token Airdrop
 * @dev Implementation of a token airdrop system for distributing tokens to multiple addresses
 * @author DeFi-Vandelay for Vandelay Technologies
 * @notice This contract allows for efficient distribution of tokens to a predefined list of addresses
 */

contract VandelayTokenAirdrop {
    // Structs
    struct Airdrop {
        uint256 id;
        address tokenAddress;
        uint256 totalAmount;
        uint256 amountPerRecipient;
        uint256 recipientCount;
        uint256 claimedCount;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        bool isCancelled;
        address creator;
    }

    // State variables
    uint256 private _airdropCounter;
    mapping(uint256 => Airdrop) private _airdrops;
    mapping(uint256 => mapping(address => bool)) private _hasClaimed;
    mapping(address => uint256[]) private _userAirdrops;
    
    // Events
    event AirdropCreated(uint256 indexed airdropId, address indexed tokenAddress, uint256 totalAmount, uint256 recipientCount);
    event AirdropCancelled(uint256 indexed airdropId);
    event TokensClaimed(uint256 indexed airdropId, address indexed recipient, uint256 amount);
    event AirdropCompleted(uint256 indexed airdropId);

    /**
     * @dev Creates a new airdrop
     * @param tokenAddress The address of the token to be airdropped
     * @param recipients The list of addresses to receive the airdrop
     * @param amountPerRecipient The amount of tokens each recipient will receive
     * @param startTime The timestamp when the airdrop starts
     * @param endTime The timestamp when the airdrop ends
     */
    function createAirdrop(
        address tokenAddress,
        address[] memory recipients,
        uint256 amountPerRecipient,
        uint256 startTime,
        uint256 endTime
    ) external {
        require(tokenAddress != address(0), "Invalid token address");
        require(recipients.length > 0, "Recipients list cannot be empty");
        require(amountPerRecipient > 0, "Amount per recipient must be greater than 0");
        require(startTime >= block.timestamp, "Start time must be in the future");
        require(endTime > startTime, "End time must be after start time");
        
        uint256 totalAmount = amountPerRecipient * recipients.length;
        
        // Transfer tokens from creator to this contract
        (bool success, ) = tokenAddress.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), totalAmount)
        );
        require(success, "Token transfer failed");
        
        uint256 airdropId = _airdropCounter++;
        
        _airdrops[airdropId] = Airdrop({
            id: airdropId,
            tokenAddress: tokenAddress,
            totalAmount: totalAmount,
            amountPerRecipient: amountPerRecipient,
            recipientCount: recipients.length,
            claimedCount: 0,
            startTime: startTime,
            endTime: endTime,
            isActive: true,
            isCancelled: false,
            creator: msg.sender
        });
        
        _userAirdrops[msg.sender].push(airdropId);
        
        emit AirdropCreated(airdropId, tokenAddress, totalAmount, recipients.length);
    }

    /**
     * @dev Claims tokens from an airdrop
     * @param airdropId The ID of the airdrop to claim from
     */
    function claimAirdrop(uint256 airdropId) external {
        Airdrop storage airdrop = _airdrops[airdropId];
        require(airdrop.isActive, "Airdrop is not active");
        require(!airdrop.isCancelled, "Airdrop is cancelled");
        require(block.timestamp >= airdrop.startTime, "Airdrop has not started yet");
        require(block.timestamp <= airdrop.endTime, "Airdrop has ended");
        require(!_hasClaimed[airdropId][msg.sender], "Already claimed");
        
        _hasClaimed[airdropId][msg.sender] = true;
        airdrop.claimedCount++;
        
        // Transfer tokens to recipient
        (bool success, ) = airdrop.tokenAddress.call(
            abi.encodeWithSignature("transfer(address,uint256)", msg.sender, airdrop.amountPerRecipient)
        );
        require(success, "Token transfer failed");
        
        emit TokensClaimed(airdropId, msg.sender, airdrop.amountPerRecipient);
        
        // Check if airdrop is completed
        if (airdrop.claimedCount == airdrop.recipientCount) {
            airdrop.isActive = false;
            emit AirdropCompleted(airdropId);
        }
    }

    /**
     * @dev Cancels an airdrop and refunds the creator
     * @param airdropId The ID of the airdrop to cancel
     */
    function cancelAirdrop(uint256 airdropId) external {
        Airdrop storage airdrop = _airdrops[airdropId];
        require(airdrop.creator == msg.sender, "Only creator can cancel airdrop");
        require(airdrop.isActive, "Airdrop is not active");
        require(!airdrop.isCancelled, "Airdrop is already cancelled");
        require(block.timestamp < airdrop.startTime, "Cannot cancel started airdrop");
        
        airdrop.isActive = false;
        airdrop.isCancelled = true;
        
        // Calculate remaining amount
        uint256 remainingAmount = airdrop.totalAmount - (airdrop.claimedCount * airdrop.amountPerRecipient);
        
        // Refund remaining tokens to creator
        if (remainingAmount > 0) {
            (bool success, ) = airdrop.tokenAddress.call(
                abi.encodeWithSignature("transfer(address,uint256)", msg.sender, remainingAmount)
            );
            require(success, "Token transfer failed");
        }
        
        emit AirdropCancelled(airdropId);
    }

    /**
     * @dev Returns the details of an airdrop
     * @param airdropId The ID of the airdrop to query
     * @return tokenAddress The address of the token
     * @return totalAmount The total amount of tokens for the airdrop
     * @return amountPerRecipient The amount of tokens each recipient receives
     * @return recipientCount The number of recipients
     * @return claimedCount The number of recipients who have claimed
     * @return startTime The timestamp when the airdrop starts
     * @return endTime The timestamp when the airdrop ends
     * @return isActive Whether the airdrop is active
     * @return isCancelled Whether the airdrop is cancelled
     * @return creator The address of the creator
     */
    function getAirdrop(uint256 airdropId) external view returns (
        address tokenAddress,
        uint256 totalAmount,
        uint256 amountPerRecipient,
        uint256 recipientCount,
        uint256 claimedCount,
        uint256 startTime,
        uint256 endTime,
        bool isActive,
        bool isCancelled,
        address creator
    ) {
        Airdrop storage airdrop = _airdrops[airdropId];
        return (
            airdrop.tokenAddress,
            airdrop.totalAmount,
            airdrop.amountPerRecipient,
            airdrop.recipientCount,
            airdrop.claimedCount,
            airdrop.startTime,
            airdrop.endTime,
            airdrop.isActive,
            airdrop.isCancelled,
            airdrop.creator
        );
    }

    /**
     * @dev Returns whether an address has claimed from an airdrop
     * @param airdropId The ID of the airdrop
     * @param recipient The address to check
     * @return Whether the address has claimed
     */
    function hasClaimed(uint256 airdropId, address recipient) external view returns (bool) {
        return _hasClaimed[airdropId][recipient];
    }

    /**
     * @dev Returns the IDs of all airdrops created by a user
     * @param user The address of the user
     * @return An array of airdrop IDs
     */
    function getUserAirdrops(address user) external view returns (uint256[] memory) {
        return _userAirdrops[user];
    }

    /**
     * @dev Returns the total number of airdrops
     * @return The total number of airdrops
     */
    function getAirdropCount() external view returns (uint256) {
        return _airdropCounter;
    }

    /**
     * @dev Allows the contract to receive tokens
     */
    function onERC20Received(address, address, uint256, bytes memory) external pure returns (bytes4) {
        return bytes4(keccak256("onERC20Received(address,address,uint256,bytes)"));
    }
} 