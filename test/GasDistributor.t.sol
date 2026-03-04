// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {GasDistributor} from "../src/GasDistributor.sol";

contract GasDistributorTest is Test {
    event AdminUpdated(address indexed admin, bool enabled);
    event Deposit(address indexed caller, uint256 amount);
    event GasDistributed(address indexed to, uint256 amount);
    event Withdraw(address indexed caller, uint256 amount, address indexed to);

    GasDistributor internal distributor;

    address internal owner = makeAddr("owner");
    address internal admin = makeAddr("admin");
    address internal user = makeAddr("user");
    address internal recipient = makeAddr("recipient");

    uint256 internal constant GAS_AMOUNT = 1 ether;

    function setUp() external {
        distributor = new GasDistributor(owner);
    }

    function testSetAdminByOwner() external {
        vm.expectEmit(true, false, false, true);
        emit AdminUpdated(admin, true);

        vm.prank(owner);
        distributor.setAdmin(admin, true);

        assertTrue(distributor.isAdmin(admin));
    }

    function testCannotSetAdminIfNotOwner() external {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        vm.prank(user);
        distributor.setAdmin(admin, true);
    }

    function testDepositNativeEmitsEvent() external {
        vm.deal(user, GAS_AMOUNT);

        vm.expectEmit(true, false, false, true);
        emit Deposit(user, GAS_AMOUNT);

        vm.prank(user);
        distributor.deposit{value: GAS_AMOUNT}();

        assertEq(address(distributor).balance, GAS_AMOUNT);
    }

    function testDepositNativeRevertsOnZeroValue() external {
        vm.expectRevert(abi.encodeWithSelector(GasDistributor.ZeroAmount.selector));
        vm.prank(user);
        distributor.deposit();
    }

    function testAdminCanDistributeGas() external {
        _setAdmin();
        _depositNative(owner, GAS_AMOUNT);

        uint256 startBalance = recipient.balance;
        vm.expectEmit(true, false, false, true);
        emit GasDistributed(recipient, GAS_AMOUNT);

        vm.prank(admin);
        distributor.distributeGas(recipient, GAS_AMOUNT);

        assertEq(recipient.balance, startBalance + GAS_AMOUNT);
    }

    function testFuzz_Deposit(uint256 amount) external {
        vm.assume(amount > 0 && amount <= 100 ether);
        vm.deal(user, amount);

        vm.expectEmit(true, false, false, true);
        emit Deposit(user, amount);

        vm.prank(user);
        distributor.deposit{value: amount}();

        assertEq(address(distributor).balance, amount);
    }

    function testFuzz_DepositRevertsOnZeroValue(uint256 amount) external {
        vm.assume(amount == 0);

        vm.expectRevert(abi.encodeWithSelector(GasDistributor.ZeroAmount.selector));
        vm.prank(user);
        distributor.deposit{value: amount}();
    }

    function testFuzz_AdminCanDistributeGas(uint256 amount) external {
        vm.assume(amount > 0 && amount <= 100 ether);
        _setAdmin();
        _depositNative(owner, amount);

        uint256 startBalance = recipient.balance;
        vm.expectEmit(true, false, false, true);
        emit GasDistributed(recipient, amount);

        vm.prank(admin);
        distributor.distributeGas(recipient, amount);

        assertEq(recipient.balance, startBalance + amount);
    }

    function testFuzz_DistributeGasRevertsOnInsufficientBalance(uint256 amount) external {
        vm.assume(amount > 0 && amount <= 100 ether);
        _setAdmin();
        _depositNative(owner, amount);
        uint256 tooMuch = amount + 1;

        vm.expectRevert(abi.encodeWithSelector(GasDistributor.InsufficientBalance.selector));
        vm.prank(admin);
        distributor.distributeGas(recipient, tooMuch);
    }

    function testNonAdminCannotDistributeOrWithdraw() external {
        vm.expectRevert(abi.encodeWithSelector(GasDistributor.Unauthorized.selector));
        vm.prank(user);
        distributor.distributeGas(recipient, GAS_AMOUNT);

        vm.expectRevert(abi.encodeWithSelector(GasDistributor.Unauthorized.selector));
        vm.prank(user);
        distributor.withdraw(GAS_AMOUNT, recipient);
    }

    function testWithdrawDefaultsToMsgSenderWhenToIsZero() external {
        _setAdmin();
        _depositNative(owner, GAS_AMOUNT);

        uint256 startBalance = admin.balance;
        vm.expectEmit(true, false, true, true);
        emit Withdraw(admin, GAS_AMOUNT, admin);

        vm.prank(admin);
        distributor.withdraw(GAS_AMOUNT, address(0));

        assertEq(admin.balance, startBalance + GAS_AMOUNT);
    }

    function testFuzz_Withdraw(uint256 amount) external {
        vm.assume(amount > 0 && amount <= 100 ether);
        _setAdmin();
        _depositNative(owner, amount);

        uint256 startBalance = admin.balance;
        vm.expectEmit(true, false, true, true);
        emit Withdraw(admin, amount, admin);

        vm.prank(admin);
        distributor.withdraw(amount, address(0));

        assertEq(admin.balance, startBalance + amount);
    }

    function testFuzz_WithdrawRevertsOnInsufficientBalance(uint256 amount) external {
        vm.assume(amount > 0 && amount <= 100 ether);
        _setAdmin();
        _depositNative(owner, amount);
        uint256 tooMuch = amount + 1;

        vm.expectRevert(abi.encodeWithSelector(GasDistributor.InsufficientBalance.selector));
        vm.prank(admin);
        distributor.withdraw(tooMuch, recipient);
    }

    function testPauseBlocksDepositAndDistribute() external {
        _setAdmin();

        vm.prank(owner);
        distributor.pause();

        vm.deal(user, GAS_AMOUNT);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(user);
        distributor.deposit{value: GAS_AMOUNT}();

        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(admin);
        distributor.distributeGas(recipient, 1);
    }

    function testWithdrawWorksWhilePaused() external {
        _setAdmin();
        _depositNative(owner, GAS_AMOUNT);

        vm.prank(owner);
        distributor.pause();

        uint256 startBalance = admin.balance;
        vm.expectEmit(true, false, true, true);
        emit Withdraw(admin, GAS_AMOUNT, admin);

        vm.prank(admin);
        distributor.withdraw(GAS_AMOUNT, address(0));

        assertEq(admin.balance, startBalance + GAS_AMOUNT);
    }

    function testWithdrawRevertsOnInsufficientBalance() external {
        _setAdmin();

        vm.expectRevert(abi.encodeWithSelector(GasDistributor.InsufficientBalance.selector));
        vm.prank(admin);
        distributor.withdraw(GAS_AMOUNT, recipient);
    }

    function testReceiveReverts() external {
        vm.deal(user, GAS_AMOUNT);

        vm.expectRevert(abi.encodeWithSelector(GasDistributor.DirectNativeDepositDisabled.selector));
        vm.prank(user);
        (bool success,) = payable(address(distributor)).call{value: GAS_AMOUNT}("");
        success;
    }

    function _setAdmin() internal {
        vm.prank(owner);
        distributor.setAdmin(admin, true);
    }

    function _depositNative(address from, uint256 amount) internal {
        vm.deal(from, amount);
        vm.prank(from);
        distributor.deposit{value: amount}();
    }
}
