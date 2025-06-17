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
}
