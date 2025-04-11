// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Vandelay Decentralized Marketplace
 * @dev Implementation of a decentralized marketplace for listing, purchasing, and managing items
 * @author DeFi-Vandelay for Vandelay Technologies
 * @notice This contract allows users to list items for sale, purchase them, and resolve disputes
 */

contract VandelayDecentralizedMarketplace {
    // Enums
    enum ListingStatus { Active, Sold, Cancelled, Disputed, Resolved }
    enum DisputeStatus { None, Open, Resolved, Cancelled }
    enum DisputeResolution { None, RefundBuyer, ReleaseToSeller, SplitPayment }

    // Structs
    struct Listing {
        uint256 id;
        address seller;
        string title;
        string description;
        uint256 price;
        uint256 quantity;
        uint256 availableQuantity;
        uint256 createdAt;
        uint256 updatedAt;
        ListingStatus status;
        bool isEscrowEnabled;
    }

    struct Order {
        uint256 id;
        uint256 listingId;
        address buyer;
        uint256 quantity;
        uint256 totalPrice;
        uint256 createdAt;
        bool isPaid;
        bool isDelivered;
        bool isConfirmed;
        bool isDisputed;
    }

    struct Dispute {
        uint256 id;
        uint256 orderId;
        address buyer;
        address seller;
        string reason;
        uint256 createdAt;
        DisputeStatus status;
        DisputeResolution resolution;
        address resolver;
    }

    // State variables
    uint256 private _listingCounter;
    uint256 private _orderCounter;
    uint256 private _disputeCounter;
    uint256 private _platformFeePercentage;
    address private _platformFeeRecipient;
    uint256 private _escrowDuration;
    uint256 private _disputeResolutionTime;
    
    mapping(uint256 => Listing) private _listings;
    mapping(uint256 => Order) private _orders;
    mapping(uint256 => Dispute) private _disputes;
    mapping(address => uint256[]) private _userListings;
    mapping(address => uint256[]) private _userOrders;
    mapping(address => uint256[]) private _userDisputes;
    mapping(uint256 => uint256) private _orderToDispute;
    
    // Events
    event ListingCreated(uint256 indexed listingId, address indexed seller, string title, uint256 price, uint256 quantity);
    event ListingUpdated(uint256 indexed listingId, uint256 price, uint256 quantity);
    event ListingCancelled(uint256 indexed listingId);
    event OrderCreated(uint256 indexed orderId, uint256 indexed listingId, address indexed buyer, uint256 quantity, uint256 totalPrice);
    event OrderPaid(uint256 indexed orderId, uint256 amount);
    event OrderDelivered(uint256 indexed orderId);
    event OrderConfirmed(uint256 indexed orderId);
    event DisputeCreated(uint256 indexed disputeId, uint256 indexed orderId, string reason);
    event DisputeResolved(uint256 indexed disputeId, DisputeResolution resolution);
    event PlatformFeeUpdated(uint256 oldPercentage, uint256 newPercentage);
    event EscrowDurationUpdated(uint256 oldDuration, uint256 newDuration);
    event DisputeResolutionTimeUpdated(uint256 oldTime, uint256 newTime);

    /**
     * @dev Constructor initializes the marketplace contract
     * @param platformFeePercentage_ The percentage of the sale price taken as platform fee
     * @param platformFeeRecipient_ The address that receives platform fees
     * @param escrowDuration_ The duration in seconds that funds are held in escrow
     * @param disputeResolutionTime_ The time in seconds allowed for dispute resolution
     */
    constructor(
        uint256 platformFeePercentage_,
        address platformFeeRecipient_,
        uint256 escrowDuration_,
        uint256 disputeResolutionTime_
    ) {
        require(platformFeePercentage_ <= 100, "Platform fee percentage cannot exceed 100");
        require(platformFeeRecipient_ != address(0), "Invalid platform fee recipient address");
        require(escrowDuration_ > 0, "Escrow duration must be greater than 0");
        require(disputeResolutionTime_ > 0, "Dispute resolution time must be greater than 0");
        
        _platformFeePercentage = platformFeePercentage_;
        _platformFeeRecipient = platformFeeRecipient_;
        _escrowDuration = escrowDuration_;
        _disputeResolutionTime = disputeResolutionTime_;
    }

    /**
     * @dev Creates a new listing
     * @param title The title of the listing
     * @param description The description of the listing
     * @param price The price per item in wei
     * @param quantity The quantity of items available
     * @param isEscrowEnabled Whether to use escrow for this listing
     */
    function createListing(
        string memory title,
        string memory description,
        uint256 price,
        uint256 quantity,
        bool isEscrowEnabled
    ) external {
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(price > 0, "Price must be greater than 0");
        require(quantity > 0, "Quantity must be greater than 0");
        
        uint256 listingId = _listingCounter++;
        
        _listings[listingId] = Listing({
            id: listingId,
            seller: msg.sender,
            title: title,
            description: description,
            price: price,
            quantity: quantity,
            availableQuantity: quantity,
            createdAt: block.timestamp,
            updatedAt: block.timestamp,
            status: ListingStatus.Active,
            isEscrowEnabled: isEscrowEnabled
        });
        
        _userListings[msg.sender].push(listingId);
        
        emit ListingCreated(listingId, msg.sender, title, price, quantity);
    }

    /**
     * @dev Updates an existing listing
     * @param listingId The ID of the listing to update
     * @param price The new price per item in wei
     * @param quantity The new quantity of items available
     */
    function updateListing(uint256 listingId, uint256 price, uint256 quantity) external {
        Listing storage listing = _listings[listingId];
        require(listing.seller == msg.sender, "Only seller can update listing");
        require(listing.status == ListingStatus.Active, "Listing is not active");
        require(price > 0, "Price must be greater than 0");
        require(quantity >= listing.quantity - listing.availableQuantity, "Quantity cannot be less than sold items");
        
        listing.price = price;
        listing.quantity = quantity;
        listing.availableQuantity = quantity - (listing.quantity - listing.availableQuantity);
        listing.updatedAt = block.timestamp;
        
        emit ListingUpdated(listingId, price, quantity);
    }

    /**
     * @dev Cancels a listing
     * @param listingId The ID of the listing to cancel
     */
    function cancelListing(uint256 listingId) external {
        Listing storage listing = _listings[listingId];
        require(listing.seller == msg.sender, "Only seller can cancel listing");
        require(listing.status == ListingStatus.Active, "Listing is not active");
        
        listing.status = ListingStatus.Cancelled;
        listing.updatedAt = block.timestamp;
        
        emit ListingCancelled(listingId);
    }

    /**
     * @dev Creates an order for a listing
     * @param listingId The ID of the listing to order from
     * @param quantity The quantity of items to order
     */
    function createOrder(uint256 listingId, uint256 quantity) external payable {
        Listing storage listing = _listings[listingId];
        require(listing.status == ListingStatus.Active, "Listing is not active");
        require(listing.availableQuantity >= quantity, "Insufficient quantity available");
        require(msg.value == listing.price * quantity, "Incorrect payment amount");
        
        uint256 orderId = _orderCounter++;
        uint256 totalPrice = listing.price * quantity;
        
        _orders[orderId] = Order({
            id: orderId,
            listingId: listingId,
            buyer: msg.sender,
            quantity: quantity,
            totalPrice: totalPrice,
            createdAt: block.timestamp,
            isPaid: true,
            isDelivered: false,
            isConfirmed: false,
            isDisputed: false
        });
        
        listing.availableQuantity -= quantity;
        if (listing.availableQuantity == 0) {
            listing.status = ListingStatus.Sold;
        }
        
        _userOrders[msg.sender].push(orderId);
        
        emit OrderCreated(orderId, listingId, msg.sender, quantity, totalPrice);
        emit OrderPaid(orderId, msg.value);
    }

    /**
     * @dev Marks an order as delivered
     * @param orderId The ID of the order to mark as delivered
     */
    function markOrderAsDelivered(uint256 orderId) external {
        Order storage order = _orders[orderId];
        Listing storage listing = _listings[order.listingId];
        require(listing.seller == msg.sender, "Only seller can mark order as delivered");
        require(order.isPaid, "Order is not paid");
        require(!order.isDelivered, "Order is already delivered");
        require(!order.isDisputed, "Order is disputed");
        
        order.isDelivered = true;
        
        // If escrow is not enabled, release payment to seller
        if (!listing.isEscrowEnabled) {
            _releasePaymentToSeller(order);
        }
        
        emit OrderDelivered(orderId);
    }

    /**
     * @dev Confirms receipt of an order
     * @param orderId The ID of the order to confirm
     */
    function confirmOrder(uint256 orderId) external {
        Order storage order = _orders[orderId];
        require(order.buyer == msg.sender, "Only buyer can confirm order");
        require(order.isPaid, "Order is not paid");
        require(order.isDelivered, "Order is not delivered");
        require(!order.isConfirmed, "Order is already confirmed");
        require(!order.isDisputed, "Order is disputed");
        
        order.isConfirmed = true;
        
        // If escrow is enabled, release payment to seller after confirmation
        if (_listings[order.listingId].isEscrowEnabled) {
            _releasePaymentToSeller(order);
        }
        
        emit OrderConfirmed(orderId);
    }

    /**
     * @dev Creates a dispute for an order
     * @param orderId The ID of the order to dispute
     * @param reason The reason for the dispute
     */
    function createDispute(uint256 orderId, string memory reason) external {
        Order storage order = _orders[orderId];
        Listing storage listing = _listings[order.listingId];
        require(order.buyer == msg.sender || listing.seller == msg.sender, "Only buyer or seller can create dispute");
        require(order.isPaid, "Order is not paid");
        require(!order.isConfirmed, "Order is already confirmed");
        require(!order.isDisputed, "Order is already disputed");
        require(bytes(reason).length > 0, "Reason cannot be empty");
        
        uint256 disputeId = _disputeCounter++;
        
        _disputes[disputeId] = Dispute({
            id: disputeId,
            orderId: orderId,
            buyer: order.buyer,
            seller: listing.seller,
            reason: reason,
            createdAt: block.timestamp,
            status: DisputeStatus.Open,
            resolution: DisputeResolution.None,
            resolver: address(0)
        });
        
        order.isDisputed = true;
        _orderToDispute[orderId] = disputeId;
        
        _userDisputes[msg.sender].push(disputeId);
        
        emit DisputeCreated(disputeId, orderId, reason);
    }

    /**
     * @dev Resolves a dispute
     * @param disputeId The ID of the dispute to resolve
     * @param resolution The resolution to apply
     */
    function resolveDispute(uint256 disputeId, DisputeResolution resolution) external {
        Dispute storage dispute = _disputes[disputeId];
        Order storage order = _orders[dispute.orderId];
        require(dispute.status == DisputeStatus.Open, "Dispute is not open");
        require(block.timestamp <= dispute.createdAt + _disputeResolutionTime, "Dispute resolution time has passed");
        require(resolution != DisputeResolution.None, "Invalid resolution");
        
        dispute.status = DisputeStatus.Resolved;
        dispute.resolution = resolution;
        dispute.resolver = msg.sender;
        
        if (resolution == DisputeResolution.RefundBuyer) {
            _refundBuyer(order);
        } else if (resolution == DisputeResolution.ReleaseToSeller) {
            _releasePaymentToSeller(order);
        } else if (resolution == DisputeResolution.SplitPayment) {
            _splitPayment(order);
        }
        
        emit DisputeResolved(disputeId, resolution);
    }

    /**
     * @dev Updates the platform fee percentage
     * @param newPlatformFeePercentage The new platform fee percentage
     */
    function updatePlatformFeePercentage(uint256 newPlatformFeePercentage) external {
        require(newPlatformFeePercentage <= 100, "Platform fee percentage cannot exceed 100");
        uint256 oldPlatformFeePercentage = _platformFeePercentage;
        _platformFeePercentage = newPlatformFeePercentage;
        emit PlatformFeeUpdated(oldPlatformFeePercentage, newPlatformFeePercentage);
    }

    /**
     * @dev Updates the escrow duration
     * @param newEscrowDuration The new escrow duration in seconds
     */
    function updateEscrowDuration(uint256 newEscrowDuration) external {
        require(newEscrowDuration > 0, "Escrow duration must be greater than 0");
        uint256 oldEscrowDuration = _escrowDuration;
        _escrowDuration = newEscrowDuration;
        emit EscrowDurationUpdated(oldEscrowDuration, newEscrowDuration);
    }

    /**
     * @dev Updates the dispute resolution time
     * @param newDisputeResolutionTime The new dispute resolution time in seconds
     */
    function updateDisputeResolutionTime(uint256 newDisputeResolutionTime) external {
        require(newDisputeResolutionTime > 0, "Dispute resolution time must be greater than 0");
        uint256 oldDisputeResolutionTime = _disputeResolutionTime;
        _disputeResolutionTime = newDisputeResolutionTime;
        emit DisputeResolutionTimeUpdated(oldDisputeResolutionTime, newDisputeResolutionTime);
    }

    /**
     * @dev Returns the details of a listing
     * @param listingId The ID of the listing to query
     * @return seller The address of the seller
     * @return title The title of the listing
     * @return description The description of the listing
     * @return price The price per item
     * @return quantity The total quantity of items
     * @return availableQuantity The available quantity of items
     * @return createdAt The timestamp when the listing was created
     * @return updatedAt The timestamp when the listing was last updated
     * @return status The status of the listing
     * @return isEscrowEnabled Whether escrow is enabled for this listing
     */
    function getListing(uint256 listingId) external view returns (
        address seller,
        string memory title,
        string memory description,
        uint256 price,
        uint256 quantity,
        uint256 availableQuantity,
        uint256 createdAt,
        uint256 updatedAt,
        ListingStatus status,
        bool isEscrowEnabled
    ) {
        Listing storage listing = _listings[listingId];
        return (
            listing.seller,
            listing.title,
            listing.description,
            listing.price,
            listing.quantity,
            listing.availableQuantity,
            listing.createdAt,
            listing.updatedAt,
            listing.status,
            listing.isEscrowEnabled
        );
    }

    /**
     * @dev Returns the details of an order
     * @param orderId The ID of the order to query
     * @return listingId The ID of the listing
     * @return buyer The address of the buyer
     * @return quantity The quantity of items ordered
     * @return totalPrice The total price of the order
     * @return createdAt The timestamp when the order was created
     * @return isPaid Whether the order is paid
     * @return isDelivered Whether the order is delivered
     * @return isConfirmed Whether the order is confirmed
     * @return isDisputed Whether the order is disputed
     */
    function getOrder(uint256 orderId) external view returns (
        uint256 listingId,
        address buyer,
        uint256 quantity,
        uint256 totalPrice,
        uint256 createdAt,
        bool isPaid,
        bool isDelivered,
        bool isConfirmed,
        bool isDisputed
    ) {
        Order storage order = _orders[orderId];
        return (
            order.listingId,
            order.buyer,
            order.quantity,
            order.totalPrice,
            order.createdAt,
            order.isPaid,
            order.isDelivered,
            order.isConfirmed,
            order.isDisputed
        );
    }

    /**
     * @dev Returns the details of a dispute
     * @param disputeId The ID of the dispute to query
     * @return orderId The ID of the order
     * @return buyer The address of the buyer
     * @return seller The address of the seller
     * @return reason The reason for the dispute
     * @return createdAt The timestamp when the dispute was created
     * @return status The status of the dispute
     * @return resolution The resolution of the dispute
     * @return resolver The address of the resolver
     */
    function getDispute(uint256 disputeId) external view returns (
        uint256 orderId,
        address buyer,
        address seller,
        string memory reason,
        uint256 createdAt,
        DisputeStatus status,
        DisputeResolution resolution,
        address resolver
    ) {
        Dispute storage dispute = _disputes[disputeId];
        return (
            dispute.orderId,
            dispute.buyer,
            dispute.seller,
            dispute.reason,
            dispute.createdAt,
            dispute.status,
            dispute.resolution,
            dispute.resolver
        );
    }

    /**
     * @dev Returns the IDs of all listings created by a user
     * @param user The address of the user
     * @return An array of listing IDs
     */
    function getUserListings(address user) external view returns (uint256[] memory) {
        return _userListings[user];
    }

    /**
     * @dev Returns the IDs of all orders created by a user
     * @param user The address of the user
     * @return An array of order IDs
     */
    function getUserOrders(address user) external view returns (uint256[] memory) {
        return _userOrders[user];
    }

    /**
     * @dev Returns the IDs of all disputes created by a user
     * @param user The address of the user
     * @return An array of dispute IDs
     */
    function getUserDisputes(address user) external view returns (uint256[] memory) {
        return _userDisputes[user];
    }

    /**
     * @dev Returns the dispute ID for an order
     * @param orderId The ID of the order
     * @return The ID of the dispute, or 0 if there is no dispute
     */
    function getDisputeForOrder(uint256 orderId) external view returns (uint256) {
        return _orderToDispute[orderId];
    }

    /**
     * @dev Internal function to release payment to the seller
     * @param order The order to release payment for
     */
    function _releasePaymentToSeller(Order storage order) internal {
        Listing storage listing = _listings[order.listingId];
        uint256 platformFee = (order.totalPrice * _platformFeePercentage) / 100;
        uint256 sellerAmount = order.totalPrice - platformFee;
        
        // Transfer platform fee to platform fee recipient
        (bool success1, ) = _platformFeeRecipient.call{value: platformFee}("");
        require(success1, "Platform fee transfer failed");
        
        // Transfer remaining amount to seller
        (bool success2, ) = listing.seller.call{value: sellerAmount}("");
        require(success2, "Seller payment transfer failed");
    }

    /**
     * @dev Internal function to refund the buyer
     * @param order The order to refund
     */
    function _refundBuyer(Order storage order) internal {
        (bool success, ) = order.buyer.call{value: order.totalPrice}("");
        require(success, "Buyer refund transfer failed");
    }

    /**
     * @dev Internal function to split the payment between buyer and seller
     * @param order The order to split payment for
     */
    function _splitPayment(Order storage order) internal {
        Listing storage listing = _listings[order.listingId];
        uint256 platformFee = (order.totalPrice * _platformFeePercentage) / 100;
        uint256 remainingAmount = order.totalPrice - platformFee;
        uint256 buyerAmount = remainingAmount / 2;
        uint256 sellerAmount = remainingAmount - buyerAmount;
        
        // Transfer platform fee to platform fee recipient
        (bool success1, ) = _platformFeeRecipient.call{value: platformFee}("");
        require(success1, "Platform fee transfer failed");
        
        // Transfer buyer's share
        (bool success2, ) = order.buyer.call{value: buyerAmount}("");
        require(success2, "Buyer payment transfer failed");
        
        // Transfer seller's share
        (bool success3, ) = listing.seller.call{value: sellerAmount}("");
        require(success3, "Seller payment transfer failed");
    }

    /**
     * @dev Allows the contract to receive ETH
     */
    receive() external payable {}
} 