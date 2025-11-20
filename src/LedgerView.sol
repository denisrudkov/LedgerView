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

    function classifyEntry(uint256 entryId, LedgerTypes.Category category) external {
        require(
            hasRole(CLASSIFIER_ROLE, msg.sender) || _sources[msg.sender].canAnnotate,
            "Not authorized"
        );
        require(entryId > 0 && entryId <= _entryCounter, "Invalid entry ID");

        LedgerTypes.Category oldCategory = _annotations[entryId].category;

        if (oldCategory != LedgerTypes.Category.UNCATEGORIZED) {
            _removeFromCategoryList(entryId, oldCategory);
        }

        _annotations[entryId].category = category;
        _annotations[entryId].annotatedBy = msg.sender;
        _annotations[entryId].annotatedAt = block.timestamp;

        _entriesByCategory[category].push(entryId);

        emit EntryClassified(entryId, category, msg.sender);
        emit EntryAnnotated(entryId, category, msg.sender);
    }

    function addTag(uint256 entryId, bytes32 tag) external {
        require(
            hasRole(CLASSIFIER_ROLE, msg.sender) || _sources[msg.sender].canAnnotate,
            "Not authorized"
        );
        require(entryId > 0 && entryId <= _entryCounter, "Invalid entry ID");

        _annotations[entryId].tags.push(tag);
        _entriesByTag[tag].push(entryId);

        if (_annotations[entryId].annotatedBy == address(0)) {
            _annotations[entryId].annotatedBy = msg.sender;
            _annotations[entryId].annotatedAt = block.timestamp;
        }

        emit TagAdded(entryId, tag, msg.sender);
    }

    function addNote(uint256 entryId, string calldata note) external {
        require(
            hasRole(CLASSIFIER_ROLE, msg.sender) || _sources[msg.sender].canAnnotate,
            "Not authorized"
        );
        require(entryId > 0 && entryId <= _entryCounter, "Invalid entry ID");

        _annotations[entryId].note = note;

        if (_annotations[entryId].annotatedBy == address(0)) {
            _annotations[entryId].annotatedBy = msg.sender;
            _annotations[entryId].annotatedAt = block.timestamp;
        }

        emit NoteAdded(entryId, msg.sender);
    }

    function getAnnotation(uint256 entryId) external view returns (LedgerTypes.EntryAnnotation memory) {
        return _annotations[entryId];
    }

    function getEntriesByCategory(LedgerTypes.Category category) external view returns (uint256[] memory) {
        return _entriesByCategory[category];
    }

    function getEntriesByTag(bytes32 tag) external view returns (uint256[] memory) {
        return _entriesByTag[tag];
    }

    function _removeFromCategoryList(uint256 entryId, LedgerTypes.Category category) private {
        uint256[] storage list = _entriesByCategory[category];
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] == entryId) {
                list[i] = list[list.length - 1];
                list.pop();
                break;
            }
        }
    }

    function registerIntegration(
        address integration,
        bytes32 integrationType,
        address executor,
        bool autoCreate
    ) external onlyRole(ADMIN_ROLE) {
        require(integration != address(0), "Invalid integration");

        _integrations[integration] = LedgerTypes.IntegrationConfig({
            executor: executor,
            autoCreateEntries: autoCreate,
            lastExecution: 0,
            integrationType: integrationType
        });

        emit IntegrationRegistered(integration, integrationType, executor);
    }

    function executeIntegration(
        address integration,
        LedgerTypes.EntryType entryType,
        address asset,
        uint256 amount,
        address source,
        address destination,
        bytes calldata metadata
    ) external nonReentrant returns (uint256) {
        LedgerTypes.IntegrationConfig storage config = _integrations[integration];
        require(config.executor != address(0), "Integration not registered");
        require(
            msg.sender == config.executor || hasRole(INTEGRATOR_ROLE, msg.sender),
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
            txHash: bytes32(0),
            metadata: metadata
        });

        _entriesBySource[source].push(id);
        _entriesByType[entryType].push(id);

        config.lastExecution = block.timestamp;

        emit EntryCreated(id, entryType, source, asset, amount, block.timestamp);
        emit IntegrationExecuted(integration, id, block.timestamp);

        return id;
    }

    function registerBasePayment(
        address from,
        address to,
        uint256 amount,
        bytes32 paymentRef,
        bytes calldata metadata
    ) external nonReentrant returns (uint256) {
        require(hasRole(INTEGRATOR_ROLE, msg.sender), "Not authorized");

        uint256 id = ++_entryCounter;

        bytes memory fullMetadata = abi.encode(paymentRef, metadata);

        _entries[id] = LedgerTypes.LedgerEntry({
            id: id,
            entryType: LedgerTypes.EntryType.PAYOUT,
            asset: usdc,
            amount: amount,
            source: from,
            destination: to,
            timestamp: block.timestamp,
            txHash: bytes32(0),
            metadata: fullMetadata
        });

        _entriesBySource[from].push(id);
        _entriesByType[LedgerTypes.EntryType.PAYOUT].push(id);

        emit EntryCreated(id, LedgerTypes.EntryType.PAYOUT, from, usdc, amount, block.timestamp);
        emit BasePayReceived(from, to, amount, paymentRef);

        return id;
    }

    function getIntegrationConfig(address integration) external view returns (LedgerTypes.IntegrationConfig memory) {
        return _integrations[integration];
    }

    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }
}
