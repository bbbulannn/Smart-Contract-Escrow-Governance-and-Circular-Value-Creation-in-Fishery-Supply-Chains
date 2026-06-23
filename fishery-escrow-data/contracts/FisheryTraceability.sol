// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
  TraceabilityCore (Contract A)
  Fokus: trace → evidence (tanpa procurement/escrow)
  Fitur:
   - RBAC (FISHER, LANDING, PROCESSOR, LOGISTICS, LAB)
   - Record catch, record landing
   - Split/Merge lot sederhana (lineage)
   - Anchor COA/PCR CID
   - Post ringkasan sensor (maxTempC, minutesAbove, readings)
   - Event lengkap buat scraping CSV dan hitung time-per-process (pakai block.timestamp)
*/

import "@openzeppelin/contracts/access/AccessControl.sol";

contract TraceabilityCore is AccessControl {
    bytes32 public constant FISHER_ROLE    = keccak256("FISHER");
    bytes32 public constant LANDING_ROLE   = keccak256("LANDING");
    bytes32 public constant PROCESSOR_ROLE = keccak256("PROCESSOR");
    bytes32 public constant LOGISTICS_ROLE = keccak256("LOGISTICS");
    bytes32 public constant LAB_ROLE       = keccak256("LAB");

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // ---------- LOT ----------
    struct Lot {
        uint256 id;
        string species;
        uint256 weight; // gram
        address owner;  // pemilik bisnis saat ini (sederhana)
        bool exists;
    }

    mapping(uint256 => Lot) public lots;

    // ---------- SENSOR ----------
    struct SensorRollup {
        uint32 maxTempC;
        uint32 minutesAbove;
        uint32 readings;
        uint64 lastUpdateTs;
    }
    mapping(uint256 => SensorRollup) public sensorOfLot;

    // ---------- LINEAGE ----------
    // parent -> children; child -> parent
    mapping(uint256 => uint256[]) public childrenOf;
    mapping(uint256 => uint256) public parentOf;

    // ---------- EVENTS ----------
    event CatchRecorded(uint256 indexed lotId, string species, uint256 weight, address owner, uint256 ts);
    event LandingRecorded(uint256 indexed lotId, uint256 verifiedWeight, uint256 ts);
    event SplitLot(uint256 indexed parentId, uint256[] childIds, uint256[] childWeights, uint256 ts);
    event MergeLots(uint256 indexed targetId, uint256[] sources, uint256 totalWeight, uint256 ts);
    event COAAnchored(uint256 indexed lotId, bytes32 cid, address indexed by, uint256 ts);
    event SensorSummaryPosted(uint256 indexed lotId, uint32 maxTempC, uint32 minutesAbove, uint32 readings, address indexed by, uint256 ts);

    // ---------- FUNCTIONS ----------
    function grantMany(bytes32 role, address[] calldata addrs) external onlyRole(getRoleAdmin(role)) {
        for (uint256 i=0; i<addrs.length; i++) { _grantRole(role, addrs[i]); }
    }

    // 1) Fisher mencatat tangkapan awal
    function recordCatch(uint256 lotId, string calldata species, uint256 grossWeight, address owner)
        external onlyRole(FISHER_ROLE)
    {
        require(!lots[lotId].exists, "lot exists");
        lots[lotId] = Lot({id: lotId, species: species, weight: grossWeight, owner: owner, exists: true});
        emit CatchRecorded(lotId, species, grossWeight, owner, block.timestamp);
    }

    // 2) Landing site verifikasi berat
    function recordLanding(uint256 lotId, uint256 verifiedWeight)
        external onlyRole(LANDING_ROLE)
    {
        require(lots[lotId].exists, "lot missing");
        // update berat ke hasil verifikasi
        lots[lotId].weight = verifiedWeight;
        emit LandingRecorded(lotId, verifiedWeight, block.timestamp);
    }

    // 3) Processor melakukan split; childIds dan childWeights harus sama panjang; total <= parent.weight
    function splitLot(uint256 parentId, uint256[] calldata childIds, uint256[] calldata childWeights, address newOwner)
        external onlyRole(PROCESSOR_ROLE)
    {
        require(lots[parentId].exists, "parent missing");
        require(childIds.length == childWeights.length && childIds.length > 0, "bad args");

        uint256 sum;
        for (uint256 i=0; i<childWeights.length; i++) {
            require(!lots[childIds[i]].exists, "child exists");
            lots[childIds[i]] = Lot({
                id: childIds[i],
                species: lots[parentId].species,
                weight: childWeights[i],
                owner: newOwner,
                exists: true
            });
            parentOf[childIds[i]] = parentId;
            childrenOf[parentId].push(childIds[i]);
            sum += childWeights[i];
        }
        require(sum <= lots[parentId].weight, "over weight");
        // sisa bobot tetap di parent (opsional). Biarkan apa adanya.

        emit SplitLot(parentId, childIds, childWeights, block.timestamp);
    }

    // 4) Merge beberapa lot menjadi target baru
    function mergeLots(uint256[] calldata sources, uint256 targetId, address newOwner)
        external onlyRole(PROCESSOR_ROLE)
    {
        require(!lots[targetId].exists, "target exists");
        require(sources.length >= 2, "need >=2 sources");

        string memory sp = lots[sources[0]].species;
        uint256 total;
        for (uint256 i=0; i<sources.length; i++) {
            require(lots[sources[i]].exists, "source missing");
            require(keccak256(bytes(lots[sources[i]].species)) == keccak256(bytes(sp)), "species mismatch");
            total += lots[sources[i]].weight;
            parentOf[sources[i]] = targetId; // tandai parent baru
        }

        lots[targetId] = Lot({id: targetId, species: sp, weight: total, owner: newOwner, exists: true});
        emit MergeLots(targetId, sources, total, block.timestamp);
    }

    // 5) Anchor COA / PCR dari lab atau processor
    function anchorCOA(uint256 lotId, bytes32 cid) external {
        require(hasRole(LAB_ROLE, msg.sender) || hasRole(PROCESSOR_ROLE, msg.sender), "not lab/processor");
        require(lots[lotId].exists, "lot missing");
        emit COAAnchored(lotId, cid, msg.sender, block.timestamp);
    }

    // 6) Post ringkasan sensor oleh logistics atau processor
    function postSensorSummary(uint256 lotId, uint32 maxTempC, uint32 minutesAbove, uint32 readings) external {
        require(hasRole(LOGISTICS_ROLE, msg.sender) || hasRole(PROCESSOR_ROLE, msg.sender), "not logistics/processor");
        require(lots[lotId].exists, "lot missing");
        SensorRollup storage s = sensorOfLot[lotId];
        if (maxTempC > s.maxTempC) s.maxTempC = maxTempC;
        s.minutesAbove += minutesAbove;
        s.readings += readings;
        s.lastUpdateTs = uint64(block.timestamp);
        emit SensorSummaryPosted(lotId, s.maxTempC, s.minutesAbove, s.readings, msg.sender, block.timestamp);
    }

    // ---------- VIEW HELPERS ----------
    function getLot(uint256 lotId) external view returns (Lot memory) { return lots[lotId]; }
    function getSensor(uint256 lotId) external view returns (SensorRollup memory) { return sensorOfLot[lotId]; }
    function getChildren(uint256 lotId) external view returns (uint256[] memory) { return childrenOf[lotId]; }
    function getParent(uint256 lotId) external view returns (uint256) { return parentOf[lotId]; }
}
