/**
 * @title IERC20 Token Interface
 * @dev Interface for the ERC20 standard as defined in the EIP.
 * @notice This interface defines the standard functions that an ERC20 token must implement
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to another (`to`).
     * @param from The address tokens are transferred from
     * @param to The address tokens are transferred to
     * @param value The amount of tokens transferred
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     * @param owner The address that owns the tokens
     * @param spender The address that is approved to spend the tokens
     * @param value The amount of tokens approved to spend
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the total supply of the token.
     * @return The total token supply
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     * @param account The address to query the balance of
     * @return The number of tokens owned by the account
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     * @param to The recipient address
     * @param amount The amount of tokens to transfer
     * @return success Returns true if the transfer succeeds
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner`.
     * @param owner The address that owns the tokens
     * @param spender The address that can spend the tokens
     * @return The number of tokens still available for the spender
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     * @param spender The address that can spend the tokens
     * @param amount The amount of tokens to allow spending
     * @return success Returns true if the approval succeeds
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the allowance mechanism.
     * Emits a {Transfer} event.
     * @param from The address to transfer tokens from
     * @param to The address to transfer tokens to
     * @param amount The amount of tokens to transfer
     * @return success Returns true if the transfer succeeds
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
