// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Vandelay Stablecoin (VST)
 * @dev Implementation of the Vandelay Stablecoin ERC20 token contract with EIP-2612 Permit functionality and token bridge mechanism
 * @author DeFi-Vandelay for Vandelay Technologies
 * @notice This contract implements the ERC20 standard with additional features for cross-chain bridging
 */

contract VandelayStablecoin {
    // Token metadata
    string public constant name = "Vandelay Stablecoin";
    string public constant symbol = "VST";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    
    // Immutable token bridge address
    address public immutable tokenBridge;
    
    // EIP-2612 Permit variables
    bytes32 public DOMAIN_SEPARATOR;
    mapping(address => uint256) public nonces;
    
    // Mapping for token balances
    mapping(address => uint256) private _balances;
    
    // Mapping for allowances
    mapping(address => mapping(address => uint256)) private _allowances;
    
    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event BridgeMint(address indexed to, uint256 amount);
    event BridgeBurn(address indexed from, uint256 amount);
    
    // Errors
    error Unauthorized();
    error InvalidSignature();
    error ExpiredSignature();
    error InvalidNonce();
    
    /**
     * @dev Constructor that initializes the token with a token bridge address
     * @param _tokenBridge The address of the token bridge contract
     */
    constructor(address _tokenBridge) {
        require(_tokenBridge != address(0), "Invalid token bridge address");
        tokenBridge = _tokenBridge;
        
        // Initialize DOMAIN_SEPARATOR for EIP-2612
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
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
     * @dev Mints tokens to a specified address (only callable by the token bridge)
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function bridgeMint(address to, uint256 amount) external {
        _checkTokenBridge(msg.sender);
        _mint(to, amount);
        emit BridgeMint(to, amount);
    }
    
    /**
     * @dev Burns tokens from a specified address (only callable by the token bridge)
     * @param from The address to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function bridgeBurn(address from, uint256 amount) external {
        _checkTokenBridge(msg.sender);
        _burn(from, amount);
        emit BridgeBurn(from, amount);
    }
    
    /**
     * @dev Implements the permit function as specified in EIP-2612
     * @param owner The address of the token owner
     * @param spender The address of the token spender
     * @param value The amount of tokens to approve
     * @param deadline The deadline after which the signature is no longer valid
     * @param v The recovery byte of the signature
     * @param r The first 32 bytes of the signature
     * @param s The second 32 bytes of the signature
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        if (block.timestamp > deadline) revert ExpiredSignature();
        
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                spender,
                value,
                nonces[owner]++,
                deadline
            )
        );
        
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                structHash
            )
        );
        
        address signer = ecrecover(hash, v, r, s);
        if (signer != owner) revert InvalidSignature();
        
        _approve(owner, spender, value);
    }
    
    /**
     * @dev Checks if the caller is the token bridge
     * @param caller The address of the caller
     */
    function _checkTokenBridge(address caller) internal view {
        if (caller != tokenBridge) revert Unauthorized();
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