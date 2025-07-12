// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./types/LedgerTypes.sol";
import "./interfaces/ILedgerModule.sol";
import "./interfaces/IRegistryModule.sol";
import "./interfaces/IClassifierModule.sol";
import "./interfaces/IIntegrationModule.sol";

contract LedgerView is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    ILedgerModule,
    IRegistryModule,
    IClassifierModule,
    IIntegrationModule
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant CLASSIFIER_ROLE = keccak256("CLASSIFIER_ROLE");
    bytes32 public constant INTEGRATOR_ROLE = keccak256("INTEGRATOR_ROLE");

    uint256 internal _entryCounter;
    mapping(uint256 => LedgerTypes.LedgerEntry) internal _entries;
    mapping(uint256 => LedgerTypes.EntryAnnotation) internal _annotations;
    mapping(address => uint256[]) internal _entriesBySource;
    mapping(LedgerTypes.EntryType => uint256[]) internal _entriesByType;
    mapping(LedgerTypes.Category => uint256[]) internal _entriesByCategory;
    mapping(bytes32 => uint256[]) internal _entriesByTag;

    mapping(address => LedgerTypes.SourceConfig) internal _sources;
    address[] internal _activeSourceList;
    mapping(address => uint256) internal _sourceIndex;

    mapping(address => LedgerTypes.IntegrationConfig) internal _integrations;

    address public usdc;

    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address _usdc) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
        _grantRole(CLASSIFIER_ROLE, admin);
        _grantRole(INTEGRATOR_ROLE, admin);

        usdc = _usdc;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(ADMIN_ROLE) {}

    function createEntry(
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

    function getEntry(uint256 id) external view returns (LedgerTypes.LedgerEntry memory) {
        require(id > 0 && id <= _entryCounter, "Invalid entry ID");
        return _entries[id];
    }

    function getEntryCount() external view returns (uint256) {
        return _entryCounter;
    }

    function getEntriesBySource(address source) external view returns (uint256[] memory) {
        return _entriesBySource[source];
    }

    function getEntriesByType(LedgerTypes.EntryType entryType) external view returns (uint256[] memory) {
        return _entriesByType[entryType];
    }

    function registerSource(
        address source,
        bytes32 sourceType,
        bool canCreateEntries,
        bool canAnnotate
    ) external onlyRole(ADMIN_ROLE) {
        require(source != address(0), "Invalid source");
        require(!_sources[source].isActive, "Already registered");

        _sources[source] = LedgerTypes.SourceConfig({
            isActive: true,
            canCreateEntries: canCreateEntries,
            canAnnotate: canAnnotate,
            registeredAt: block.timestamp,
            sourceType: sourceType
        });

        _sourceIndex[source] = _activeSourceList.length;
        _activeSourceList.push(source);

        emit SourceRegistered(source, sourceType, block.timestamp);
    }

    function removeSource(address source) external onlyRole(ADMIN_ROLE) {
        require(_sources[source].isActive, "Not registered");

        _sources[source].isActive = false;

        uint256 index = _sourceIndex[source];
        uint256 lastIndex = _activeSourceList.length - 1;

        if (index != lastIndex) {
            address lastSource = _activeSourceList[lastIndex];
            _activeSourceList[index] = lastSource;
            _sourceIndex[lastSource] = index;
        }
        _activeSourceList.pop();

        emit SourceRemoved(source, block.timestamp);
    }

    function updateSourceConfig(
        address source,
        bool canCreateEntries,
        bool canAnnotate
    ) external onlyRole(ADMIN_ROLE) {
        require(_sources[source].isActive, "Not registered");

        _sources[source].canCreateEntries = canCreateEntries;
        _sources[source].canAnnotate = canAnnotate;

        emit SourceConfigUpdated(source, canCreateEntries, canAnnotate);
    }

    function isSourceActive(address source) external view returns (bool) {
        return _sources[source].isActive;
    }

    function getSourceConfig(address source) external view returns (LedgerTypes.SourceConfig memory) {
        return _sources[source];
    }

    function getActiveSources() external view returns (address[] memory) {
        return _activeSourceList;
    }
}
