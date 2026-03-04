// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract GasDistributor is Ownable, Pausable, ReentrancyGuard {
    error Unauthorized();
    error ZeroAmount();
    error ZeroAddress();
    error NativeTransferFailed();
    error InsufficientBalance();
    error DirectNativeDepositDisabled();

    event AdminUpdated(address indexed admin, bool enabled);
    event Deposit(address indexed caller, uint256 amount);
    event GasDistributed(address indexed to, uint256 amount);
    event Withdraw(address indexed caller, uint256 amount, address indexed to);

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

    function deposit() external payable whenNotPaused nonReentrant {
        if (msg.value == 0) revert ZeroAmount();
        emit Deposit(msg.sender, msg.value);
    }

    function distributeGas(address to, uint256 amount) external onlyOwnerOrAdmin whenNotPaused nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        _transferNative(to, amount);
        emit GasDistributed(to, amount);
    }

    /// @notice Withdraws funds even while paused to support emergency admin recovery.
    function withdraw(uint256 amount, address to) external onlyOwnerOrAdmin nonReentrant {
        if (amount == 0) revert ZeroAmount();
        address recipient = to == address(0) ? msg.sender : to;

        _transferNative(recipient, amount);
        emit Withdraw(msg.sender, amount, recipient);
    }

    receive() external payable {
        revert DirectNativeDepositDisabled();
    }

    function _transferNative(address to, uint256 amount) internal {
        if (address(this).balance < amount) revert InsufficientBalance();
        (bool success,) = payable(to).call{value: amount}("");
        if (!success) revert NativeTransferFailed();
    }
}
