// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../lib/forge-std/src/Test.sol";
import {MiniERC1155} from "../../src/day3/MiniERC1155.sol";
import {MultiTokenSale} from "../../src/day3/MultiTokenSale.sol";

contract MultiTokenSaleTest is Test {
    MiniERC1155 token;
    MultiTokenSale sale;

    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        token = new MiniERC1155("ipfs://base/");
        sale = new MultiTokenSale(address(token));

        token.mint(address(sale), 1, 100);
        token.mint(address(sale), 2, 50);

        sale.setPrice(1, 0.01 ether);
        sale.setPrice(2, 0.02 ether);

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function test_SetPrice() public {
        sale.setPrice(3, 0.05 ether);
        assertEq(sale.priceOf(3), 0.05 ether);
    }

    function test_RevertIf_NonOwnerSetPrice() public {
        vm.prank(alice);
        vm.expectRevert(MultiTokenSale.NotOwner.selector);
        sale.setPrice(3, 0.05 ether);
    }

    function test_BuySuccess() public {
        vm.prank(alice);
        sale.buy{value: 0.03 ether}(1, 3);

        assertEq(token.balanceOf(1, alice), 3);
        assertEq(token.balanceOf(1, address(sale)), 97);
    }

    function test_RevertIf_InsufficientPayment() public {
        vm.prank(alice);
        vm.expectRevert(MultiTokenSale.InsufficientPayment.selector);
        sale.buy{value: 0.01 ether}(2, 2);
    }

    function test_RevertIf_InsufficientInventory() public {
        vm.prank(alice);
        vm.expectRevert(MultiTokenSale.InsufficientInventory.selector);
        sale.buy{value: 2 ether}(2, 100);
    }

    function test_RevertIf_PriceNotSet() public {
        vm.prank(alice);
        vm.expectRevert(MultiTokenSale.InvalidPrice.selector);
        sale.buy{value: 1 ether}(999, 1);
    }

    function test_Withdraw() public {
        vm.prank(alice);
        sale.buy{value: 0.02 ether}(1, 2);

        uint256 ownerBalBefore = address(this).balance;

        sale.withdraw();

        uint256 ownerBalAfter = address(this).balance;

        assertEq(address(sale).balance, 0);
        assertEq(ownerBalAfter, ownerBalBefore + 0.02 ether);
    }

    function test_RevertIf_NonOwnerWithdraw() public {
        vm.prank(alice);
        vm.expectRevert(MultiTokenSale.NotOwner.selector);
        sale.withdraw();
    }

    receive() external payable {}
}