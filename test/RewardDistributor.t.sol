// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {RewardDistributor} from "../src/RewardDistributor.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract RewardDistributorTest is Test {
    event AdminUpdated(address indexed admin, bool enabled);
    event Deposit(address indexed token, uint256 amount);
    event RewardDistributed(address indexed to, address indexed token, uint256 amount);
    event Withdraw(address indexed token, uint256 amount, address indexed to);

    RewardDistributor internal distributor;
    MockERC20 internal token;

    address internal owner = makeAddr("owner");
    address internal admin = makeAddr("admin");
    address internal user = makeAddr("user");
    address internal recipient = makeAddr("recipient");

    uint256 internal constant NATIVE_REWARD_AMOUNT = 1 ether;
    uint256 internal constant TOKEN_REWARD_AMOUNT = 1_000e18;

    function setUp() external {
        distributor = new RewardDistributor(owner);
        token = new MockERC20();
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

    function testDepositErc20EmitsEventAndTransfers() external {
        token.mint(user, TOKEN_REWARD_AMOUNT);

        vm.startPrank(user);
        token.approve(address(distributor), TOKEN_REWARD_AMOUNT);

        vm.expectEmit(true, false, false, true);
        emit Deposit(address(token), TOKEN_REWARD_AMOUNT);
        distributor.deposit(address(token), TOKEN_REWARD_AMOUNT);
        vm.stopPrank();

        assertEq(token.balanceOf(address(distributor)), TOKEN_REWARD_AMOUNT);
    }

    function testDepositNativeEmitsEvent() external {
        vm.deal(user, NATIVE_REWARD_AMOUNT);

        vm.expectEmit(true, false, false, true);
        emit Deposit(address(0), NATIVE_REWARD_AMOUNT);

        vm.prank(user);
        distributor.deposit{value: NATIVE_REWARD_AMOUNT}(address(0), NATIVE_REWARD_AMOUNT);

        assertEq(address(distributor).balance, NATIVE_REWARD_AMOUNT);
    }

    function testDepositNativeRevertsOnWrongValue() external {
        vm.deal(user, NATIVE_REWARD_AMOUNT);

        vm.expectRevert(abi.encodeWithSelector(RewardDistributor.InvalidNativeDeposit.selector));
        vm.prank(user);
        distributor.deposit{value: NATIVE_REWARD_AMOUNT - 1}(address(0), NATIVE_REWARD_AMOUNT);
    }

    function testDepositErc20RevertsIfMsgValueProvided() external {
        token.mint(user, TOKEN_REWARD_AMOUNT);
        vm.deal(user, 1);

        vm.startPrank(user);
        token.approve(address(distributor), TOKEN_REWARD_AMOUNT);

        vm.expectRevert(abi.encodeWithSelector(RewardDistributor.UnexpectedNativeValue.selector));
        distributor.deposit{value: 1}(address(token), TOKEN_REWARD_AMOUNT);
        vm.stopPrank();
    }

    function testAdminCanDistributeErc20() external {
        _setAdmin();
        _depositErc20(owner, TOKEN_REWARD_AMOUNT);

        vm.expectEmit(true, true, false, true);
        emit RewardDistributed(recipient, address(token), TOKEN_REWARD_AMOUNT);

        vm.prank(admin);
        distributor.distributeReward(recipient, address(token), TOKEN_REWARD_AMOUNT);

        assertEq(token.balanceOf(recipient), TOKEN_REWARD_AMOUNT);
    }

    function testAdminCanDistributeNative() external {
        _setAdmin();
        _depositNative(owner, NATIVE_REWARD_AMOUNT);

        uint256 startBalance = recipient.balance;
        vm.expectEmit(true, true, false, true);
        emit RewardDistributed(recipient, address(0), NATIVE_REWARD_AMOUNT);

        vm.prank(admin);
        distributor.distributeReward(recipient, address(0), NATIVE_REWARD_AMOUNT);

        assertEq(recipient.balance, startBalance + NATIVE_REWARD_AMOUNT);
    }

    function testNonAdminCannotDistributeOrWithdraw() external {
        vm.expectRevert(abi.encodeWithSelector(RewardDistributor.Unauthorized.selector));
        vm.prank(user);
        distributor.distributeReward(recipient, address(token), TOKEN_REWARD_AMOUNT);

        vm.expectRevert(abi.encodeWithSelector(RewardDistributor.Unauthorized.selector));
        vm.prank(user);
        distributor.withdraw(address(token), TOKEN_REWARD_AMOUNT, recipient);
    }

    function testWithdrawDefaultsToMsgSenderWhenToIsZero() external {
        _setAdmin();
        _depositErc20(owner, TOKEN_REWARD_AMOUNT);

        vm.expectEmit(true, false, true, true);
        emit Withdraw(address(token), TOKEN_REWARD_AMOUNT, admin);

        vm.prank(admin);
        distributor.withdraw(address(token), TOKEN_REWARD_AMOUNT, address(0));

        assertEq(token.balanceOf(admin), TOKEN_REWARD_AMOUNT);
    }

    function testPauseBlocksDepositAndDistribute() external {
        _setAdmin();

        vm.prank(owner);
        distributor.pause();

        vm.deal(user, NATIVE_REWARD_AMOUNT);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(user);
        distributor.deposit{value: NATIVE_REWARD_AMOUNT}(address(0), NATIVE_REWARD_AMOUNT);

        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(admin);
        distributor.distributeReward(recipient, address(0), 1);
    }

    function testReceiveReverts() external {
        vm.deal(user, NATIVE_REWARD_AMOUNT);

        vm.expectRevert(abi.encodeWithSelector(RewardDistributor.DirectNativeDepositDisabled.selector));
        vm.prank(user);
        (bool success,) = payable(address(distributor)).call{value: NATIVE_REWARD_AMOUNT}("");
        success;
    }

    function _setAdmin() internal {
        vm.prank(owner);
        distributor.setAdmin(admin, true);
    }

    function _depositErc20(address from, uint256 amount) internal {
        token.mint(from, amount);
        vm.startPrank(from);
        token.approve(address(distributor), amount);
        distributor.deposit(address(token), amount);
        vm.stopPrank();
    }

    function _depositNative(address from, uint256 amount) internal {
        vm.deal(from, amount);
        vm.prank(from);
        distributor.deposit{value: amount}(address(0), amount);
    }
}
