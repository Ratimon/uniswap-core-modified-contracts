// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

// import {console2} from "@forge-std/console2.sol";
import {Test} from "@forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";

import {UniswapV2Factory} from "@main/UniswapV2Factory.sol";
import {UniswapV2PairVault} from "@main/UniswapV2PairVault.sol";

contract UniswapV2FactoryTest is Test {
    string mnemonic = "test test test test test test test test test test test junk";
    uint256 deployerPrivateKey = vm.deriveKey(mnemonic, "m/44'/60'/0'/0/", 1); //  address = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8

    address deployer = vm.addr(deployerPrivateKey);
    address alice = makeAddr("Alice");

    UniswapV2Factory factory;

    IERC20 token0;
    IERC20 token1;

    function setUp() public {
        vm.startPrank(deployer);
        vm.deal(deployer, 1 ether);
        vm.label(deployer, "Deployer");


        factory = new UniswapV2Factory(1); // fee 1%

        token0 = IERC20(address(new MockERC20("Token0", "T0", 18)));
        token1 = IERC20(address(new MockERC20("Token1", "T1", 18)));

        vm.label(address(token0), "Token0");
        vm.label(address(token1), "Token1");

        vm.stopPrank();
    }

    function test_RevertWhen_IDENTICAL_ADDRESSES_createPair() external {
        vm.startPrank(deployer);

        vm.expectRevert(bytes("UniswapV2: IDENTICAL_ADDRESSES"));
        factory.createPair( address(token0), address(token0));

        vm.stopPrank();
    }


    function test_RevertWhen_ZERO_ADDRESS_createPair() external {
        vm.startPrank(deployer);

        vm.expectRevert(bytes("UniswapV2: ZERO_ADDRESS"));
        factory.createPair( address(token0), address(0));

        vm.expectRevert(bytes("UniswapV2: ZERO_ADDRESS"));
        factory.createPair(address(0), address(token1));

        vm.stopPrank();
    }

    function test_RevertWhen_PAIR_EXISTS_createPair() external {
        vm.startPrank(deployer);

        factory.createPair(address(token0),address(token1));

        vm.expectRevert(bytes("UniswapV2: PAIR_EXISTS"));
        factory.createPair(address(token1), address(token0));

        vm.stopPrank();
    }

    function test_createPair() external {
        vm.startPrank(deployer);

        address pairAddress = factory.createPair(
            address(token1),
            address(token0)
        );

        UniswapV2PairVault pair = UniswapV2PairVault(pairAddress);

        assertEq(pair.asset0(), address(token0));
        assertEq(pair.asset1(), address(token1));

        vm.stopPrank();
    }
}