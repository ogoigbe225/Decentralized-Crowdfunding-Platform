# 🚀 Decentralized Crowdfunding Platform

A blockchain-based crowdfunding platform built on Stacks using Clarity smart contracts. Fund innovative projects with milestone-based releases and community governance! 💰

## ✨ Features

- 📝 **Project Creation**: Entrepreneurs can create funding campaigns with goals and deadlines
- 💸 **Secure Funding**: Backers fund projects with STX tokens held in escrow
- 🎯 **Milestone System**: Funds are released only when project milestones are achieved
- 🗳️ **Community Voting**: Funders vote to approve milestone completion
- 🔄 **Refund Protection**: Automatic refunds if projects don't reach funding goals
- 👥 **DAO Governance**: Decentralized approval process for fund releases

## 🛠️ Contract Functions

### Project Management
- `create-project` - Create a new crowdfunding project
- `fund-project` - Contribute STX to a project
- `end-project` - End a project (creator only)
- `refund-project` - Claim refund for failed projects

### Milestone System
- `create-milestone` - Add project milestones (creator only)
- `vote-milestone` - Vote on milestone completion (funders only)
- `approve-milestone` - Approve milestone based on votes
- `release-milestone-funds` - Release funds for approved milestones

### Read Functions
- `get-project` - Get project details
- `get-milestone` - Get milestone information
- `get-user-funding` - Check user's funding amount
- `get-project-count` - Total number of projects
- `has-voted-milestone` - Check if user voted on milestone

## 🚀 Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing

### Installation

```bash
clarinet new my-crowdfunding-project
```

Replace the generated contract with the crowdfunding contract code.

### Testing

```bash
clarinet test
```

### Deployment

```bash
clarinet deploy
```

## 📖 Usage Examples

### Creating a Project
```clarity
(contract-call? .crowdfunding create-project 
  "Revolutionary App" 
  "Building the next big social platform" 
  u10000000000 
  u1000)
```

### Funding a Project
```clarity
(contract-call? .crowdfunding fund-project u1 u1000000)
```

### Creating Milestones
```clarity
(contract-call? .crowdfunding create-milestone 
  u1 
  "MVP Development Complete" 
  u3000000000)
```

### Voting on Milestones
```clarity
(contract-call? .crowdfunding vote-milestone u1)
```

## 🔒 Security Features

- ✅ Only project creators can create milestones and release funds
- ✅ Only funders can vote on milestones
- ✅ Funds are held in contract escrow until milestone approval
- ✅ Automatic refunds for failed projects
- ✅ Protection against double-voting and unauthorized access

## 🎯 Roadmap

- [ ] Enhanced milestone templates
- [ ] Project categories and tags
- [ ] Advanced voting mechanisms
- [ ] Integration with external oracles
- [ ] Mobile-friendly interface
- [ ] Multi-token support

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 🌟 Support

Give this project a ⭐ if you find it useful!

For questions and support, please open an issue in the repository.
```

