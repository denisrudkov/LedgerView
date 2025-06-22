// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library LedgerTypes {
    enum EntryType {
        DEPOSIT,
        WITHDRAWAL,
        TRANSFER,
        PAYOUT,
        REVENUE,
        REFUND
    }

    enum Category {
        UNCATEGORIZED,
        PAYROLL,
        GRANT,
        OPERATIONS,
        TREASURY_MOVE,
        REVENUE_SHARE,
        REFUND,
        INVESTMENT,
        FEE
    }

    struct LedgerEntry {
        uint256 id;
        EntryType entryType;
        address asset;
        uint256 amount;
        address source;
        address destination;
        uint256 timestamp;
        bytes32 txHash;
        bytes metadata;
    }

    struct EntryAnnotation {
        Category category;
        bytes32[] tags;
        string note;
        address annotatedBy;
        uint256 annotatedAt;
    }

    struct SourceConfig {
        bool isActive;
        bool canCreateEntries;
        bool canAnnotate;
        uint256 registeredAt;
        bytes32 sourceType;
    }

    struct IntegrationConfig {
        address executor;
        bool autoCreateEntries;
        uint256 lastExecution;
        bytes32 integrationType;
    }
}
