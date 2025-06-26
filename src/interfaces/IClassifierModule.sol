// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../types/LedgerTypes.sol";

interface IClassifierModule {
    event EntryClassified(uint256 indexed entryId, LedgerTypes.Category indexed category, address indexed classifier);
    event TagAdded(uint256 indexed entryId, bytes32 indexed tag, address indexed addedBy);
    event NoteAdded(uint256 indexed entryId, address indexed addedBy);

    function classifyEntry(uint256 entryId, LedgerTypes.Category category) external;
    function addTag(uint256 entryId, bytes32 tag) external;
    function addNote(uint256 entryId, string calldata note) external;
    function getAnnotation(uint256 entryId) external view returns (LedgerTypes.EntryAnnotation memory);
    function getEntriesByCategory(LedgerTypes.Category category) external view returns (uint256[] memory);
    function getEntriesByTag(bytes32 tag) external view returns (uint256[] memory);
}
