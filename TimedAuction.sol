// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Vandelay Timed Auction
 * @dev Implementation of a timed auction system for blockchain assets
 * @author DeFi-Vandelay for Vandelay Technologies
 * @notice This contract implements a timed auction system with bid management and asset transfer
 */

contract VandelayTimedAuction {
    // Auction structure to store auction details
    struct Auction {
        address payable seller;           // Address of the seller
        address payable highestBidder;    // Address of the highest bidder
        uint256 highestBid;               // Amount of the highest bid
        uint256 startTime;                // Time when the auction starts
        uint256 endTime;                  // Time when the auction ends
        bool ended;                       // Flag to indicate if the auction has ended
        bool active;                      // Flag to indicate if the auction is active
    }

    // Mapping from auction ID to Auction struct
    mapping(uint256 => Auction) public auctions;
    
    // Counter for auction IDs
    uint256 private _auctionCounter;
    
    // Events
    event AuctionCreated(uint256 indexed auctionId, address indexed seller, uint256 startTime, uint256 endTime);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed auctionId, address indexed winner, uint256 amount);
    event BidWithdrawn(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionCancelled(uint256 indexed auctionId, address indexed seller);

    /**
     * @dev Creates a new auction
     * @param _startTime The time when the auction starts
     * @param _endTime The time when the auction ends
     * @return auctionId The ID of the created auction
     */
    function createAuction(uint256 _startTime, uint256 _endTime) external returns (uint256) {
        require(_startTime >= block.timestamp, "Start time must be in the future");
        require(_endTime > _startTime, "End time must be after start time");
        
        uint256 auctionId = _auctionCounter++;
        
        auctions[auctionId] = Auction({
            seller: payable(msg.sender),
            highestBidder: payable(address(0)),
            highestBid: 0,
            startTime: _startTime,
            endTime: _endTime,
            ended: false,
            active: true
        });
        
        emit AuctionCreated(auctionId, msg.sender, _startTime, _endTime);
        
        return auctionId;
    }

    /**
     * @dev Places a bid on an auction
     * @param _auctionId The ID of the auction to bid on
     */
    function placeBid(uint256 _auctionId) external payable {
        Auction storage auction = auctions[_auctionId];
        require(auction.active, "Auction is not active");
        require(block.timestamp >= auction.startTime, "Auction has not started yet");
        require(block.timestamp <= auction.endTime, "Auction has ended");
        require(msg.value > auction.highestBid, "Bid must be higher than current highest bid");
        
        // Refund the previous highest bidder if there is one
        if (auction.highestBidder != address(0)) {
            // Store the previous bidder's address before updating
            address payable previousBidder = auction.highestBidder;
            uint256 previousBid = auction.highestBid;
            
            // Update the auction with the new highest bid
            auction.highestBidder = payable(msg.sender);
            auction.highestBid = msg.value;
            
            // Refund the previous bidder
            (bool success, ) = previousBidder.call{value: previousBid}("");
            require(success, "Refund failed");
            
            emit BidWithdrawn(_auctionId, previousBidder, previousBid);
        } else {
            // First bid on the auction
            auction.highestBidder = payable(msg.sender);
            auction.highestBid = msg.value;
        }
        
        emit BidPlaced(_auctionId, msg.sender, msg.value);
    }

    /**
     * @dev Ends an auction and transfers the funds to the seller
     * @param _auctionId The ID of the auction to end
     */
    function endAuction(uint256 _auctionId) external {
        Auction storage auction = auctions[_auctionId];
        require(auction.active, "Auction is not active");
        require(block.timestamp > auction.endTime, "Auction has not ended yet");
        require(!auction.ended, "Auction already ended");
        
        auction.ended = true;
        auction.active = false;
        
        // Transfer the highest bid to the seller
        if (auction.highestBidder != address(0)) {
            (bool success, ) = auction.seller.call{value: auction.highestBid}("");
            require(success, "Transfer to seller failed");
            
            emit AuctionEnded(_auctionId, auction.highestBidder, auction.highestBid);
        } else {
            emit AuctionEnded(_auctionId, address(0), 0);
        }
    }

    /**
     * @dev Cancels an auction before it has started
     * @param _auctionId The ID of the auction to cancel
     */
    function cancelAuction(uint256 _auctionId) external {
        Auction storage auction = auctions[_auctionId];
        require(msg.sender == auction.seller, "Only seller can cancel auction");
        require(auction.active, "Auction is not active");
        require(block.timestamp < auction.startTime, "Auction has already started");
        
        auction.active = false;
        
        emit AuctionCancelled(_auctionId, msg.sender);
    }

    /**
     * @dev Returns the details of an auction
     * @param _auctionId The ID of the auction to query
     * @return seller The address of the seller
     * @return highestBidder The address of the highest bidder
     * @return highestBid The amount of the highest bid
     * @return startTime The time when the auction starts
     * @return endTime The time when the auction ends
     * @return ended Whether the auction has ended
     * @return active Whether the auction is active
     */
    function getAuctionDetails(uint256 _auctionId) external view returns (
        address seller,
        address highestBidder,
        uint256 highestBid,
        uint256 startTime,
        uint256 endTime,
        bool ended,
        bool active
    ) {
        Auction storage auction = auctions[_auctionId];
        return (
            auction.seller,
            auction.highestBidder,
            auction.highestBid,
            auction.startTime,
            auction.endTime,
            auction.ended,
            auction.active
        );
    }

    /**
     * @dev Returns the current highest bid for an auction
     * @param _auctionId The ID of the auction to query
     * @return The amount of the highest bid
     */
    function getHighestBid(uint256 _auctionId) external view returns (uint256) {
        return auctions[_auctionId].highestBid;
    }

    /**
     * @dev Returns the time remaining in an auction
     * @param _auctionId The ID of the auction to query
     * @return The time remaining in seconds, or 0 if the auction has ended
     */
    function getTimeRemaining(uint256 _auctionId) external view returns (uint256) {
        Auction storage auction = auctions[_auctionId];
        if (block.timestamp >= auction.endTime) {
            return 0;
        }
        return auction.endTime - block.timestamp;
    }

    /**
     * @dev Returns the total number of auctions created
     * @return The total number of auctions
     */
    function getAuctionCount() external view returns (uint256) {
        return _auctionCounter;
    }
} 