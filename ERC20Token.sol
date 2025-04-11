// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Vandelay Token (VTT)
 * @dev Implementation of the Vandelay Token ERC20 token contract
 * @author DeFi-Vandelay for Vandelay Technologies
 * @notice This contract implements the ERC20 standard with additional features
 */

contract VandelayToken {
    // Token metadata
    string public constant name = "Vandelay Token";
    string public constant symbol = "VTT";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    // Mapping for token balances
    mapping(address => uint256) private _balances;
    
    // Mapping for allowances
    mapping(address => mapping(address => uint256)) private _allowances;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Constructor that gives the msg.sender all of the initial supply
     * @param initialSupply The initial supply of tokens to be minted
     */
    constructor(uint256 initialSupply) {
        _mint(msg.sender, initialSupply * 10**decimals);
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
            _approve(owner, spender, currentAllowance - amount);
        }
    }
}
