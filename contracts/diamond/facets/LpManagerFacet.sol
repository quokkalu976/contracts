// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../utils/TransferHelper.sol";
import "../security/Pausable.sol";
import "../interfaces/ILpManager.sol";
import "../libraries/LibLpManager.sol";
import "../libraries/LibStakeReward.sol";
import "../security/ReentrancyGuard.sol";
import "../libraries/LibAccessControlEnumerable.sol";

interface ILp {
    function mint(address to, uint256 amount) external;

    function burnFrom(address account, uint256 amount) external;
}

contract LpManagerFacet is ReentrancyGuard, Pausable, ILpManager {

    using TransferHelper for address;

    function initLpManagerFacet(address lpToken) external {
        LibAccessControlEnumerable.checkRole(Constants.DEPLOYER_ROLE);
        require(lpToken != address(0), "LpManagerFacet: Invalid lpToken");
        LibLpManager.initialize(lpToken);
    }

    function LP() public view override returns (address) {
        return LibLpManager.lpManagerStorage().lpAddress;
    }

    function coolingDuration() external view override returns (uint256) {
        return LibLpManager.lpManagerStorage().coolingDuration;
    }

    function setCoolingDuration(uint256 coolingDuration_) external override {
        LibAccessControlEnumerable.checkRole(Constants.ADMIN_ROLE);
        LibLpManager.LpManagerStorage storage ams = LibLpManager.lpManagerStorage();
        ams.coolingDuration = coolingDuration_;
    }

    function mintLP(address tokenIn, uint256 amount, uint256 minLp, bool stake) external whenNotPaused nonReentrant override {
        _mintLP(tokenIn, amount, minLp, stake);
    }

    function mintLPNative(uint256 minLp, bool stake) external payable whenNotPaused nonReentrant override {
        _mintLP(TransferHelper.nativeWrapped(), msg.value, minLp, stake);
    }

    function _mintLP(address tokenIn, uint256 amount, uint256 minLp, bool stake) private {
        require(amount > 0, "LpManagerFacet: invalid amount");
        address account = msg.sender;
        uint256 lpAmount = LibLpManager.mintLP(account, tokenIn, amount);
        require(lpAmount >= minLp, "LpManagerFacet: insufficient LP output");
        tokenIn.transferFrom(account, amount);
        _mint(account, tokenIn, amount, lpAmount, stake);
    }

    function _mint(address account, address tokenIn, uint256 amount, uint256 lpAmount, bool stake) private {
        ILp(LP()).mint(account, lpAmount);
        emit MintLp(account, tokenIn, amount, lpAmount);
        if (stake) {
            LibStakeReward.stake(lpAmount);
        }
    }

    function burnLP(address tokenOut, uint256 lpAmount, uint256 minOut, address receiver) external whenNotPaused nonReentrant override {
        _burnLP(tokenOut, lpAmount, minOut, receiver);
    }

    function burnLPNative(uint256 lpAmount, uint256 minOut, address payable receiver) external whenNotPaused nonReentrant override {
        _burnLP(TransferHelper.nativeWrapped(), lpAmount, minOut, receiver);
    }

    function _burnLP(address tokenOut, uint256 lpAmount, uint256 minOut, address receiver) private {
        require(lpAmount > 0, "LpManagerFacet: invalid lpAmount");
        address account = msg.sender;
        uint256 amountOut = LibLpManager.burnLP(account, tokenOut, lpAmount);
        require(amountOut >= minOut, "LpManagerFacet: insufficient token output");
        ILp(LP()).burnFrom(account, lpAmount);
        IVault(address(this)).decrease(tokenOut, amountOut);
        tokenOut.transfer(receiver, amountOut);
        emit burnLp(account, receiver, tokenOut, lpAmount, amountOut);
    }

    function addFreeBurnWhitelist(address account) external override {
        LibAccessControlEnumerable.checkRole(Constants.ADMIN_ROLE);
        LibLpManager.LpManagerStorage storage ams = LibLpManager.lpManagerStorage();
        ams.freeBurnWhitelists[account] = true;
        emit SupportedFreeBurn(account, true);
    }

    function removeFreeBurnWhitelist(address account) external override {
        LibAccessControlEnumerable.checkRole(Constants.ADMIN_ROLE);
        LibLpManager.LpManagerStorage storage ams = LibLpManager.lpManagerStorage();
        ams.freeBurnWhitelists[account] = false;
        emit SupportedFreeBurn(account, false);
    }

    function isFreeBurn(address account) external view override returns (bool) {
        return LibLpManager.lpManagerStorage().freeBurnWhitelists[account];
    }

    function lpPrice() external view override returns (uint256) {
        return LibLpManager.lpPrice();
    }

    function lastMintedTimestamp(address account) external view override returns (uint256) {
        return LibLpManager.lpManagerStorage().lastMintedAt[account];
    }
}