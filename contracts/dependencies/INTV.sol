// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// native token
interface INTV {
    function deposit() external payable;

    function withdraw(uint) external;
}