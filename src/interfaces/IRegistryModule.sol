// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../types/LedgerTypes.sol";

interface IRegistryModule {
    event SourceRegistered(address indexed source, bytes32 indexed sourceType, uint256 timestamp);
    event SourceRemoved(address indexed source, uint256 timestamp);
    event SourceConfigUpdated(address indexed source, bool canCreateEntries, bool canAnnotate);

    function registerSource(address source, bytes32 sourceType, bool canCreateEntries, bool canAnnotate) external;
    function removeSource(address source) external;
    function updateSourceConfig(address source, bool canCreateEntries, bool canAnnotate) external;
    function isSourceActive(address source) external view returns (bool);
    function getSourceConfig(address source) external view returns (LedgerTypes.SourceConfig memory);
    function getActiveSources() external view returns (address[] memory);
}
