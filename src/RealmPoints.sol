// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import './Events.sol';
import {Errors} from "./Errors.sol";

import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";

import {Pausable} from "openzeppelin-contracts/contracts/utils/Pausable.sol";
import {Ownable2Step, Ownable} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";

interface IPool {
    function stakeRP(bytes32 vaultId, uint256 amount, address onBehalfOf) external;
}

contract RealmPoints is EIP712, Pausable, Ownable2Step {

    IPool public POOL;
    uint256 public MINIMUM_REALMPOINTS_REQUIRED;

    uint256 public immutable startTime; 
    address internal immutable STORED_SIGNER;                 // can this be immutable? 

    struct StakeRp {
        address user;
        bytes32 vaultId;
        uint256 amount;
        uint256 expiry;
    }

    // has signature been executed: 1 is true, 0 is false [replay attack prevention]
    mapping(bytes signature => uint256 executed) public executedSignatures;

    constructor(address owner, uint256 startTime_, uint256 minimumRealmPointsRequired, string memory name, string memory version) EIP712(name, version) Ownable(owner) {
        require(owner > address(0), "Zero address");
        require(startTime > block.timestamp, "Start time must be in the future");
        require(minimumRealmPointsRequired > 0, "Minimum realm points required must be greater than 0");

        startTime = startTime_;
        MINIMUM_REALMPOINTS_REQUIRED = minimumRealmPointsRequired;
    }

    /**
     * @notice Stakes realm points for a user
     * @dev Requires a valid signature from the stored signer to authorize the staking
     * @param vaultId The ID of the vault to stake realm points in
     * @param amount The amount of realm points to stake
     * @param expiry The expiry timestamp of the signature
     * @param signature The signature to verify
     */
    function stakeRP(bytes32 vaultId, uint256 amount, uint256 expiry, bytes calldata signature) external whenStarted whenNotPaused {
        if(vaultId == 0) revert Errors.InvalidVaultId();
        if(expiry < block.timestamp) revert Errors.SignatureExpired();
        if(amount < MINIMUM_REALMPOINTS_REQUIRED) revert Errors.MinimumRpRequired();
        
        // replay attack prevention
        if(executedSignatures[signature] == 1) revert Errors.SignatureAlreadyExecuted();

        // verify signature
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
            keccak256("StakeRp(address user,bytes32 vaultId,uint256 amount,uint256 expiry)"), 
            msg.sender, vaultId, amount, expiry)));
        
        address signer = ECDSA.recover(digest, signature);
        if(signer != STORED_SIGNER) revert Errors.InvalidSignature(); 

        // set signature to executed
        executedSignatures[signature] = 1;

        emit StakedRealmPoints(msg.sender, vaultId, amount);

        // call pool
        POOL.stakeRP(vaultId, amount, msg.sender);
    }


    /*//////////////////////////////////////////////////////////////
                                OWNER
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the pool contract address
     * @dev Only callable by owner
     * @param poolAddress The address of the pool contract to set
     */
    function setPool(address poolAddress) external onlyOwner {
        if(poolAddress == address(0)) revert Errors.InvalidAddress();
        
        POOL = IPool(poolAddress);
        emit PoolSet(poolAddress);
    }

    /**
     * @notice Updates the minimum realm points required for staking
     * @dev Zero values are not accepted to prevent dust attacks
     * @param newAmount The new minimum realm points required
    */
    function updateMinimumRealmPoints(uint256 newAmount) external onlyOwner {
        if(newAmount == 0) revert Errors.InvalidAmount();
        
        uint256 oldAmount = MINIMUM_REALMPOINTS_REQUIRED;
        MINIMUM_REALMPOINTS_REQUIRED = newAmount;

        emit MinimumRealmPointsUpdated(oldAmount, newAmount);
    }

    
    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Returns the hash of the fully encoded EIP712 message for this domain
     *      See EIP712.sol
     */
    function hashTypedDataV4(bytes32 structHash) external view returns (bytes32) {
        return _hashTypedDataV4(structHash);
    }

    /**
     * @dev Returns the domain separator for the current chain
     *      See EIP712.sol
     */
    function domainSeparatorV4() external view returns (bytes32) {
        return _domainSeparatorV4();
    }


    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    function _whenStarted() internal view {
        if(block.timestamp < startTime) revert Errors.NotStarted();    
    }

    modifier whenStarted() {
        _whenStarted();
        _;
    }
}