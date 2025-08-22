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

    function test_RegisterSource() public {
        bytes32 sourceType = keccak256("TREASURY");

        vm.prank(admin);
        vm.expectEmit(true, true, false, true);
        emit SourceRegistered(treasury, sourceType, block.timestamp);

        ledger.registerSource(treasury, sourceType, true, false);

        assertTrue(ledger.isSourceActive(treasury));

        LedgerTypes.SourceConfig memory config = ledger.getSourceConfig(treasury);
        assertTrue(config.isActive);
        assertTrue(config.canCreateEntries);
    }

    function test_RegisterSource_ThenCreateEntry() public {
        vm.prank(admin);
        ledger.registerSource(treasury, keccak256("TREASURY"), true, false);

        vm.prank(treasury);
        uint256 id = ledger.createEntry(
            LedgerTypes.EntryType.WITHDRAWAL,
            usdc,
            500e6,
            treasury,
            makeAddr("recipient"),
            keccak256("tx2"),
            ""
        );

        assertEq(id, 1);
    }

    function test_RemoveSource() public {
        vm.startPrank(admin);
        ledger.registerSource(treasury, keccak256("TREASURY"), true, false);
        ledger.removeSource(treasury);
        vm.stopPrank();

        assertFalse(ledger.isSourceActive(treasury));
    }

    function test_ClassifyEntry() public {
        vm.prank(operator);
        ledger.createEntry(LedgerTypes.EntryType.PAYOUT, usdc, 2000e6, treasury, makeAddr("employee"), keccak256("tx3"), "");

        vm.prank(classifier);
        vm.expectEmit(true, true, true, false);
        emit EntryClassified(1, LedgerTypes.Category.PAYROLL, classifier);

        ledger.classifyEntry(1, LedgerTypes.Category.PAYROLL);

        LedgerTypes.EntryAnnotation memory annotation = ledger.getAnnotation(1);
        assertEq(uint256(annotation.category), uint256(LedgerTypes.Category.PAYROLL));
    }

    function test_AddTag() public {
        vm.prank(operator);
        ledger.createEntry(LedgerTypes.EntryType.PAYOUT, usdc, 1500e6, treasury, makeAddr("contractor"), keccak256("tx4"), "");

        bytes32 tag = keccak256("Q3-2025");

        vm.prank(classifier);
        ledger.addTag(1, tag);

        uint256[] memory taggedEntries = ledger.getEntriesByTag(tag);
        assertEq(taggedEntries.length, 1);
    }

    function test_AddNote() public {
        vm.prank(operator);
        ledger.createEntry(LedgerTypes.EntryType.REVENUE, usdc, 50000e6, treasury, makeAddr("grantee"), keccak256("tx5"), "");

        vm.prank(classifier);
        ledger.addNote(1, "Ecosystem grant for protocol development");

        LedgerTypes.EntryAnnotation memory annotation = ledger.getAnnotation(1);
        assertEq(annotation.note, "Ecosystem grant for protocol development");
    }

    function test_GetEntriesByCategory() public {
        vm.startPrank(operator);
        ledger.createEntry(LedgerTypes.EntryType.PAYOUT, usdc, 1000e6, treasury, address(0), bytes32(0), "");
        ledger.createEntry(LedgerTypes.EntryType.PAYOUT, usdc, 2000e6, treasury, address(0), bytes32(0), "");
        vm.stopPrank();

        vm.startPrank(classifier);
        ledger.classifyEntry(1, LedgerTypes.Category.PAYROLL);
        ledger.classifyEntry(2, LedgerTypes.Category.PAYROLL);
        vm.stopPrank();

        uint256[] memory payrollEntries = ledger.getEntriesByCategory(LedgerTypes.Category.PAYROLL);
        assertEq(payrollEntries.length, 2);
    }

    function test_ReclassifyEntry() public {
        vm.prank(operator);
        ledger.createEntry(LedgerTypes.EntryType.PAYOUT, usdc, 1000e6, treasury, address(0), bytes32(0), "");

        vm.startPrank(classifier);
        ledger.classifyEntry(1, LedgerTypes.Category.OPERATIONS);
        ledger.classifyEntry(1, LedgerTypes.Category.PAYROLL);
        vm.stopPrank();

        uint256[] memory opsEntries = ledger.getEntriesByCategory(LedgerTypes.Category.OPERATIONS);
        assertEq(opsEntries.length, 0);

        uint256[] memory payrollEntries = ledger.getEntriesByCategory(LedgerTypes.Category.PAYROLL);
        assertEq(payrollEntries.length, 1);
    }
}
