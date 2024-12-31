// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title IRealmPoints
 * @notice Interface for the RealmPoints contract
 */
interface IRealmPoints {
    /**
     * @notice Verifies if a user has sufficient realm points and if they are not expired
     * @param user Address of the user
     * @param amount Amount of realm points to verify
     * @param expiry Expiry timestamp of the realm points
     * @param signature Signature from authorized signer verifying the realm points
     * @return bool True if verification passes
     */
    function verifyRealmPoints(
        address user,
        uint256 amount,
        uint256 expiry,
        bytes calldata signature
    ) external view returns (bool);
} 