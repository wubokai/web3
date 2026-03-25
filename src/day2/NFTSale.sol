// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MiniERC721} from "./MiniERC721.sol";

contract NFTSale {
    MiniERC721 public immutable nft;
    address public owner;
    uint256 public price;
    uint256 public nextTokenId;
    
    error NotOwner();
    error InsufficientPayment();
    error WithdrawFailed();
    error InvalidPrice();

    event Bought(address indexed buyer, uint256 indexed tokenId, uint256 pricePaid);
    event Withdraw(address indexed owner, uint256 amount);
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address nftAddress, uint256 initialPrice){
        if (nftAddress == address(0)) revert InvalidPrice();
        if (initialPrice == 0) revert InvalidPrice();

        nft = MiniERC721(nftAddress);
        owner = msg.sender;
        price = initialPrice;
    }

    function buy() external payable {
        if(msg.value < price) revert InsufficientPayment();
        
        uint256 tokenId = nextTokenId;
        nextTokenId = tokenId + 1;

        nft.mint(msg.sender, tokenId);
        emit Bought(msg.sender,tokenId,msg.value);
    }

    function withdraw() external onlyOwner{
        uint256 amount = address(this).balance;
        
        (bool ok, ) = payable(owner).call{value: amount}("");
        if(!ok) revert WithdrawFailed();

        emit Withdraw(owner, amount);
    }

    function setPrice(uint256 newPrice) external onlyOwner {
        if(newPrice == 0) revert InvalidPrice();
        uint256 oldPrice = price;
        price = newPrice;

        emit PriceUpdated(oldPrice,newPrice);
    }

}