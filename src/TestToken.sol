// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20("TestToken", "TKN") {
    /** Constructor gives msg.sender all existing tokens.
     */
    constructor(uint256 initialSupply) {
        _mint(msg.sender, initialSupply);
    }

    /** Overrides transferFrom to approve msg.sender to spend tokens owned by `sender`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _approve(sender, msg.sender, amount);
        return super.transferFrom(sender, recipient, amount);
    }
}
