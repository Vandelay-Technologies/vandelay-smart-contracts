// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Vandelay Cross Chain Token (VCC)
 * @dev Implementation of the Vandelay Cross Chain ERC20 token contract with cross-chain bridging functionality
 * @author DeFi-Vandelay for Vandelay Technologies
 * @notice This contract implements the ERC20 standard with additional features for cross-chain bridging
 */

contract VandelayCrossChain {
    // Token metadata
    string public constant name = "Vandelay Cross Chain Token";
    string public constant symbol = "VCC";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    
    // Superchain Token Bridge address
    address internal constant SUPERCHAIN_TOKEN_BRIDGE = 0x4200000000000000000000000000000000000028;
    
    // Owner address
    address public owner;
    
    // Mapping for token balances
    mapping(address => uint256) private _balances;
    
    // Mapping for allowances
    mapping(address => mapping(address => uint256)) private _allowances;
    
    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event BridgeMint(address indexed to, uint256 amount);
    event BridgeBurn(address indexed from, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    // Errors
    error Unauthorized();
    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);
    
    /**
     * @dev Constructor that initializes the token with an initial owner and recipient
     * @param initialOwner The address of the initial owner
     * @param recipient The address to receive the initial supply on Ethereum Mainnet
     */
    constructor(address initialOwner, address recipient) {
        require(initialOwner != address(0), "Invalid initial owner address");
        require(recipient != address(0), "Invalid recipient address");
        
        owner = initialOwner;
        
        // Mint initial supply on Ethereum Mainnet
        if (block.chainid == 1) {
            uint256 initialSupply = 1_000_000_000 * 10**decimals; // 1 billion tokens
            _mint(recipient, initialSupply);
        }
    }
    
    /**
     * @dev Returns the balance of a specified account
     * @param account The address to query the balance of
     * @return The balance of the specified account
     */
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }
    
    /**
     * @dev Returns the allowance given to spender by owner
     * @param owner The address of the token owner
     * @param spender The address of the token spender
     * @return The allowance amount
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }
    
    /**
     * @dev Transfers tokens from the caller to a specified address
     * @param to The address to transfer tokens to
     * @param amount The amount of tokens to transfer
     * @return A boolean indicating whether the transfer was successful
     */
    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }
    
    /**
     * @dev Approves the spender to spend tokens on behalf of the owner
     * @param spender The address to approve
     * @param amount The amount of tokens to approve
     * @return A boolean indicating whether the approval was successful
     */
    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    /**
     * @dev Transfers tokens from one address to another using allowance
     * @param from The address to transfer tokens from
     * @param to The address to transfer tokens to
     * @param amount The amount of tokens to transfer
     * @return A boolean indicating whether the transfer was successful
     */
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }
    
    /**
     * @dev Increases the allowance granted to spender by the caller
     * @param spender The address to increase the allowance for
     * @param addedValue The amount to increase the allowance by
     * @return A boolean indicating whether the increase was successful
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }
    
    /**
     * @dev Decreases the allowance granted to spender by the caller
     * @param spender The address to decrease the allowance for
     * @param subtractedValue The amount to decrease the allowance by
     * @return A boolean indicating whether the decrease was successful
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        address owner = msg.sender;
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }
        return true;
    }
    
    /**
     * @dev Mints tokens to a specified address (only callable by the Superchain Token Bridge)
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function bridgeMint(address to, uint256 amount) external {
        _checkTokenBridge(msg.sender);
        _mint(to, amount);
        emit BridgeMint(to, amount);
    }
    
    /**
     * @dev Burns tokens from a specified address (only callable by the Superchain Token Bridge)
     * @param from The address to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function bridgeBurn(address from, uint256 amount) external {
        _checkTokenBridge(msg.sender);
        _burn(from, amount);
        emit BridgeBurn(from, amount);
    }
    
    /**
     * @dev Transfers ownership of the contract to a new owner
     * @param newOwner The address of the new owner
     */
    function transferOwnership(address newOwner) public {
        _checkOwner();
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    
    /**
     * @dev Checks if the caller is the owner
     */
    function _checkOwner() internal view {
        if (owner != msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
    }
    
    /**
     * @dev Checks if the caller is the Superchain Token Bridge
     * @param caller The address of the caller
     */
    function _checkTokenBridge(address caller) internal pure {
        if (caller != SUPERCHAIN_TOKEN_BRIDGE) revert Unauthorized();
    }
    
    /**
     * @dev Internal function to transfer tokens
     * @param from The address to transfer tokens from
     * @param to The address to transfer tokens to
     * @param amount The amount of tokens to transfer
     */
    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        
        _balances[from] = fromBalance - amount;
        _balances[to] += amount;
        
        emit Transfer(from, to, amount);
    }
    
    /**
     * @dev Internal function to mint tokens
     * @param account The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");
        
        totalSupply += amount;
        _balances[account] += amount;
        
        emit Transfer(address(0), account, amount);
    }
    
    /**
     * @dev Internal function to burn tokens
     * @param account The address to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");
        
        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        
        _balances[account] = accountBalance - amount;
        totalSupply -= amount;
        
        emit Transfer(account, address(0), amount);
    }
    
    /**
     * @dev Internal function to approve token spending
     * @param owner The address of the token owner
     * @param spender The address to approve
     * @param amount The amount of tokens to approve
     */
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    /**
     * @dev Internal function to spend allowance
     * @param owner The address of the token owner
     * @param spender The address of the token spender
     * @param amount The amount of tokens to spend
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
    
    /**
     * @dev Allows the contract to receive ETH
     */
    receive() external payable {}
} 