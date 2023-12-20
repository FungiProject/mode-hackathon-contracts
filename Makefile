-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil 

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
# 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

all: clean install build test

# Clean the repo
clean  :; forge clean

install :; forge install foundry-rs/forge-std@v1.5.3 foundry-rs/forge-std transmissions11/solmate OpenZeppelin/openzeppelin-contracts Arachnid/solidity-stringutils smartcontractkit/foundry-chainlink-toolkit --no-commit

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test --ffi --via-ir

NETWORK_ARGS := --ffi --via-ir --fork-url http:localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast
NETWORK_LACHAIN := --ffi --via-ir --legacy --rpc-url $(LATESTNET_RPC_URL) --chain 418 --private-key $(LATESTNET_PRIVATE_KEY) --broadcast -vvvv

# NETWORK_TDLY := --ffi --rpc-url $(TENDERLY_RPC_URL) --private-key $(DEFAULT_ANVIL_KEY) --broadcast

# Modify the deployerPK and DiamondOwner in DeployDiamond.s.sol script to deploy the diamond in the network of your choice
# SEPOLIA
ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --ffi --via-ir --rpc-url $(SEPOLIA_RPC_URL) --private-key $(SEPOLIA_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

# ARBITRUM MAINNET
ifeq ($(findstring --network arbitrum,$(ARGS)),--network arbitrum)
	NETWORK_ARGS := --ffi --via-ir --rpc-url $(ARBITRUM_RPC_URL) --private-key $(ARBITRUM_PRIVATE_KEY) --broadcast -vvvv
endif

# MUMBAI
ifeq ($(findstring --network mumbai,$(ARGS)),--network mumbai)
	NETWORK_ARGS := --ffi --via-ir --rpc-url $(MUMBAI_RPC_URL) --private-key $(MUMBAI_PRIVATE_KEY) --legacy --broadcast --verify --etherscan-api-key $(POLYSCAN_API_KEY) -vvvv
endif

# LATESTNET
ifeq ($(findstring --network latestnet,$(ARGS)),--network latestnet)
	NETWORK_ARGS := --ffi --via-ir --rpc-url $(LATESTNET_RPC_URL) --private-key $(LATESTNET_PRIVATE_KEY) --legacy --broadcast -vvvv
endif

# MODE TESTNET
ifeq ($(findstring --network mode,$(ARGS)),--network mode)
	NETWORK_ARGS := --ffi --via-ir --rpc-url $(MODE_TESTNET_RPC_URL) --private-key $(MODE_TESTNET_PRIVATE_KEY) --broadcast -vvvv
endif

# Deploy the Protocol diamond with all its facets: DiamondCut, DiamondLoupe, Ownership, GenericSwap, Pricefeed & FundFactory, and saves the addresses to script/deploy/deployed_addresses.txt
# e.g. make deploy ARGS="--network sepolia"
deploy:
	forge script script/deploy/deployDiamondWithSCA.s.sol $(NETWORK_ARGS)

# run node
node:
	anvil --fork-url $(MAINNET_RPC_URL)
