// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Usage:
//   source .env
//   forge script script/UpdateGasDistributorOwner.s.sol:UpdateGasDistributorOwnerScript --rpc-url glue --broadcast
//
// Required env vars:
// - PRIVATE_KEY
// - GAS_DISTRIBUTOR_ADDRESS
// - OWNER_ADDRESS

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

interface IGasDistributorOwner {
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
}

contract UpdateGasDistributorOwnerScript is Script {
    function run() external {
        uint256 signerPrivateKey = vm.envUint("PRIVATE_KEY");
        address signer = vm.addr(signerPrivateKey);
        address gasDistributor = vm.envAddress("GAS_DISTRIBUTOR_ADDRESS");
        address newOwner = vm.envAddress("OWNER_ADDRESS");

        console2.log("Updating GasDistributor owner");
        console2.log("Chain ID:", block.chainid);
        console2.log("Signer:", signer);
        console2.log("GasDistributor:", gasDistributor);
        console2.log("New owner:", newOwner);

        require(IGasDistributorOwner(gasDistributor).owner() == signer, "Signer is not owner");

        vm.startBroadcast(signerPrivateKey);
        IGasDistributorOwner(gasDistributor).transferOwnership(newOwner);
        vm.stopBroadcast();
    }
}
