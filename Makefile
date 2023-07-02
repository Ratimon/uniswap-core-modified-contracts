# spin node
anvil-node:
	anvil --chain-id 1337

anvil-node-auto:
	anvil --chain-id 1337 --block-time 15

unit-test:
	forge test --match-path test/UniswapV2PairVault.t.sol -vvv

unit-test2:
	forge test --match-test test_swap -vvv

	

define local_network
http://127.0.0.1:$1
endef