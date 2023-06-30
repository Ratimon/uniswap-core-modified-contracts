// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {Test} from "@forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
        token1 = IERC20(address(new MockERC20("Token1", "T1", 18)));

        vm.label(address(token0), "Token0");
        vm.label(address(token1), "Token1");

        vm.stopPrank();
    }

    modifier deployerInit() {
        vm.startPrank(deployer);

        deal({token: address(token0), to: deployer, give: 200 ether});
        deal({token: address(token1), to: deployer, give: 300 ether});

        assertEq(token0.balanceOf(deployer), 200 ether, "Unexpected Faucet for token0");
        assertEq(token1.balanceOf(deployer), 300 ether, "Unexpected Faucet for token0");

        pair.initialize(token0, token1);

        vm.stopPrank();
        _;
    }

    function test_deposit() external deployerInit {
        vm.startPrank(deployer);

        token0.approve(address(pair), type(uint256).max);
        token1.approve(address(pair), type(uint256).max);

        pair.deposit(10 ether, 10 ether, deployer);

        
        (uint128 reserve0, uint128 reserve1) = pair.totalAssets();
        assertEq(reserve0, 10 ether, "unexpected reserve0");
        assertEq(reserve1, 10 ether, "unexpected reserve1");

        assertEq(pair.balanceOf(deployer), 10 ether, "initial share should be sqrt( token0 * token1 )");
        assertEq(pair.totalSupply(), 10 ether, "unexpected total supply");

        vm.stopPrank();
    }

    function test_double_deposit() external deployerInit {
        vm.startPrank(deployer);

        token0.approve(address(pair), type(uint256).max);
        token1.approve(address(pair), type(uint256).max);

        pair.deposit(10 ether, 10 ether, deployer);

        vm.warp(37);

        pair.deposit(20 ether, 20 ether, deployer);


        (uint128 reserve0, uint128 reserve1) = pair.totalAssets();
        assertEq(reserve0, 30 ether, "unexpected reserve0");
        assertEq(reserve1, 30 ether, "unexpected reserve1");

        uint decimalsOffset = 5;
        assertApproxEqAbs(pair.balanceOf(deployer), 30 ether, 10*(10**decimalsOffset), "should approximately equal original + added");
        assertApproxEqAbs(pair.totalSupply(), 30 ether, 10*(10**decimalsOffset), "unexpected total supply");

        vm.stopPrank();
    }
}
