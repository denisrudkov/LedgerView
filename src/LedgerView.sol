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
}
