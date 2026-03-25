// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import "../../lib/forge-std/src/Test.sol";
import {NFTSale} from "../../src/day2/NFTSale.sol";
import {MiniERC721} from "../../src/day2/MiniERC721.sol";

contract NFTSaleTest is Test {

    MiniERC721 internal nft;
    NFTSale internal sale;

    address internal deployer = address(this);
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    uint256 internal constant PRICE = 0.1 ether;

    event Bought(address indexed buyer, uint256 indexed tokenId, uint256 pricePaid);
    event Withdraw(address indexed owner, uint256 amount);
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);

    function setUp() public {
        nft = new MiniERC721("Mini NFT", "MNFT");
        sale = new NFTSale(address(nft), PRICE);

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function test_BuySuccess() public {
        vm.prank(alice);
        sale.buy{value: PRICE}();

        assertEq(nft.ownerOf(0), alice);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(sale.nextTokenId(), 1);
        assertEq(address(sale).balance, PRICE);
    }

    function test_BuyEmitsEvent() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit Bought(alice, 0, PRICE);
        sale.buy{value: PRICE}();
    }

    function test_RevertIf_BuyInsufficientPayment() public {
        vm.prank(alice);
        vm.expectRevert(NFTSale.InsufficientPayment.selector);
        sale.buy{value: PRICE - 1}();
    }

    function test_BuyOverpayAllowed() public {
        vm.prank(alice);
        sale.buy{value: 1 ether}();

        assertEq(nft.ownerOf(0), alice);
        assertEq(address(sale).balance, 1 ether);
    }

    function test_MultipleBuysIncrementTokenId() public {
        vm.prank(alice);
        sale.buy{value: PRICE}();

        vm.prank(bob);
        sale.buy{value: PRICE}();

        assertEq(nft.ownerOf(0), alice);
        assertEq(nft.ownerOf(1), bob);
        assertEq(sale.nextTokenId(), 2);
    }

    function test_WithdrawByOwner() public {
        vm.prank(alice);
        sale.buy{value: PRICE}();

        uint256 ownerBalanceBefore = address(this).balance;

        vm.expectEmit(true, false, false, true);
        emit Withdraw(address(this), PRICE);
        sale.withdraw();

        uint256 ownerBalanceAfter = address(this).balance;

        assertEq(address(sale).balance, 0);
        assertEq(ownerBalanceAfter, ownerBalanceBefore + PRICE);
    }

    function test_RevertIf_WithdrawByNonOwner() public {
        vm.prank(alice);
        vm.expectRevert(NFTSale.NotOwner.selector);
        sale.withdraw();
    }

    function test_SetPrice() public {
        uint256 newPrice = 0.2 ether;

        vm.expectEmit(false, false, false, true);
        emit PriceUpdated(PRICE, newPrice);
        sale.setPrice(newPrice);

        assertEq(sale.price(), newPrice);
    }

    function test_RevertIf_SetPriceByNonOwner() public {
        vm.prank(alice);
        vm.expectRevert(NFTSale.NotOwner.selector);
        sale.setPrice(0.2 ether);
    }

    function test_RevertIf_SetPriceToZero() public {
        vm.expectRevert(NFTSale.InvalidPrice.selector);
        sale.setPrice(0);
    }

    receive() external payable {}

}