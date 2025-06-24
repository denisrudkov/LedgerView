// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../types/LedgerTypes.sol";

interface ILedgerModule {
    event EntryCreated(
        uint256 indexed id,
        LedgerTypes.EntryType indexed entryType,
        address indexed source,
        address asset,
        uint256 amount,
        uint256 timestamp
    );

    event EntryAnnotated(
        uint256 indexed id,
        LedgerTypes.Category indexed category,
        address indexed annotatedBy
    );

    function createEntry(
        LedgerTypes.EntryType entryType,
        address asset,
        uint256 amount,
        address source,
        address destination,
        bytes32 txHash,
        bytes calldata metadata
    ) external returns (uint256);

    function getEntry(uint256 id) external view returns (LedgerTypes.LedgerEntry memory);
    function getEntryCount() external view returns (uint256);
    function getEntriesBySource(address source) external view returns (uint256[] memory);
    function getEntriesByType(LedgerTypes.EntryType entryType) external view returns (uint256[] memory);
}
