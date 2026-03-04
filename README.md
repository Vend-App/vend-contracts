## Vend Contracts

This repository contains contracts and scripts for reward distribution from the Vend mobile app.

Current implementation:
- `src/RewardDistributor.sol`

## RewardDistributor

`RewardDistributor` is a simple vault-style contract for:
- Holding ERC20 tokens (including LayerZero OFTs as standard ERC20s).
- Holding native network token (`token == address(0)` sentinel).
- Emitting reward-focused events for indexing and analytics.

### Features

- Ownable (`owner`) plus configurable admins.
- Pausable (`deposit` and `distributeReward` are blocked while paused).
- Deposit flow with explicit `Deposit(caller, token, amount)` event.
- Reward distribution flow with `RewardDistributed(to, token, amount)` event.
- Withdraw flow with `Withdraw(caller, token, amount, to)` event.

### Important behavior notes

- Distributions are intended to be initiated by the Vend app's backend server wallet as admin.
- Native deposits must use `deposit(address(0), amount)` with matching `msg.value`.
- Direct native sends are rejected by `receive()` so deposits are always event-tracked.
- ERC20 transfers sent directly to the contract (without calling `deposit`) cannot be prevented; funds are still usable, but no `Deposit` event is emitted.
- OFT handling does not require LayerZero imports for this contract because local token handling is ERC20-compatible.
- `withdraw` intentionally bypasses pause checks so owner/admin can recover funds during incident response.

## Network Configuration (Glue)

Configured in `foundry.toml`:
- RPC alias: `glue -> https://rpc.vend.trade`
- Explorer verifier URL: `https://explorer.glue.net/api`

Glue RPC requires header auth. Set:
- `ETH_RPC_HEADERS=X-Api-Key:<your-rpc-api-key>`

## Environment Variables

Copy and fill:

```bash
cp .env.example .env
```

Required vars:
- `RPC_API_KEY`
- `ETH_RPC_HEADERS`
- `PRIVATE_KEY`
- `REWARD_DISTRIBUTOR_ADDRESS` (after deploy)
- `ADMIN_ADDRESS` (for add/remove admin scripts)

## Scripts

All scripts read `PRIVATE_KEY` from env, so you do not pass private key on the command line.

> 💡 Make sure to use a private key associated with an admin account, otherwise scripts will fail.

### Deploy RewardDistributor

Dry run:

```bash
source .env
forge script script/DeployRewardDistributor.s.sol:DeployRewardDistributorScript --rpc-url glue
```

Broadcast + verify (Blockscout):

```bash
source .env
forge script script/DeployRewardDistributor.s.sol:DeployRewardDistributorScript --rpc-url glue --broadcast --verify --verifier blockscout --verifier-url https://explorer.glue.net/api
```

### Add admin

```bash
source .env
forge script script/AddRewardDistributorAdmin.s.sol:AddRewardDistributorAdminScript --rpc-url glue --broadcast
```

### Remove admin

```bash
source .env
forge script script/RemoveRewardDistributorAdmin.s.sol:RemoveRewardDistributorAdminScript --rpc-url glue --broadcast
```

## Development Commands

Build:

```bash
forge build
```

Test:

```bash
forge test
```

Format:

```bash
forge fmt
```

## Foundry Documentation

- [Foundry Book](https://book.getfoundry.sh/)
