// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MiniERC1155} from "./MiniERC1155.sol";

contract MultiTokenSale {
    MiniERC1155 public immutable token;
    address public owner;

    mapping(uint256 => uint256) public priceOf;

    error NotOwner();
    error InvalidPrice();
    error InsufficientPayment();
    error InsufficientInventory();
    error WithdrawFailed();

    constructor(address tokenAddress) {
        token = MiniERC1155(tokenAddress);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function setPrice(uint256 id, uint256 price) external onlyOwner {
        if (price == 0) revert InvalidPrice();
        priceOf[id] = price;
    }

    function buy(uint256 id, uint256 amount) external payable {
        uint256 unitPrice = priceOf[id];
        if (unitPrice == 0) revert InvalidPrice();

        uint256 totalCost = unitPrice * amount;
        if (msg.value < totalCost) revert InsufficientPayment();

        uint256 inventory = token.balanceOf(id, address(this));
        if (inventory < amount) revert InsufficientInventory();

        token.safeTransferFrom(address(this), msg.sender, id, amount, "");
    }

    function withdraw() external onlyOwner {
        uint256 bal = address(this).balance;
        (bool ok, ) = payable(owner).call{value: bal}("");
        if (!ok) revert WithdrawFailed();
    }


}