// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/LedgerView.sol";

contract DeployLedgerView is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address usdc = vm.envOr("USDC_ADDRESS", address(0));

        if (usdc == address(0)) {
            if (block.chainid == 84532) {
                usdc = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
            } else if (block.chainid == 8453) {
                usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
            }
        }

        vm.startBroadcast(deployerPrivateKey);

        LedgerView implementation = new LedgerView();

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeCall(LedgerView.initialize, (admin, usdc))
        );

        vm.stopBroadcast();

        string memory output = string(abi.encodePacked(
            '{"implementation":"', vm.toString(address(implementation)),
            '","proxy":"', vm.toString(address(proxy)),
            '","admin":"', vm.toString(admin),
            '","usdc":"', vm.toString(usdc),
            '","chainId":', vm.toString(block.chainid), '}'
        ));

        vm.writeFile("./deployments/latest.json", output);

        console.log("Implementation:", address(implementation));
        console.log("Proxy:", address(proxy));
    }
}
