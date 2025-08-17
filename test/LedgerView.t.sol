// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/LedgerView.sol";
import "../src/LedgerViewV2.sol";
import "../src/types/LedgerTypes.sol";

contract LedgerViewTest is Test {
    LedgerView public ledger;
    LedgerView public implementation;
    address public admin;
    address public operator;
    address public classifier;
    address public treasury;
    address public usdc;

    event EntryCreated(
        uint256 indexed id,
        LedgerTypes.EntryType indexed entryType,
        address indexed source,
        address asset,
        uint256 amount,
        uint256 timestamp
    );

    event SourceRegistered(
        address indexed source,
        bytes32 indexed sourceType,
        uint256 timestamp
    );

    event EntryClassified(
        uint256 indexed entryId,
        LedgerTypes.Category indexed category,
        address indexed classifier
    );

    function setUp() public {
        admin = makeAddr("admin");
        operator = makeAddr("operator");
        classifier = makeAddr("classifier");
        treasury = makeAddr("treasury");
        usdc = makeAddr("usdc");

        implementation = new LedgerView();

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeCall(LedgerView.initialize, (admin, usdc))
        );

        ledger = LedgerView(address(proxy));

        vm.startPrank(admin);
        ledger.grantRole(ledger.OPERATOR_ROLE(), operator);
        ledger.grantRole(ledger.CLASSIFIER_ROLE(), classifier);
        vm.stopPrank();
    }

    function test_Initialize() public view {
        assertTrue(ledger.hasRole(ledger.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(ledger.hasRole(ledger.ADMIN_ROLE(), admin));
        assertEq(ledger.usdc(), usdc);
        assertEq(ledger.version(), "1.0.0");
    }

    function test_CreateEntry() public {
        vm.prank(operator);

        vm.expectEmit(true, true, true, true);
        emit EntryCreated(1, LedgerTypes.EntryType.DEPOSIT, treasury, usdc, 1000e6, block.timestamp);

        uint256 id = ledger.createEntry(
            LedgerTypes.EntryType.DEPOSIT,
            usdc,
            1000e6,
            treasury,
            address(ledger),
            keccak256("tx1"),
            ""
        );

        assertEq(id, 1);
        assertEq(ledger.getEntryCount(), 1);

        LedgerTypes.LedgerEntry memory entry = ledger.getEntry(1);
        assertEq(entry.amount, 1000e6);
        assertEq(entry.source, treasury);
    }

    function test_CreateEntry_Unauthorized() public {
        address random = makeAddr("random");
        vm.prank(random);
        vm.expectRevert("Not authorized");
        ledger.createEntry(
            LedgerTypes.EntryType.DEPOSIT,
            usdc,
            1000e6,
            treasury,
            address(ledger),
            keccak256("tx1"),
            ""
        );
    }

    function test_GetEntriesBySource() public {
        vm.startPrank(operator);
        ledger.createEntry(LedgerTypes.EntryType.DEPOSIT, usdc, 100e6, treasury, address(0), bytes32(0), "");
        ledger.createEntry(LedgerTypes.EntryType.WITHDRAWAL, usdc, 50e6, treasury, address(0), bytes32(0), "");
        ledger.createEntry(LedgerTypes.EntryType.DEPOSIT, usdc, 200e6, makeAddr("other"), address(0), bytes32(0), "");
        vm.stopPrank();

        uint256[] memory entries = ledger.getEntriesBySource(treasury);
        assertEq(entries.length, 2);
    }

    function test_GetEntriesByType() public {
        vm.startPrank(operator);
        ledger.createEntry(LedgerTypes.EntryType.DEPOSIT, usdc, 100e6, treasury, address(0), bytes32(0), "");
        ledger.createEntry(LedgerTypes.EntryType.DEPOSIT, usdc, 200e6, treasury, address(0), bytes32(0), "");
        ledger.createEntry(LedgerTypes.EntryType.WITHDRAWAL, usdc, 50e6, treasury, address(0), bytes32(0), "");
        vm.stopPrank();

        uint256[] memory deposits = ledger.getEntriesByType(LedgerTypes.EntryType.DEPOSIT);
        assertEq(deposits.length, 2);
    }
}
