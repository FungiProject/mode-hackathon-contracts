// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {LibAsset} from "src/libraries/LibAsset.sol";
import {LibUtil} from "src/libraries/LibUtil.sol";
import {
    InvalidReceiver,
    InformationMismatch,
    InvalidSendingToken,
    InvalidAmount,
    NativeAssetNotSupported,
    InvalidDestinationChain,
    CannotBridgeToSameNetwork
} from "src/Errors/GenericErrors.sol";
import {IStruct} from "../interfaces/IStruct.sol";
import {LibSwap} from "src/libraries/LibSwap.sol";

contract Validatable {
    modifier validateBridgeData(IStruct.BridgeData memory _bridgeData) {
        if (LibUtil.isZeroAddress(_bridgeData.receiver)) {
            revert InvalidReceiver();
        }
        if (_bridgeData.minAmount == 0) {
            revert InvalidAmount();
        }
        if (_bridgeData.destinationChainId == block.chainid) {
            revert CannotBridgeToSameNetwork();
        }
        _;
    }

    modifier noNativeAsset(IStruct.BridgeData memory _bridgeData) {
        if (LibAsset.isNativeAsset(_bridgeData.sendingAssetId)) {
            revert NativeAssetNotSupported();
        }
        _;
    }

    modifier onlyAllowSourceToken(IStruct.BridgeData memory _bridgeData, address _token) {
        if (_bridgeData.sendingAssetId != _token) {
            revert InvalidSendingToken();
        }
        _;
    }

    modifier onlyAllowDestinationChain(IStruct.BridgeData memory _bridgeData, uint256 _chainId) {
        if (_bridgeData.destinationChainId != _chainId) {
            revert InvalidDestinationChain();
        }
        _;
    }

    modifier containsSourceSwaps(IStruct.BridgeData memory _bridgeData) {
        if (!_bridgeData.hasSourceSwaps) {
            revert InformationMismatch();
        }
        _;
    }

    modifier doesNotContainSourceSwaps(IStruct.BridgeData memory _bridgeData) {
        if (_bridgeData.hasSourceSwaps) {
            revert InformationMismatch();
        }
        _;
    }

    modifier doesNotContainDestinationCalls(IStruct.BridgeData memory _bridgeData) {
        if (_bridgeData.hasDestinationCall) {
            revert InformationMismatch();
        }
        _;
    }
}
