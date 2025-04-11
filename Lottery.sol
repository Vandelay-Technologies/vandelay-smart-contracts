// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Vandelay Lottery
 * @dev Implementation of a decentralized lottery system
 * @author DeFi-Vandelay for Vandelay Technologies
 * @notice This contract implements a lottery system with ticket purchases and random winner selection
 */

contract VandelayLottery {
    // Lottery structure to store lottery details
    struct Lottery {
        uint256 ticketPrice;              // Price per ticket in wei
        uint256 startTime;                // Time when the lottery starts
        uint256 endTime;                  // Time when the lottery ends
        uint256 prizePool;                // Total prize pool in wei
        uint256 ticketCount;              // Total number of tickets sold
        address[] participants;            // Array of participant addresses
        address winner;                    // Address of the winner
        bool ended;                        // Flag to indicate if the lottery has ended
        bool active;                       // Flag to indicate if the lottery is active
        uint256 ownerFeePercentage;        // Percentage of prize pool that goes to the owner
    }

    // Mapping from lottery ID to Lottery struct
    mapping(uint256 => Lottery) public lotteries;
    
    // Counter for lottery IDs
    uint256 private _lotteryCounter;
    
    // Owner of the contract
    address payable public owner;
    
    // Events
    event LotteryCreated(uint256 indexed lotteryId, uint256 ticketPrice, uint256 startTime, uint256 endTime);
    event TicketPurchased(uint256 indexed lotteryId, address indexed buyer, uint256 ticketCount);
    event LotteryEnded(uint256 indexed lotteryId, address indexed winner, uint256 prizeAmount);
    event PrizeClaimed(uint256 indexed lotteryId, address indexed winner, uint256 prizeAmount);
    event OwnerFeeCollected(uint256 indexed lotteryId, address indexed owner, uint256 feeAmount);

    /**
     * @dev Constructor sets the owner of the contract
     */
    constructor() {
        owner = payable(msg.sender);
    }

    /**
     * @dev Modifier to restrict function access to the owner
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    /**
     * @dev Creates a new lottery
     * @param _ticketPrice The price per ticket in wei
     * @param _startTime The time when the lottery starts
     * @param _endTime The time when the lottery ends
     * @param _ownerFeePercentage The percentage of prize pool that goes to the owner (0-100)
     * @return lotteryId The ID of the created lottery
     */
    function createLottery(
        uint256 _ticketPrice,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _ownerFeePercentage
    ) external onlyOwner returns (uint256) {
        require(_ticketPrice > 0, "Ticket price must be greater than 0");
        require(_startTime >= block.timestamp, "Start time must be in the future");
        require(_endTime > _startTime, "End time must be after start time");
        require(_ownerFeePercentage <= 100, "Owner fee percentage cannot exceed 100");
        
        uint256 lotteryId = _lotteryCounter++;
        
        lotteries[lotteryId] = Lottery({
            ticketPrice: _ticketPrice,
            startTime: _startTime,
            endTime: _endTime,
            prizePool: 0,
            ticketCount: 0,
            participants: new address[](0),
            winner: address(0),
            ended: false,
            active: true,
            ownerFeePercentage: _ownerFeePercentage
        });
        
        emit LotteryCreated(lotteryId, _ticketPrice, _startTime, _endTime);
        
        return lotteryId;
    }

    /**
     * @dev Purchases tickets for a lottery
     * @param _lotteryId The ID of the lottery to buy tickets for
     * @param _ticketCount The number of tickets to buy
     */
    function buyTickets(uint256 _lotteryId, uint256 _ticketCount) external payable {
        Lottery storage lottery = lotteries[_lotteryId];
        require(lottery.active, "Lottery is not active");
        require(block.timestamp >= lottery.startTime, "Lottery has not started yet");
        require(block.timestamp <= lottery.endTime, "Lottery has ended");
        require(_ticketCount > 0, "Must buy at least one ticket");
        
        uint256 totalCost = lottery.ticketPrice * _ticketCount;
        require(msg.value >= totalCost, "Insufficient payment for tickets");
        
        // Add the buyer to the participants list for each ticket
        for (uint256 i = 0; i < _ticketCount; i++) {
            lottery.participants.push(msg.sender);
        }
        
        // Update lottery state
        lottery.ticketCount += _ticketCount;
        lottery.prizePool += totalCost;
        
        // Refund any excess payment
        if (msg.value > totalCost) {
            (bool success, ) = msg.sender.call{value: msg.value - totalCost}("");
            require(success, "Refund failed");
        }
        
        emit TicketPurchased(_lotteryId, msg.sender, _ticketCount);
    }

    /**
     * @dev Ends a lottery and selects a winner
     * @param _lotteryId The ID of the lottery to end
     */
    function endLottery(uint256 _lotteryId) external {
        Lottery storage lottery = lotteries[_lotteryId];
        require(lottery.active, "Lottery is not active");
        require(block.timestamp > lottery.endTime, "Lottery has not ended yet");
        require(!lottery.ended, "Lottery already ended");
        require(lottery.ticketCount > 0, "No tickets sold");
        
        lottery.ended = true;
        lottery.active = false;
        
        // Select a random winner
        uint256 randomIndex = _generateRandomNumber(lottery.ticketCount);
        lottery.winner = lottery.participants[randomIndex];
        
        emit LotteryEnded(_lotteryId, lottery.winner, lottery.prizePool);
    }

    /**
     * @dev Claims the prize for a lottery
     * @param _lotteryId The ID of the lottery to claim the prize for
     */
    function claimPrize(uint256 _lotteryId) external {
        Lottery storage lottery = lotteries[_lotteryId];
        require(lottery.ended, "Lottery has not ended yet");
        require(msg.sender == lottery.winner, "Only winner can claim prize");
        require(lottery.prizePool > 0, "Prize already claimed");
        
        uint256 prizeAmount = lottery.prizePool;
        uint256 ownerFee = (prizeAmount * lottery.ownerFeePercentage) / 100;
        uint256 winnerPrize = prizeAmount - ownerFee;
        
        // Reset prize pool to prevent double claiming
        lottery.prizePool = 0;
        
        // Transfer prize to winner
        if (winnerPrize > 0) {
            (bool success, ) = lottery.winner.call{value: winnerPrize}("");
            require(success, "Prize transfer failed");
            emit PrizeClaimed(_lotteryId, lottery.winner, winnerPrize);
        }
        
        // Transfer owner fee
        if (ownerFee > 0) {
            (bool success, ) = owner.call{value: ownerFee}("");
            require(success, "Owner fee transfer failed");
            emit OwnerFeeCollected(_lotteryId, owner, ownerFee);
        }
    }

    /**
     * @dev Generates a pseudo-random number
     * @param _max The maximum value for the random number
     * @return A random number between 0 and _max-1
     */
    function _generateRandomNumber(uint256 _max) internal view returns (uint256) {
        // This is a simple implementation and not cryptographically secure
        // For production use, consider using a more secure randomness source
        return uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.difficulty,
            blockhash(block.number - 1),
            _max
        ))) % _max;
    }

    /**
     * @dev Returns the details of a lottery
     * @param _lotteryId The ID of the lottery to query
     * @return ticketPrice The price per ticket in wei
     * @return startTime The time when the lottery starts
     * @return endTime The time when the lottery ends
     * @return prizePool The total prize pool in wei
     * @return ticketCount The total number of tickets sold
     * @return winner The address of the winner
     * @return ended Whether the lottery has ended
     * @return active Whether the lottery is active
     * @return ownerFeePercentage The percentage of prize pool that goes to the owner
     */
    function getLotteryDetails(uint256 _lotteryId) external view returns (
        uint256 ticketPrice,
        uint256 startTime,
        uint256 endTime,
        uint256 prizePool,
        uint256 ticketCount,
        address winner,
        bool ended,
        bool active,
        uint256 ownerFeePercentage
    ) {
        Lottery storage lottery = lotteries[_lotteryId];
        return (
            lottery.ticketPrice,
            lottery.startTime,
            lottery.endTime,
            lottery.prizePool,
            lottery.ticketCount,
            lottery.winner,
            lottery.ended,
            lottery.active,
            lottery.ownerFeePercentage
        );
    }

    /**
     * @dev Returns the number of tickets purchased by an address
     * @param _lotteryId The ID of the lottery to query
     * @param _participant The address of the participant
     * @return The number of tickets purchased by the participant
     */
    function getParticipantTicketCount(uint256 _lotteryId, address _participant) external view returns (uint256) {
        Lottery storage lottery = lotteries[_lotteryId];
        uint256 count = 0;
        
        for (uint256 i = 0; i < lottery.participants.length; i++) {
            if (lottery.participants[i] == _participant) {
                count++;
            }
        }
        
        return count;
    }

    /**
     * @dev Returns the total number of lotteries created
     * @return The total number of lotteries
     */
    function getLotteryCount() external view returns (uint256) {
        return _lotteryCounter;
    }

    /**
     * @dev Allows the owner to withdraw any ETH sent to the contract
     */
    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        (bool success, ) = owner.call{value: balance}("");
        require(success, "Withdrawal failed");
    }
} 