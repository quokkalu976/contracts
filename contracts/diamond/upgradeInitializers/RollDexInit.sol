// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../libraries/LibDiamond.sol";
import "../interfaces/IDiamondLoupe.sol";
import "../interfaces/IDiamondCut.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/access/IAccessControlEnumerable.sol";
import "../libraries/LibAccessControlEnumerable.sol";

contract RollDexInit {
    function init() external {
        // adding ERC165 data
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;

        LibAccessControlEnumerable.AccessControlStorage storage acs = LibAccessControlEnumerable.accessControlStorage();
        acs.supportedInterfaces[type(IERC165).interfaceId] = true;
        acs.supportedInterfaces[type(IAccessControl).interfaceId] = true;
        acs.supportedInterfaces[type(IAccessControlEnumerable).interfaceId] = true;
    }
}
