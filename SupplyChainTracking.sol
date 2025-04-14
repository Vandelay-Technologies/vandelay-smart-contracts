// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Vandelay Supply Chain Tracking
 * @dev Implementation of a supply chain tracking system for product movement verification
 * @author DeFi-Vandelay for Vandelay Technologies
 * @notice This contract implements a supply chain tracking system with product movement logging and verification
 */

contract VandelaySupplyChainTracking {
    // Enum for product status
    enum ProductStatus {
        Created,
        InTransit,
        Delivered,
        Sold,
        Returned
    }

    // Structure for product details
    struct Product {
        string productId;                  // Unique identifier for the product
        string name;                       // Name of the product
        string description;                // Description of the product
        address manufacturer;              // Address of the manufacturer
        uint256 timestamp;                 // Timestamp when the product was created
        ProductStatus status;              // Current status of the product
        address currentLocation;           // Current location of the product
        bool isValid;                      // Flag to indicate if the product is valid
    }

    // Structure for movement details
    struct Movement {
        string productId;                  // ID of the product being moved
        address from;                      // Address of the sender
        address to;                        // Address of the receiver
        uint256 timestamp;                 // Timestamp of the movement
        string notes;                      // Additional notes about the movement
    }

    // Mapping from product ID to Product struct
    mapping(string => Product) public products;
    
    // Mapping from product ID to array of Movement structs
    mapping(string => Movement[]) public productMovements;
    
    // Mapping from address to role
    mapping(address => bool) public manufacturers;
    mapping(address => bool) public distributors;
    mapping(address => bool) public retailers;
    
    // Owner of the contract
    address public owner;
    
    // Events
    event ProductCreated(string indexed productId, string name, address indexed manufacturer);
    event ProductMoved(string indexed productId, address indexed from, address indexed to);
    event ProductStatusUpdated(string indexed productId, ProductStatus status);
    event ManufacturerAdded(address indexed manufacturer);
    event DistributorAdded(address indexed distributor);
    event RetailerAdded(address indexed retailer);
    event ProductInvalidated(string indexed productId, address indexed by);

    /**
     * @dev Constructor sets the owner of the contract
     */
    constructor() {
        owner = msg.sender;
        manufacturers[msg.sender] = true;
    }

    /**
     * @dev Modifier to restrict function access to the owner
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    /**
     * @dev Modifier to restrict function access to manufacturers
     */
    modifier onlyManufacturer() {
        require(manufacturers[msg.sender], "Only manufacturer can call this function");
        _;
    }

    /**
     * @dev Modifier to restrict function access to distributors
     */
    modifier onlyDistributor() {
        require(distributors[msg.sender], "Only distributor can call this function");
        _;
    }

    /**
     * @dev Modifier to restrict function access to retailers
     */
    modifier onlyRetailer() {
        require(retailers[msg.sender], "Only retailer can call this function");
        _;
    }

    /**
     * @dev Modifier to check if a product exists
     * @param _productId The ID of the product to check
     */
    modifier productExists(string memory _productId) {
        require(products[_productId].isValid, "Product does not exist");
        _;
    }

    /**
     * @dev Adds a new manufacturer
     * @param _manufacturer The address of the manufacturer to add
     */
    function addManufacturer(address _manufacturer) external onlyOwner {
        require(_manufacturer != address(0), "Invalid manufacturer address");
        manufacturers[_manufacturer] = true;
        emit ManufacturerAdded(_manufacturer);
    }

    /**
     * @dev Adds a new distributor
     * @param _distributor The address of the distributor to add
     */
    function addDistributor(address _distributor) external onlyOwner {
        require(_distributor != address(0), "Invalid distributor address");
        distributors[_distributor] = true;
        emit DistributorAdded(_distributor);
    }

    /**
     * @dev Adds a new retailer
     * @param _retailer The address of the retailer to add
     */
    function addRetailer(address _retailer) external onlyOwner {
        require(_retailer != address(0), "Invalid retailer address");
        retailers[_retailer] = true;
        emit RetailerAdded(_retailer);
    }

    /**
     * @dev Creates a new product
     * @param _productId The unique identifier for the product
     * @param _name The name of the product
     * @param _description The description of the product
     */
    function createProduct(
        string memory _productId,
        string memory _name,
        string memory _description
    ) external onlyManufacturer {
        require(bytes(_productId).length > 0, "Product ID cannot be empty");
        require(bytes(_name).length > 0, "Product name cannot be empty");
        require(!products[_productId].isValid, "Product already exists");
        
        products[_productId] = Product({
            productId: _productId,
            name: _name,
            description: _description,
            manufacturer: msg.sender,
            timestamp: block.timestamp,
            status: ProductStatus.Created,
            currentLocation: msg.sender,
            isValid: true
        });
        
        emit ProductCreated(_productId, _name, msg.sender);
    }

    /**
     * @dev Moves a product from one location to another
     * @param _productId The ID of the product to move
     * @param _to The address of the receiver
     * @param _notes Additional notes about the movement
     */
    function moveProduct(
        string memory _productId,
        address _to,
        string memory _notes
    ) external productExists(_productId) {
        Product storage product = products[_productId];
        require(product.currentLocation == msg.sender, "Only current holder can move the product");
        require(_to != address(0), "Invalid receiver address");
        
        // Check if the receiver is a valid participant in the supply chain
        require(
            manufacturers[_to] || distributors[_to] || retailers[_to],
            "Receiver must be a manufacturer, distributor, or retailer"
        );
        
        // Create a new movement record
        Movement memory movement = Movement({
            productId: _productId,
            from: msg.sender,
            to: _to,
            timestamp: block.timestamp,
            notes: _notes
        });
        
        productMovements[_productId].push(movement);
        
        // Update product status and location
        product.currentLocation = _to;
        
        // Update product status based on the receiver
        if (manufacturers[_to]) {
            product.status = ProductStatus.Created;
        } else if (distributors[_to]) {
            product.status = ProductStatus.InTransit;
        } else if (retailers[_to]) {
            product.status = ProductStatus.Delivered;
        }
        
        emit ProductMoved(_productId, msg.sender, _to);
        emit ProductStatusUpdated(_productId, product.status);
    }

    /**
     * @dev Marks a product as sold
     * @param _productId The ID of the product to mark as sold
     */
    function markAsSold(string memory _productId) external onlyRetailer productExists(_productId) {
        Product storage product = products[_productId];
        require(product.currentLocation == msg.sender, "Only current holder can mark the product as sold");
        require(product.status == ProductStatus.Delivered, "Product must be delivered before it can be sold");
        
        product.status = ProductStatus.Sold;
        
        emit ProductStatusUpdated(_productId, product.status);
    }

    /**
     * @dev Marks a product as returned
     * @param _productId The ID of the product to mark as returned
     * @param _to The address to return the product to
     */
    function markAsReturned(
        string memory _productId,
        address _to
    ) external onlyRetailer productExists(_productId) {
        Product storage product = products[_productId];
        require(product.currentLocation == msg.sender, "Only current holder can mark the product as returned");
        require(product.status == ProductStatus.Sold, "Product must be sold before it can be returned");
        require(
            manufacturers[_to] || distributors[_to],
            "Product can only be returned to a manufacturer or distributor"
        );
        
        // Create a new movement record for the return
        Movement memory movement = Movement({
            productId: _productId,
            from: msg.sender,
            to: _to,
            timestamp: block.timestamp,
            notes: "Product returned"
        });
        
        productMovements[_productId].push(movement);
        
        // Update product status and location
        product.currentLocation = _to;
        product.status = ProductStatus.Returned;
        
        emit ProductMoved(_productId, msg.sender, _to);
        emit ProductStatusUpdated(_productId, product.status);
    }

    /**
     * @dev Invalidates a product (e.g., if it's counterfeit or damaged)
     * @param _productId The ID of the product to invalidate
     */
    function invalidateProduct(string memory _productId) external onlyManufacturer productExists(_productId) {
        Product storage product = products[_productId];
        require(product.manufacturer == msg.sender, "Only manufacturer can invalidate the product");
        
        product.isValid = false;
        
        emit ProductInvalidated(_productId, msg.sender);
    }

    /**
     * @dev Returns the details of a product
     * @param _productId The ID of the product to query
     * @return name The name of the product
     * @return description The description of the product
     * @return manufacturer The address of the manufacturer
     * @return timestamp The timestamp when the product was created
     * @return status The current status of the product
     * @return currentLocation The current location of the product
     * @return isValid Whether the product is valid
     */
    function getProductDetails(string memory _productId) external view returns (
        string memory name,
        string memory description,
        address manufacturer,
        uint256 timestamp,
        ProductStatus status,
        address currentLocation,
        bool isValid
    ) {
        Product storage product = products[_productId];
        return (
            product.name,
            product.description,
            product.manufacturer,
            product.timestamp,
            product.status,
            product.currentLocation,
            product.isValid
        );
    }

    /**
     * @dev Returns the movement history of a product
     * @param _productId The ID of the product to query
     * @return An array of Movement structs representing the movement history
     */
    function getProductMovements(string memory _productId) external view returns (Movement[] memory) {
        return productMovements[_productId];
    }

    /**
     * @dev Returns the number of movements for a product
     * @param _productId The ID of the product to query
     * @return The number of movements for the product
     */
    function getProductMovementCount(string memory _productId) external view returns (uint256) {
        return productMovements[_productId].length;
    }

    /**
     * @dev Returns whether an address is a manufacturer
     * @param _address The address to check
     * @return Whether the address is a manufacturer
     */
    function isManufacturer(address _address) external view returns (bool) {
        return manufacturers[_address];
    }

    /**
     * @dev Returns whether an address is a distributor
     * @param _address The address to check
     * @return Whether the address is a distributor
     */
    function isDistributor(address _address) external view returns (bool) {
        return distributors[_address];
    }

    /**
     * @dev Returns whether an address is a retailer
     * @param _address The address to check
     * @return Whether the address is a retailer
     */
    function isRetailer(address _address) external view returns (bool) {
        return retailers[_address];
    }
} 