// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../dependencies/INTV.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library TransferHelper {

    using Address for address payable;
    using SafeERC20 for IERC20;

    uint constant public BITLAYER_CHAIN = 200901;
    address constant public BITLAYER_CHAIN_WRAPPED = 0xfF204e2681A6fA0e2C3FaDe68a1B28fb90E4Fc5F;

    uint constant public BITLAYER_CHAIN_TESTNET = 200810;
    address constant public BITLAYER_CHAIN_TESTNET_WRAPPED = 0x3e57d6946f893314324C975AA9CEBBdF3232967E;

    function transfer(address token, address to, uint256 amount) internal {
        if (token != nativeWrapped() || _isContract(to)) {
            IERC20(token).safeTransfer(to, amount);
        } else {
            INTV(token).withdraw(amount);
            payable(to).sendValue(amount);
        }
    }

    function transferFrom(address token, address from, uint256 amount) internal {
        if (token != nativeWrapped()) {
            IERC20(token).safeTransferFrom(from, address(this), amount);
        } else {
            require(msg.value >= amount, "insufficient transfers");
            INTV(token).deposit{value: amount}();
        }
    }

    function nativeWrapped() internal view returns (address) {
        uint256 chainId = block.chainid;
        if (chainId == BITLAYER_CHAIN_TESTNET) {
            return BITLAYER_CHAIN_TESTNET_WRAPPED;
        } else if (chainId == BITLAYER_CHAIN) {
            return BITLAYER_CHAIN_WRAPPED;
        } else {
            revert("unsupported chain id");
        }
    }

    function _isContract(address account) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}
