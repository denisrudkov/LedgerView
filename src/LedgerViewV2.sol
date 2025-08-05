// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LedgerView.sol";

contract LedgerViewV2 is LedgerView {
    uint256 private _totalVolume;
    mapping(address => uint256) private _assetVolumes;

    event VolumeUpdated(address indexed asset, uint256 newVolume, uint256 totalVolume);

    function createEntryV2(
        LedgerTypes.EntryType entryType,
        address asset,
        uint256 amount,
        address source,
        address destination,
        bytes32 txHash,
        bytes calldata metadata
    ) external nonReentrant returns (uint256) {
        require(
            hasRole(OPERATOR_ROLE, msg.sender) || _sources[msg.sender].canCreateEntries,
            "Not authorized"
        );

        uint256 id = _createEntryInternal(entryType, asset, amount, source, destination, txHash, metadata);

        _totalVolume += amount;
        _assetVolumes[asset] += amount;

        emit VolumeUpdated(asset, _assetVolumes[asset], _totalVolume);

        return id;
    }

    function _createEntryInternal(
        LedgerTypes.EntryType entryType,
        address asset,
        uint256 amount,
        address source,
        address destination,
        bytes32 txHash,
        bytes calldata metadata
    ) private returns (uint256) {
        uint256 id = ++_entryCounter;

        _entries[id] = LedgerTypes.LedgerEntry({
            id: id,
            entryType: entryType,
            asset: asset,
            amount: amount,
            source: source,
            destination: destination,
            timestamp: block.timestamp,
            txHash: txHash,
            metadata: metadata
        });

        _entriesBySource[source].push(id);
        _entriesByType[entryType].push(id);

        emit EntryCreated(id, entryType, source, asset, amount, block.timestamp);

        return id;
    }

    function getTotalVolume() external view returns (uint256) {
        return _totalVolume;
    }

    function getAssetVolume(address asset) external view returns (uint256) {
        return _assetVolumes[asset];
    }

    function version() external pure override returns (string memory) {
        return "2.0.0";
    }
}
