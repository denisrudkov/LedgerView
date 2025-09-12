// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/LedgerView.sol";
import "../src/LedgerViewV2.sol";

contract UpgradeLedgerView is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        LedgerViewV2 newImplementation = new LedgerViewV2();

        LedgerView proxy = LedgerView(proxyAddress);
        proxy.upgradeTo(address(newImplementation));

        vm.stopBroadcast();

        console.log("New implementation:", address(newImplementation));
        console.log("Proxy upgraded:", proxyAddress);
    }
}
