// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IStruct} from "../interfaces/IStruct.sol";
import {LibAsset} from "src/libraries/LibAsset.sol";
import {ReentrancyGuard} from "../Helpers/ReentrancyGuard.sol";
import {SwapperV2, LibSwap} from "../Helpers/SwapperV2.sol";
import {Validatable} from "../Helpers/Validatable.sol";
import {LibUtil} from "src/libraries/LibUtil.sol";
import {InvalidReceiver} from "src/Errors/GenericErrors.sol";
import {LibAllowList} from "src/libraries/LibAllowList.sol";

/// @title Generic Swap Facet
/// @author LI.FI (https://li.fi)
/// @notice Provides functionality for swapping through ANY APPROVED DEX
/// @dev Uses calldata to execute APPROVED arbitrary methods on DEXs
/// @custom:version 1.0.0
contract GenericSwapFacet is IStruct, ReentrancyGuard, SwapperV2, Validatable {
    /// External Methods ///
    function addDex(address _dex) external {
        LibAllowList.addAllowedContract(_dex);
    }

    function setFunctionApprovalBySignature(bytes4 _signature) external {
        LibAllowList.addAllowedSelector(_signature);
    }

    /// @notice Performs multiple swaps in one transaction
    /// @param _transactionId the transaction id associated with the operation
    /// @param _integrator the name of the integrator
    /// @param _referrer the address of the referrer
    /// @param _receiver the address to receive the swapped tokens into (also excess tokens)
    /// @param _minAmount the minimum amount of the final asset to receive
    /// @param _swapData an object containing swap related data to perform swaps before bridging
    function swapTokensGeneric(
        bytes32 _transactionId,
        string calldata _integrator,
        string calldata _referrer,
        address payable _receiver,
        uint256 _minAmount,
        LibSwap.SwapData[] calldata _swapData
    ) external payable nonReentrant refundExcessNative(_receiver) returns (address) {
        if (LibUtil.isZeroAddress(_receiver)) {
            revert InvalidReceiver();
        }

        uint256 postSwapBalance = _depositAndSwap(_transactionId, _minAmount, _swapData, _receiver);
        address receivingAssetId = _swapData[_swapData.length - 1].receivingAssetId;
        LibAsset.transferAsset(receivingAssetId, _receiver, postSwapBalance);

        emit GenericSwapCompleted(
            _transactionId,
            _integrator,
            _referrer,
            _receiver,
            _swapData[0].sendingAssetId,
            receivingAssetId,
            _swapData[0].fromAmount,
            postSwapBalance
        );
        return receivingAssetId;
    }
}
