// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../lib/forge-std/src/Test.sol";
import "../../src/day1/MiniERC20.sol";

contract MiniERC20Test is Test {
    MiniERC20 internal token;
    address internal owner = address(this);
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal charlie = address(0xC0FFEE);

    function setUp() public {
        token = new MiniERC20("Mini Token", "MTK", 18);
    }

    /*//////////////////////////////////////////////////////////////
                              BASIC TESTS
    //////////////////////////////////////////////////////////////*/

    function test_InitialParams() public view {
        assertEq(token.name(), "Mini Token");
        assertEq(token.symbol(), "MTK");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);
        assertEq(token.owner(), owner);
    }

    function test_Transfer() public {
        token.mint(alice, 1000 ether);
        
        vm.prank(alice);
        bool ok = token.transfer(bob, 250 ether);

        assertTrue(ok);
        assertEq(token.balanceOf(alice), 750 ether);
        assertEq(token.balanceOf(bob), 250 ether);
        assertEq(token.totalSupply(), 1000 ether);
    
    }

    function test_Approve() public {
        vm.prank(alice);
        bool ok = token.approve(bob, 500 ether);

        assertTrue(ok);
        assertEq(token.allowance(alice,bob), 500 ether);
    }

    function test_TransferFrom() public {
        token.mint(alice, 1000 ether);

        vm.prank(alice);
        token.approve(bob, 400 ether);

        vm.prank(bob);
        bool ok = token.transferFrom(alice, charlie, 300 ether);
    
        assertEq(token.balanceOf(alice),700 ether);
        assertEq(token.balanceOf(charlie),300 ether);
        assertTrue(ok);
        assertEq(token.allowance(alice,bob), 100 ether);

    }

    function test_TransferFrom_InfiniteAllowance() public {
        token.mint(alice, 1000 ether);

        vm.prank(alice);
        token.approve(bob, type(uint256).max);

        vm.prank(bob);
        token.transferFrom(alice, charlie, 200 ether);

        assertEq(token.balanceOf(alice), 800 ether);
        assertEq(token.balanceOf(charlie), 200 ether);
        assertEq(token.allowance(alice, bob), type(uint256).max);
    }

    function test_Burn() public {
        token.mint(alice, 1000 ether);
        vm.prank(alice);
        bool ok = token.burn(300 ether);

        assertTrue(ok);
        assertEq(token.balanceOf(alice), 700 ether);
        assertEq(token.totalSupply(), 700 ether);

    }

    function test_TransferOwnership() public {
        
        token.transferOwnership(alice);
        assertEq(token.owner(), alice);
    
    }

    /*//////////////////////////////////////////////////////////////
                             REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_TransferInsufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert(MiniERC20.InsufficientBalance.selector);
        token.transfer(bob, 1 ether);
    }

    function test_RevertWhen_TransferToZeroAddress() public {
        token.mint(alice, 100 ether);

        vm.prank(alice);
        vm.expectRevert(MiniERC20.ZeroAddress.selector);
        token.transfer(address(0), 1 ether);
    }

    function test_RevertWhen_ApproveZeroAddress() public {
        vm.prank(alice);
        vm.expectRevert(MiniERC20.ZeroAddress.selector);
        token.approve(address(0), 1 ether);
    }

    function test_RevertWhen_TransferFromInsufficientAllowance() public {
        token.mint(alice, 100 ether);

        vm.prank(alice);
        token.approve(bob, 10 ether);

        vm.prank(bob);
        vm.expectRevert(MiniERC20.InsufficientAllowance.selector);
        token.transferFrom(alice, charlie, 11 ether);
    }

    function test_RevertWhen_TransferFromInsufficientBalance() public {
        token.mint(alice, 200 ether);

        vm.prank(alice);
        token.approve(bob, 300 ether);

        vm.prank(bob);
        vm.expectRevert(MiniERC20.InsufficientBalance.selector);
        token.transferFrom(alice, charlie, 300 ether);

    }

    function test_RevertWhen_NonOwnerMint() public {
        vm.prank(alice);
        vm.expectRevert(MiniERC20.NotOwner.selector);
        token.mint(alice, 100 ether);
    }

    function test_RevertWhen_MintToZeroAddress() public {
        vm.expectRevert(MiniERC20.ZeroAddress.selector);
        token.mint(address(0), 100 ether);
    }

    function test_RevertWhen_BurnInsufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert(MiniERC20.InsufficientBalance.selector);
        token.burn(1 ether);
    }

    function test_RevertWhen_NonOwnerTransferOwnership() public {
        vm.prank(alice);
        vm.expectRevert(MiniERC20.NotOwner.selector);
        token.transferOwnership(bob);
    }

    function test_RevertWhen_TransferOwnershipToZeroAddress() public {
        vm.expectRevert(MiniERC20.ZeroAddress.selector);
        token.transferOwnership(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    function test_EmitTransferOnMint() public {
        vm.expectEmit(true, true, false, true);
        emit MiniERC20.Transfer(address(0), alice, 100 ether);

        token.mint(alice, 100 ether);
    }

    function test_EmitApprovalOnApprove() public {
        vm.prank(alice);

        vm.expectEmit(true, true, false, true);
        emit MiniERC20.Approval(alice, bob, 50 ether);

        token.approve(bob, 50 ether);
    }

    function test_EmitTransferOnTransfer() public {
        token.mint(alice, 100 ether);

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit MiniERC20.Transfer(alice, bob, 20 ether);

        token.transfer(bob, 20 ether);
    }

    /*//////////////////////////////////////////////////////////////
                               FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_TransferPreservesSum(uint256 mintAmount, uint256 sendAmount) public {
    
        mintAmount = bound(mintAmount,1,type(uint256).max);
        sendAmount = bound(sendAmount, 0, mintAmount);

        token.mint(alice, mintAmount);

        uint256 beforeSum = token.balanceOf(alice) + token.balanceOf(bob);

        vm.prank(alice);
        token.transfer(bob, sendAmount);

        uint256 afterSum = token.balanceOf(alice) + token.balanceOf(bob);

        assertEq(afterSum, beforeSum);
        assertEq(token.totalSupply(), mintAmount);

    }

    function testFuzz_MintIncreasesTotalSupply(uint256 amount1, uint256 amount2) public {

        amount1 = bound(amount1, 0, type(uint128).max);
        amount2 = bound(amount2, 0, type(uint128).max);

        uint256 beforeSupply = token.totalSupply();

        token.mint(alice, amount1);
        uint256 midSupply = token.totalSupply();

        token.mint(bob, amount2);
        uint256 afterSupply = token.totalSupply();

        assertGe(midSupply, beforeSupply);
        assertGe(afterSupply, midSupply);
        assertEq(afterSupply, beforeSupply + amount1 + amount2);

    }

    /*//////////////////////////////////////////////////////////////
                          EXTRA ACCOUNTING TEST
    //////////////////////////////////////////////////////////////*/

    function test_TotalSupplyMatchesKnownBalances() public {
        token.mint(alice, 1000 ether);
        token.mint(bob, 500 ether);

        vm.prank(alice);
        token.transfer(charlie, 200 ether);

        vm.prank(bob);
        token.burn(100 ether);

        uint256 know = token.balanceOf(alice)
                        + token.balanceOf(bob)
                        +token.balanceOf(charlie);

        assertEq(know,token.totalSupply());
    }
    
}
