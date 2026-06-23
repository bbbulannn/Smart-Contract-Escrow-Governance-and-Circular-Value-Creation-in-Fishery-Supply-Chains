# Fishery Escrow Smart Contract — Execution Dataset

Supporting materials for:
> "From Dispute to Valorization: Smart Contract Escrow Governance 
> and Circular Value Creation in Fishery Supply Chains"
> Submitted to Supply Chain Management: An International Journal

## Repository Contents

| Folder | Contents |
|--------|----------|
| `contracts/` | Solidity source code for four governance contracts |
| `data/` | Execution dataset — 1,985 confirmed transactions on Ethereum Sepolia testnet |
| `docs/` | Deployment information and contract addresses |

## Contract Architecture

| Contract | Function |
|----------|----------|
| `LotRegistry.sol` | Immutable provenance logging |
| `Custody.sol` | Role-checked stakeholder transfers |
| `QualitySLA.sol` | Quality Index computation (QI = 100 − α·minutesAbove − β·excessDeg) |
| `EscrowSettlement.sol` | Financial settlement + circular routing logic |

## Dataset Description

`execution_results_1985tx.csv` contains all 1,985 confirmed 
transaction executions across four governance functions:
- recordActivity (n=609)
- updateLocation (n=400)
- createOrder (n=400)
- evaluateAndSettle (n=576): PASS (337) / PARTIAL (180) / FAIL-fishmeal (29) / FAIL-biogas (30)

All transactions executed on Ethereum Sepolia public testnet.
Projected costs under conservative Q2 2024 mainnet conditions.

## Verification

Transactions are independently verifiable on-chain via Sepolia 
Etherscan using the contract addresses listed in `docs/deployment_info.md`.

## License

Data and code released for academic reproducibility under 
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
