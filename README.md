# Medirecall - Medicine Recall Tracker 🗂️

A blockchain-based system for tracking and verifying expired and dangerous medicine products using Clarity smart contracts on Stacks blockchain.

## Overview

Medirecall is a decentralized platform that enables pharmaceutical companies, healthcare providers, and regulatory authorities to track medicine recall status, verify product authenticity, and monitor expiration dates. This system ensures transparency and safety in the pharmaceutical supply chain.

## Features

### 🏥 Medicine Registry
- Register new medicines with complete product information
- Track batch numbers, expiration dates, and manufacturer details
- Immutable record keeping on blockchain

### ⚠️ Recall Management
- Issue recall notices for dangerous or defective products
- Track recall status and affected batches
- Emergency recall capabilities for immediate safety threats

### ✅ Verification System
- Real-time verification of medicine safety status
- Check expiration dates and recall status
- Public API for healthcare providers

### 📊 Transparency
- Public visibility of recalled products
- Audit trail for all transactions
- Decentralized verification process

## Smart Contracts

### 1. Medicine Registry Contract (`medicine-registry.clar`)
Handles the registration and management of medicine products with:
- Product registration and metadata storage
- Expiration date tracking
- Batch number management
- Manufacturer verification

### 2. Recall Manager Contract (`recall-manager.clar`)
Manages recall processes including:
- Recall issuance and categorization
- Status updates and notifications
- Emergency recall procedures
- Public recall database

## Technology Stack

- **Blockchain**: Stacks (STX)
- **Smart Contract Language**: Clarity
- **Development Framework**: Clarinet
- **Testing**: Vitest
- **Version Control**: Git

## Getting Started

### Prerequisites
- [Clarinet](https://docs.hiro.so/clarinet) installed
- [Node.js](https://nodejs.org/) v16+
- Git

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd Medirecall
```

2. Install dependencies:
```bash
npm install
```

3. Check contract syntax:
```bash
clarinet check
```

4. Run tests:
```bash
npm test
```

## Usage

### Registering a Medicine
Healthcare providers and manufacturers can register new medicines with batch information and expiration dates.

### Issuing a Recall
Authorized entities can issue recalls for defective or dangerous products, categorized by severity level.

### Checking Medicine Status
Anyone can verify the safety status of a medicine using its batch number or product ID.

## Contract Architecture

The system uses two main smart contracts that work together:

1. **Medicine Registry**: Core product database
2. **Recall Manager**: Recall processing and status management

All data is stored on-chain ensuring immutability and transparency while maintaining efficient query capabilities.

## Security

- Role-based access control
- Multi-signature requirements for critical operations
- Immutable audit trail
- Emergency response mechanisms

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

This project is licensed under the MIT License.

## Contact

For questions or support, please open an issue in the GitHub repository.

---

**⚠️ Important**: This system is designed for tracking medicine recalls and should be used in conjunction with existing regulatory frameworks and not as a replacement for professional medical advice.
