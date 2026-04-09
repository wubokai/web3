// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Box {
    uint256 public value;
    address public owner;

    error NotOwner();
    error ZeroAddress();

    event ValueChanged(uint256 newValue);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address _owner) {
        if (_owner == address(0)) revert ZeroAddress();
        owner = _owner;
        emit OwnershipTransferred(address(0), _owner);
    }

    function setValue(uint256 newValue) external onlyOwner {
        value = newValue;
        emit ValueChanged(newValue);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}