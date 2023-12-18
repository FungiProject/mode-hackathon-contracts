// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {LibSwap} from "../Helpers/SwapperV2.sol";

interface IGenericSwapFacet {
    function setFunctionApprovalBySignature(bytes4 _signature) external;
    function swapTokensGeneric(
        bytes32 _transactionId,
        string calldata _integrator,
        string calldata _referrer,
        address payable _receiver,
        uint256 _minAmount,
        LibSwap.SwapData[] calldata _swapData
    ) external payable;
}
