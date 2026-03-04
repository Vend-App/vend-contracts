// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract RewardDistributor is Ownable, Pausable {
    using SafeERC20 for IERC20;

    address internal constant NATIVE_TOKEN = address(0);

    error Unauthorized();
    error ZeroAmount();
    error ZeroAddress();
    error InvalidNativeDeposit();
    error UnexpectedNativeValue();
    error NativeTransferFailed();
    error DirectNativeDepositDisabled();

    event AdminUpdated(address indexed admin, bool enabled);
    event Deposit(address indexed token, uint256 amount);
    event RewardDistributed(address indexed to, address indexed token, uint256 amount);
    event Withdraw(address indexed token, uint256 amount, address indexed to);

    mapping(address => bool) public isAdmin;

    modifier onlyOwnerOrAdmin() {
        _onlyOwnerOrAdmin();
        _;
    }

    function _onlyOwnerOrAdmin() internal view {
        if (owner() != msg.sender && !isAdmin[msg.sender]) {
            revert Unauthorized();
        }
    }

    constructor(address initialOwner) Ownable(initialOwner) {}

    function setAdmin(address admin, bool enabled) external onlyOwner {
        isAdmin[admin] = enabled;
        emit AdminUpdated(admin, enabled);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function deposit(address token, uint256 amount) external payable whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        if (token == NATIVE_TOKEN) {
            if (msg.value != amount) revert InvalidNativeDeposit();
        } else {
            if (msg.value != 0) revert UnexpectedNativeValue();
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }

        emit Deposit(token, amount);
    }

    function distributeReward(address to, address token, uint256 amount) external onlyOwnerOrAdmin whenNotPaused {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        _transferAsset(token, to, amount);
        emit RewardDistributed(to, token, amount);
    }

    function withdraw(address token, uint256 amount, address to) external onlyOwnerOrAdmin {
        if (amount == 0) revert ZeroAmount();
        address recipient = to == address(0) ? msg.sender : to;

        _transferAsset(token, recipient, amount);
        emit Withdraw(token, amount, recipient);
    }

    receive() external payable {
        revert DirectNativeDepositDisabled();
    }

    function _transferAsset(address token, address to, uint256 amount) internal {
        if (token == NATIVE_TOKEN) {
            (bool success,) = payable(to).call{value: amount}("");
            if (!success) revert NativeTransferFailed();
            return;
        }

        IERC20(token).safeTransfer(to, amount);
    }
}
