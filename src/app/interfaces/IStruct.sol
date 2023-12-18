// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IStruct {
    /// Structs ///

    struct BridgeData {
        bytes32 transactionId;
        string bridge;
        string integrator;
        address referrer;
        address sendingAssetId;
        address receiver;
        uint256 minAmount;
        uint256 destinationChainId;
        bool hasSourceSwaps;
        bool hasDestinationCall;
    }

    /// Events ///

    event TransferStarted(IStruct.BridgeData bridgeData);

    event TransferCompleted(
        bytes32 indexed transactionId, address receivingAssetId, address receiver, uint256 amount, uint256 timestamp
    );

    event TransferRecovered(
        bytes32 indexed transactionId, address receivingAssetId, address receiver, uint256 amount, uint256 timestamp
    );

    event GenericSwapCompleted(
        bytes32 indexed transactionId,
        string integrator,
        string referrer,
        address receiver,
        address fromAssetId,
        address toAssetId,
        uint256 fromAmount,
        uint256 toAmount
    );

    // Deprecated but kept here to include in ABI to parse historic events
    event SwappedGeneric(
        bytes32 indexed transactionId,
        string integrator,
        string referrer,
        address fromAssetId,
        address toAssetId,
        uint256 fromAmount,
        uint256 toAmount
    );
}
