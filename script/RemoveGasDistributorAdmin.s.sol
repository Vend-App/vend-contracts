// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Usage:
//   source .env
//   forge script script/RemoveGasDistributorAdmin.s.sol:RemoveGasDistributorAdminScript --rpc-url glue --broadcast
//
// Required env vars:
// - PRIVATE_KEY
// - GAS_DISTRIBUTOR_ADDRESS
// - ADMIN_ADDRESS

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

interface IGasDistributorAdmin {
    function setAdmin(address admin, bool enabled) external;
    function isAdmin(address admin) external view returns (bool);
}

contract RemoveGasDistributorAdminScript is Script {
    function run() external {
        uint256 signerPrivateKey = vm.envUint("PRIVATE_KEY");
        address signer = vm.addr(signerPrivateKey);
        address gasDistributor = vm.envAddress("GAS_DISTRIBUTOR_ADDRESS");
        address adminToRemove = vm.envAddress("ADMIN_ADDRESS");

        console2.log("Removing GasDistributor admin");
        console2.log("Chain ID:", block.chainid);
        console2.log("Signer:", signer);
        console2.log("GasDistributor:", gasDistributor);
        console2.log("Admin to remove:", adminToRemove);

        vm.startBroadcast(signerPrivateKey);
        IGasDistributorAdmin(gasDistributor).setAdmin(adminToRemove, false);
        vm.stopBroadcast();

        bool enabled = IGasDistributorAdmin(gasDistributor).isAdmin(adminToRemove);
        console2.log("Admin enabled:", enabled);
    }
}
