# 🆘 Decentralised Emergency Aid Wallets

> A transparent, trustless emergency aid distribution system built on Stacks blockchain

## 🌟 Overview

The Decentralised Emergency Aid Wallets smart contract enables communities to request, approve, and distribute emergency aid in a transparent and decentralized manner. Built with Clarity, this system ensures accountability while providing rapid assistance to those in need.

## ✨ Features

- 🏥 **Emergency Aid Requests**: Create detailed aid requests with descriptions and deadlines
- ✅ **Approval System**: Designated approvers validate legitimate aid requests
- 💰 **Decentralized Donations**: Community members can donate STX tokens directly
- 📊 **Progress Tracking**: Real-time monitoring of funding progress
- 🔒 **Secure Withdrawals**: Only approved requests can withdraw funds
- 📈 **Statistics Dashboard**: Track total donations and distributions
- ⏰ **Time-based Expiry**: Automatic expiration of aid requests

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- [Stacks Wallet](https://wallet.hiro.so/) or compatible wallet
- Basic understanding of Clarity smart contracts

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/Decentralised-Emergency-Aid-Wallets
   cd Decentralised-Emergency-Aid-Wallets
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Check contract syntax**
   ```bash
   clarinet check
   ```

4. **Run tests**
   ```bash
   npm test
   ```

## 📋 Contract Functions

### 🔧 Admin Functions

#### `add-approver`
Adds a new approver to validate aid requests (contract owner only)
```clarity
(contract-call? .contract add-approver 'SP1234...)
```

#### `remove-approver`
Removes an approver from the system (contract owner only)
```clarity
(contract-call? .contract remove-approver 'SP1234...)
```

### 🆘 Aid Request Functions

#### `create-aid-request`
Create a new emergency aid request
```clarity
(contract-call? .contract create-aid-request 
    u1000000  ; amount needed in microSTX
    "Medical emergency treatment needed"
    "Medical"
    u2016)    ; deadline in blocks (~2 weeks)
```

#### `approve-aid-request`
Approve an aid request (approvers only)
```clarity
(contract-call? .contract approve-aid-request u1)
```

#### `close-aid-request`
Close an aid request (requester only)
```clarity
(contract-call? .contract close-aid-request u1)
```

### 💝 Donation Functions

#### `donate-to-aid`
Donate STX tokens to an approved aid request
```clarity
(contract-call? .contract donate-to-aid u1 u500000)
```

#### `withdraw-aid`
Withdraw donated funds (requester only, after approval)
```clarity
(contract-call? .contract withdraw-aid u1)
```

### 📊 Read-Only Functions

#### `get-aid-request`
Retrieve details of a specific aid request
```clarity
(contract-call? .contract get-aid-request u1)
```

#### `get-aid-progress`
Get funding progress for an aid request
```clarity
(contract-call? .contract get-aid-progress u1)
```

#### `get-total-statistics`
View overall platform statistics
```clarity
(contract-call? .contract get-total-statistics)
```

#### `get-donor-stats`
Retrieve donation statistics for a specific donor
```clarity
(contract-call? .contract get-donor-stats 'SP1234...)
```

## 🔄 Workflow

1. **Setup** 🏗️
   - Contract owner adds trusted approvers
   - System is ready to receive aid requests

2. **Aid Request** 🆘
   - Person in need creates aid request with description
   - Sets amount needed and deadline
   - Request enters pending state

3. **Approval Process** ✅
   - Approvers review and validate requests
   - Only legitimate requests get approved
   - Approved requests can receive donations

4. **Donation Phase** 💰
   - Community members donate STX tokens
   - Progress tracked in real-time
   - Donations held securely in contract

5. **Distribution** 📤
   - Requester withdraws approved funds
   - Aid request marked as inactive
   - Statistics updated

## 🛡️ Security Features

- **Access Control**: Owner-only admin functions
- **Validation**: Multiple checks before fund transfers
- **Time Limits**: Automatic expiration prevents stale requests
- **Self-Approval Prevention**: Requesters cannot approve their own requests
- **Transparent Records**: All transactions recorded on-chain

## 📊 Error Codes

- `u100` - Owner only operation
- `u101` - Resource not found
- `u102` - Resource already exists
- `u103` - Insufficient funds
- `u104` - Invalid amount
- `u105` - Not approved
- `u106` - Already approved
- `u107` - Request expired
- `u108` - Self-approval attempt

## 🧪 Testing

Run the test suite to ensure contract functionality:

```bash
npm test
```

Tests cover:
- ✅ Aid request creation and management
- ✅ Approver system functionality
- ✅ Donation and withdrawal processes
- ✅ Access control mechanisms
- ✅ Edge cases and error conditions


## 📝 License

This project is licensed under the MIT License 



## ⚠️ Disclaimer

This smart contract is provided as-is. Users should conduct their own security audits before deploying to mainnet. Emergency aid distribution involves real funds and should be thoroughly tested.

---

**Built with ❤️ for humanitarian causes on Stacks blockchain**

# Decentralised Emergency Aid Wallets

