# Vandelay Smart Contract Templates

A curated collection of Solidity smart contract templates — built without imports, optimized for readability, learning, and customization.  

Created & maintained by **Vandelay Technologies**.

---

### ERC20 Token (`ERC20Token.sol`)
A standard ERC20 token implementation following OpenZeppelin standards.  
**Features:**
- Token transfers and approvals  
- Customizable initial supply  
- 18 decimal places  
- Full compliance with ERC20 specification  

---

### ERC721 NFT (`ERC721NFT.sol`)
A standard ERC721 NFT implementation with metadata support.  
**Features:**
- Unique token minting with metadata URIs  
- Token transfers and approvals  
- Operator approvals for bulk management  
- Full compliance with ERC721 specification  

---

### MultiSig Wallet (`MultiSigWallet.sol`)
A secure multi-signature wallet implementation.  
**Features:**
- Configurable number of required approvals  
- Transaction submission and execution  
- Owner management (add/remove)  
- ETH and contract interaction support  
- Comprehensive security checks  

---

### Crowdfunding (`Crowdfunding.sol`)
A flexible crowdfunding platform with token rewards.  
**Features:**
- Campaign creation and management  
- Contribution tracking  
- Token reward distribution  
- Automatic refunds for failed campaigns  
- Campaign status monitoring  

---

### Escrow (`Escrow.sol`)
A secure escrow system for marketplace transactions.  
**Features:**
- Agreement creation and management  
- Secure fund holding  
- Dispute resolution mechanism  
- Automated fund release/refund  
- Comprehensive security checks  

---

### Staking (`Staking.sol`)
A flexible token staking system with reward distribution.  
**Features:**
- Token staking and withdrawal management  
- Configurable reward rates and periods  
- Minimum and maximum staking periods  
- Reward accumulation and claiming  
- Position tracking and management  

---

### DAO Governance (`DAOGovernance.sol`)
A decentralized governance system for DAOs.  
**Features:**
- Proposal creation and management  
- Token-weighted voting system  
- Configurable voting periods and thresholds  
- Quorum-based decision making  
- Proposal execution and cancellation  
- Governance parameter updates  

---

### Timed Auction (`TimedAuction.sol`)
A flexible auction system with time-based bidding.  
**Features:**
- Auction creation with configurable start/end times  
- Bid placement with auto-refunds for outbid users  
- Auction cancellation before start  
- Auto fund transfer to seller upon close  
- Auction status tracking and querying  

---

### Lottery (`Lottery.sol`)
A decentralized lottery system with configurable parameters.  
**Features:**
- Lottery creation with custom ticket prices/timeframes  
- Automatic prize pool accumulation  
- Random winner selection via blockchain data  
- Owner fee percentage from prize pool  
- Lottery status and participant tracking  

---

### Supply Chain Tracking (`SupplyChainTracking.sol`)
A comprehensive product tracking system across the supply chain.  
**Features:**
- Product registration with unique IDs  
- Role-based control (manufacturer, distributor, retailer)  
- Movement logging with time/location data  
- Product status updates  
- Counterfeit detection and invalidation  

---

### Token Vesting (`TokenVesting.sol`)
A vesting system for distributing tokens over time.  
**Features:**
- Configurable schedules with cliffs  
- Linear vesting  
- Revocable/non-revocable options  
- Auto token release  
- Vesting schedule tracking  

---

### Bounties & Rewards (`BountiesAndRewards.sol`)
A system for incentivizing contributions with on-chain rewards.  
**Features:**
- Bounty creation with deadlines/rewards  
- Claim and completion tracking  
- Auto reward distribution  
- Refunds for unclaimed bounties  
- Bounty status and history  

---

### Governance Token Staking (`GovernanceTokenStaking.sol`)
A staking system tailored for DAO governance tokens.  
**Features:**
- Configurable staking amounts/durations  
- Time-based rewards  
- Flexible incentive structures  
- Stake tracking and reward claiming  
- Governance updates  

---

### Decentralized Marketplace (`DecentralizedMarketplace.sol`)
A peer-to-peer trading platform with built-in security.  
**Features:**
- Item listings with custom metadata  
- Order/payment processing  
- Escrow for secure trades  
- Dispute resolution options  
- Platform fee handling  

---

### Token Airdrop (`TokenAirdrop.sol`)
A system for distributing tokens to communities and users.  
**Features:**
- Airdrop creation with recipient list and token amounts  
- Time-based distribution  
- Claim tracking to prevent double claims  
- Refunds for canceled airdrops  
- Full airdrop status management  

---

### Referral Rewards (`ReferralRewards.sol`)
An incentivized referral tracking system.  
**Features:**
- Referral registration and history  
- Configurable reward tiers  
- Auto distribution to referrer/referee  
- Emergency pause functionality  
- Admin reward tier controls  

---

### NFT Staking (`NFTStaking.sol`)
Stake ERC721 NFTs to earn ERC20 token rewards.  
**Features:**
- Multi-collection support with individual reward configs  
- Time-based reward logic  
- Staking position tracking  
- Claim without unstaking  
- Emergency pause and admin control  

---

### Stablecoin (`VandelayStablecoin.sol`)
A cross-chain compatible ERC20 stablecoin.  
**Features:**
- ERC20 with EIP-2612 Permit support  
- Secure token bridge mechanism  
- Immutable bridge address  
- Optimized gas usage  
- Custom error handling  

---

### Cross-Chain Token (`VandelayCrossChain.sol`)
A Superchain-compatible ERC20 token for bridging across networks.  
**Features:**
- Secure cross-chain transfers  
- Superchain Token Bridge integration  
- Minting on Ethereum Mainnet  
- Admin ownership and access control  
- Optimized error and gas handling  

---

### Identity Verification (`IdentityVerification.sol`)
An on-chain identity verification and attestation framework.  
**Features:**
- Manage attestations (KYC, human checks, etc.)  
- Role-based access for attesters/admins  
- Revocable attestations  
- Customizable attestation types  
- Query and tracking tools  

---

**Dev/Author:**  
DeFi-Vandelay for Vandelay Technologies
