// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../types/LedgerTypes.sol";

interface IIntegrationModule {
    event IntegrationRegistered(address indexed integration, bytes32 indexed integrationType, address executor);
    event IntegrationExecuted(address indexed integration, uint256 indexed entryId, uint256 timestamp);
    event BasePayReceived(address indexed from, address indexed to, uint256 amount, bytes32 paymentRef);

    function registerIntegration(address integration, bytes32 integrationType, address executor, bool autoCreate) external;
    function executeIntegration(address integration, LedgerTypes.EntryType entryType, address asset, uint256 amount, address source, address destination, bytes calldata metadata) external returns (uint256);
    function registerBasePayment(address from, address to, uint256 amount, bytes32 paymentRef, bytes calldata metadata) external returns (uint256);
    function getIntegrationConfig(address integration) external view returns (LedgerTypes.IntegrationConfig memory);
}
