// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {Test} from "@forge-std/Test.sol";

import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";
import {UniswapV2PairVault} from "@main/UniswapV2PairVault.sol";



contract UniswapV2PairVaultTest is Test {

    string mnemonic = "test test test test test test test test test test test junk";
    uint256 deployerPrivateKey = vm.deriveKey(mnemonic, "m/44'/60'/0'/0/", 1); //  address = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8

    address deployer = vm.addr(deployerPrivateKey);

    UniswapV2PairVault pair;

    IERC20 token0;
    IERC20 token1;

    function setUp() public {
        vm.startPrank(deployer);
        vm.deal(deployer, 1 ether);

        vm.label(deployer, "Deployer");

        pair = new UniswapV2PairVault();

        token0 = IERC20(address(new MockERC20("Token0", "T0", 18)));
        vm.label(address(acceptedToken), "Token0");

        token1 = IERC20(address(new MockERC20("Token1", "T1", 18)));
        vm.label(address(saleToken), "Token1");

        pair.initialize(token0, token1);

        vm.stopPrank();
    }

    function test_1() external {

    }

}