// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract CircularEscrowFishery {
    address public buyer;
    address public seller;
    address public oracle;
    
    uint256 public totalEscrowAmount;
    bool public isFundsReleased;
    bool public isFundsRefunded;
    
    enum RiskStatus { Low, Medium, High, Critical }
    RiskStatus public currentRisk;

    event FundsDeposited(address indexed buyer, uint256 amount);
    event FundsReleased(address indexed seller, uint256 amount);
    event FundsRefunded(address indexed buyer, uint256 amount);
    event RiskUpdated(RiskStatus newRisk);

    modifier onlyOracle() {
        require(msg.sender == oracle, "Hanya oracle yang dapat mengeksekusi fungsi ini");
        _;
    }

    constructor(address _oracle) payable {
        buyer = msg.sender;
        // Alamat placeholder untuk pihak penjual/distributor dalam rantai pasok
        seller = 0x1111111111111111111111111111111111111111; 
        oracle = _oracle;
        totalEscrowAmount = msg.value;
        currentRisk = RiskStatus.Low;
        if(msg.value > 0) {
            emit FundsDeposited(msg.sender, msg.value);
        }
    }

    function depositFunds() external payable {
        require(msg.sender == buyer, "Hanya pembeli yang dapat menambah dana");
        require(!isFundsReleased && !isFundsRefunded, "Kontrak transaksi telah selesai");
        totalEscrowAmount += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }

    function updateRiskStatus(uint8 _risk) external onlyOracle {
        require(_risk <= 3, "Status risiko tidak valid");
        currentRisk = RiskStatus(_risk);
        emit RiskUpdated(currentRisk);
    }

    function releaseEscrow() external onlyOracle {
        require(!isFundsReleased && !isFundsRefunded, "Dana telah diproses sebelumnya");
        require(currentRisk != RiskStatus.Critical, "Pelepasan dana ditolak: Risiko kritikal terdeteksi");
        
        isFundsReleased = true;
        payable(seller).transfer(totalEscrowAmount);
        emit FundsReleased(seller, totalEscrowAmount);
    }

    function refundBuyer() external onlyOracle {
        require(!isFundsReleased && !isFundsRefunded, "Dana telah diproses sebelumnya");
        
        isFundsRefunded = true;
        payable(buyer).transfer(totalEscrowAmount);
        emit FundsRefunded(buyer, totalEscrowAmount);
    }
}