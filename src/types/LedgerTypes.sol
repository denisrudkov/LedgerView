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
}
