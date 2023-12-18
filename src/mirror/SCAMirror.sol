// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

abstract contract SCAMirror {
    address public diamond;

    event DiamondSet(address indexed newDiamond);
    event FacetSelectorsSet(address indexed facet, bytes4[] selectors);

    function setDiamond(address _diamond) internal {
        require(_diamond != address(0), "Diamond address cannot be the zero address.");
        diamond = _diamond;
        emit DiamondSet(_diamond);
    }

    function getDiamond() external view returns (address) {
        return diamond;
    }

    function callFacet(bytes memory _data) internal returns (bool success, bytes memory result) {
        (success, result) = diamond.call(_data);
        require(success, "Facet call failed");
    }

    function staticCallFacet(bytes memory _data) internal view returns (bool success, bytes memory result) {
        (success, result) = address(diamond).staticcall(_data);
        require(success, "Facet call failed");
    }
}
