// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TestTarget {
    uint256 public number;
    uint256 public lastValue;

    event Called(uint256 value, uint256 newNumber);
    event Received(address indexed sender, uint256 amount);

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function setNumber(uint256 _number) external payable {
        number = _number;
        lastValue = msg.value;
        emit Called(msg.value, _number);
    }
}