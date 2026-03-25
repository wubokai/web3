// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MiniERC20 {

    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256 public totalSupply;
    address public owner;

    mapping(address=>uint256) public balanceOf;
    mapping(address=>mapping(address=>uint256)) public allowance;

    error NotOwner();
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed tokenOwner, address indexed spender, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner(){
        if(msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ){
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        owner = msg.sender;

        emit OwnershipTransferred(address(0), msg.sender);
    }

    function transfer(address to, uint256 amount) external returns(bool){
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns(bool){
        uint256 allow = allowance[from][msg.sender];

        if(allow != type(uint256).max){
            if(allow < amount) revert InsufficientAllowance();

            unchecked {
                allowance[from][msg.sender] = allow - amount;
            }
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();

        uint256 bal = balanceOf[from];
        if(bal < amount) revert InsufficientBalance();

        unchecked {
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

    }

    function approve(address spender, uint256 amount) external returns(bool){
        if(spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function mint(address to, uint256 amount) external onlyOwner returns(bool){
        if(to == address(0)) revert ZeroAddress();
        totalSupply += amount;
        balanceOf[to] += amount;

        emit Transfer(address(0), to, amount);
        return true;
    } 

    function burn(uint256 amount) external returns(bool){
        uint256 bal = balanceOf[msg.sender];
        if(bal < amount) revert InsufficientBalance();

        unchecked {
            balanceOf[msg.sender] -= amount;
            totalSupply -= amount;
        }

        emit Transfer(msg.sender, address(0), amount);
        return true;
    }

    function transferOwnership(address newOwner) external onlyOwner{
        if(newOwner == address(0)) revert ZeroAddress();

        address old = owner;
        owner = newOwner;

        emit OwnershipTransferred(old, newOwner);
    }

}