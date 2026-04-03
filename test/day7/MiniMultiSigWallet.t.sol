// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../lib/forge-std/src/Test.sol";
import "../../src/day7/MiniMultiSigWallet.sol";
import "../../src/day7/TestTarget.sol";

contract Reverter {
    function willRevert() external pure {
        revert("call failed");
    }
}

contract MiniMultiSigWalletTest is Test {
    MiniMultiSigWallet public wallet;
    TestTarget public target;
    Reverter public reverter;

    address public owner1 = makeAddr("owner1");
    address public owner2 = makeAddr("owner2");
    address public owner3 = makeAddr("owner3");
    address public nonOwner = makeAddr("nonOwner");
    address public recipient = makeAddr("recipient");

    function setUp() public {
        address[] memory _owners = new address[](3);
        _owners[0] = owner1;
        _owners[1] = owner2;
        _owners[2] = owner3;

        wallet = new MiniMultiSigWallet(_owners, 2);
        target = new TestTarget();
        reverter = new Reverter();

        vm.deal(owner1, 100 ether);
        vm.deal(owner2, 100 ether);
        vm.deal(owner3, 100 ether);
        vm.deal(nonOwner, 100 ether);
        vm.deal(address(this), 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_SetsOwnersAndRequired() public view {
        assertEq(wallet.required(), 2);
        assertEq(wallet.owners(0), owner1);
        assertEq(wallet.owners(1), owner2);
        assertEq(wallet.owners(2), owner3);

        assertTrue(wallet.isOwner(owner1));
        assertTrue(wallet.isOwner(owner2));
        assertTrue(wallet.isOwner(owner3));
        assertFalse(wallet.isOwner(nonOwner));
    }

    function test_Constructor_RevertIfOwnersEmpty() public {
        address[] memory _owners = new address[](0);

        vm.expectRevert(MiniMultiSigWallet.InvalidRequirement.selector);
        new MiniMultiSigWallet(_owners, 1);
    }

    function test_Constructor_RevertIfRequiredZero() public {
        address[] memory _owners = new address[](3);
        _owners[0] = owner1;
        _owners[1] = owner2;

        vm.expectRevert(MiniMultiSigWallet.InvalidRequirement.selector);
        new MiniMultiSigWallet(_owners, 0);
    }

    function test_Constructor_RevertIfRequiredGreaterThanOwnersLength() public {
        address[] memory _owners = new address[](2);
        _owners[0] = owner1;
        _owners[1] = owner2;

        vm.expectRevert(MiniMultiSigWallet.InvalidRequirement.selector);
        new MiniMultiSigWallet(_owners, 3);
    }

    function test_Constructor_RevertIfZeroOwner() public {
        address[] memory _owners = new address[](3);
        _owners[0] = owner1;
        _owners[1] = address(0);

        vm.expectRevert(MiniMultiSigWallet.InvalidOwner.selector);
        new MiniMultiSigWallet(_owners, 2);
    }

    function test_Constructor_RevertIfDuplicateOwner() public {
        address[] memory _owners = new address[](3);
        _owners[0] = owner1;
        _owners[1] = owner1;

        vm.expectRevert(MiniMultiSigWallet.OwnerNotUnique.selector);
        new MiniMultiSigWallet(_owners, 2);
    }

    /*//////////////////////////////////////////////////////////////
                              RECEIVE
    //////////////////////////////////////////////////////////////*/

    function test_ReceiveETH() public {
        vm.prank(owner1);
        (bool ok, ) = address(wallet).call{value: 1 ether}("");
        assertTrue(ok);

        assertEq(address(wallet).balance, 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                          SUBMIT TRANSACTION
    //////////////////////////////////////////////////////////////*/

    function test_SubmitTransaction() public {
        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");

        assertEq(wallet.getTransactionCount(), 1);
        
        (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 numApprovals
        ) = wallet.getTransaction(0);

        assertEq(to, recipient);
        assertEq(value, 1 ether);
        assertEq(data.length, 0);
        assertFalse(executed);
        assertEq(numApprovals, 0);
    }

    function test_SubmitTransaction_RevertIfNotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(MiniMultiSigWallet.NotOwner.selector);
        wallet.submitTransaction(recipient, 1 ether, "");
    }

    /*//////////////////////////////////////////////////////////////
                         APPROVE TRANSACTION
    //////////////////////////////////////////////////////////////*/

    function test_ApproveTransaction() public {
        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        wallet.approveTransaction(0);

        (, , , , uint256 numApprovals) = wallet.getTransaction(0);
        assertEq(numApprovals, 1);
        assertTrue(wallet.approved(0, owner1));
    }

    function test_ApproveTransaction_RevertIfNotOwner() public {
        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(nonOwner);
        vm.expectRevert(MiniMultiSigWallet.NotOwner.selector);
        wallet.approveTransaction(0);
    }

    function test_ApproveTransaction_RevertIfAlreadyApproved() public {
        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        wallet.approveTransaction(0);

        vm.prank(owner1);
        vm.expectRevert(MiniMultiSigWallet.TxAlreadyApproved.selector);
        wallet.approveTransaction(0);
    }

    function test_ApproveTransaction_RevertIfTxDoesNotExist() public {
        vm.prank(owner1);
        vm.expectRevert(MiniMultiSigWallet.TxDoesNotExist.selector);
        wallet.approveTransaction(0);
    }

    /*//////////////////////////////////////////////////////////////
                         REVOKE APPROVAL
    //////////////////////////////////////////////////////////////*/

    function test_RevokeApproval() public {
        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        wallet.approveTransaction(0);

        vm.prank(owner1);
        wallet.revokeApproval(0);

        (, , , , uint256 numApprovals) = wallet.getTransaction(0);
        assertEq(numApprovals, 0);
        assertFalse(wallet.approved(0, owner1));
    }

    function test_RevokeApproval_RevertIfNotApproved() public {
        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        vm.expectRevert(MiniMultiSigWallet.TxNotApproved.selector);
        wallet.revokeApproval(0);
    }

    /*//////////////////////////////////////////////////////////////
                        EXECUTE TRANSACTION
    //////////////////////////////////////////////////////////////*/

    function _fundWallet(uint256 amount) internal {
        vm.prank(owner1);
        (bool ok, ) = address(wallet).call{value: amount}("");
        assertTrue(ok);
    }

    function test_ExecuteTransaction_SendETH() public {
        _fundWallet(2 ether);

        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        wallet.approveTransaction(0);

        vm.prank(owner2);
        wallet.approveTransaction(0);

        uint256 balanceBefore = recipient.balance;

        vm.prank(owner1);
        wallet.executeTransaction(0);

        assertEq(recipient.balance, balanceBefore + 1 ether);

        (, , , bool executed, uint256 numApprovals) = wallet.getTransaction(0);
        assertTrue(executed);
        assertEq(numApprovals, 2);
    }
    
    function test_ExecuteTransaction_CallContract() public {
        _fundWallet(1 ether);

        bytes memory data = abi.encodeWithSignature("setNumber(uint256)", 123);

        vm.prank(owner1);
        wallet.submitTransaction(address(target), 0.2 ether, data);

        vm.prank(owner1);
        wallet.approveTransaction(0);

        vm.prank(owner2);
        wallet.approveTransaction(0);

        vm.prank(owner3);
        wallet.executeTransaction(0);

        assertEq(target.number(), 123);
        assertEq(target.lastValue(), 0.2 ether);
    }

    function test_ExecuteTransaction_RevertIfNotEnoughApprovals() public {
        _fundWallet(1 ether);

        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        wallet.approveTransaction(0);

        vm.prank(owner1);
        vm.expectRevert(MiniMultiSigWallet.NotEnoughApprovals.selector);
        wallet.executeTransaction(0);
    }

    function test_ExecuteTransaction_RevertIfAlreadyExecuted() public {
        _fundWallet(2 ether);

        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        wallet.approveTransaction(0);

        vm.prank(owner2);
        wallet.approveTransaction(0);

        vm.prank(owner1);
        wallet.executeTransaction(0);

        vm.prank(owner2);
        vm.expectRevert(MiniMultiSigWallet.TxAlreadyExecuted.selector);
        wallet.executeTransaction(0);
    }

    function test_ExecuteTransaction_RevertIfCallFails() public {
        bytes memory data = abi.encodeWithSignature("willRevert()");

        vm.prank(owner1);
        wallet.submitTransaction(address(reverter), 0, data);

        vm.prank(owner1);
        wallet.approveTransaction(0);

        vm.prank(owner2);
        wallet.approveTransaction(0);

        vm.prank(owner1);
        vm.expectRevert(MiniMultiSigWallet.TxExecutionFailed.selector);
        wallet.executeTransaction(0);
    }

    function test_Approve_RevertIfAlreadyExecuted() public {
        _fundWallet(2 ether);

        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        wallet.approveTransaction(0);

        vm.prank(owner2);
        wallet.approveTransaction(0);

        vm.prank(owner1);
        wallet.executeTransaction(0);

        vm.prank(owner3);
        vm.expectRevert(MiniMultiSigWallet.TxAlreadyExecuted.selector);
        wallet.approveTransaction(0);
    }

    function test_Revoke_RevertIfAlreadyExecuted() public {
        _fundWallet(2 ether);

        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        wallet.approveTransaction(0);

        vm.prank(owner2);
        wallet.approveTransaction(0);

        vm.prank(owner1);
        wallet.executeTransaction(0);

        vm.prank(owner1);
        vm.expectRevert(MiniMultiSigWallet.TxAlreadyExecuted.selector);
        wallet.revokeApproval(0);
    }
}
