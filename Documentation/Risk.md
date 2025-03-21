# Risk matrix for all contracts

Mainnet
- NftLocker
- [In ecosystem: MocaToken, MocaTokenAdapter, NftStreaming]

Base
- StakingPro + RewardsVault
- NftRegistry

Away
- EVMVault

## Approach

Pause everything everywhere first.
Remediate and unpause accordingly. 

### StakingPro

### RewardsVaultV1

User fns
- setReceiverEvm

POOL_ROLE
- `setupDistribution` 
- `updateDistribution`
- `endDistribution`
- `payRewards`

MONEY_MANAGER_ROLE
- deposit
- withdraw

MONITOR_ROLE [eoa]
- pause

DEFAULT_ADMIN_ROLE [multisig]
- unpause
- exit  [to withdraw any ERC20 tokens when paused]

**Monitor script is expected to pause contract when something untoward.**

If POOL_ROLE is compromised, attacker could:
- create malicious distributions
- update distribution amounts
- trigger unauthorized reward payments

If MONEY_MANAGER_ROLE is compromised:
- drain funds through withdraw function

- `setupDistribution`, `updateDistribution`, `endDistribution` fns are only callable by POOL_ROLE.
- If pool is paused, these functions cannot be called, unless there is another address with POOL_ROLE.

### EVMVault

User fns:
- collectUnclaimedRewards

MONEY_MANAGER_ROLE:
- deposit
- withdraw

MONITOR_ROLE [eoa]
- pause

DEFAULT_ADMIN_ROLE [multisig]
- unpause

LZ fn:
_lzReceive