// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

// import {console2} from "@forge-std/console2.sol";

import {Test} from "@forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";

import {FlashLoanReceiver} from "@main/FlashLoanReceiver.sol";
import {UniswapV2PairVault} from "@main/UniswapV2PairVault.sol";

contract UniswapV2PairVaultTest is Test {
    string mnemonic = "test test test test test test test test test test test junk";
    uint256 deployerPrivateKey = vm.deriveKey(mnemonic, "m/44'/60'/0'/0/", 1); //  address = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8

    address deployer = vm.addr(deployerPrivateKey);
    address alice = makeAddr("Alice");

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

        pair.initialize(address(token0), address(token1), 1);

        vm.stopPrank();
        _;
    }

    modifier deployerAddsFirstLiquiditySuccess() {
        vm.startPrank(deployer);

        token0.approve(address(pair), type(uint256).max);
        token1.approve(address(pair), type(uint256).max);

        pair.deposit(10 ether, 10 ether, deployer); // + 10 LP

        (uint128 reserve0, uint128 reserve1) = pair.totalAssets();
        assertEq(reserve0, 10 ether, "unexpected reserve0");
        assertEq(reserve1, 10 ether, "unexpected reserve1");

        assertEq(pair.balanceOf(deployer), 10 ether, "initial share should be sqrt( token0 * token1 )");
        assertEq(pair.totalSupply(), 10 ether, "unexpected total supply");

        vm.stopPrank();
        _;
    }

    function test_deposit() external deployerInit deployerAddsFirstLiquiditySuccess {
        vm.startPrank(deployer);

        vm.stopPrank();
    }

    function test_double_deposits() external deployerInit deployerAddsFirstLiquiditySuccess {
        vm.startPrank(deployer);

        vm.warp(37);
        pair.deposit(20 ether, 20 ether, deployer); // + 20 LP

        (uint128 reserve0, uint128 reserve1) = pair.totalAssets();
        assertEq(reserve0, 30 ether, "unexpected reserve0");
        assertEq(reserve1, 30 ether, "unexpected reserve1");

        uint256 decimalsOffset = 5;
        assertApproxEqAbs(
            pair.balanceOf(deployer),
            30 ether,
            10 * (10 ** decimalsOffset),
            "should approximately equal original + added"
        );
        assertApproxEqAbs(pair.totalSupply(), 30 ether, 10 * (10 ** decimalsOffset), "unexpected total supply");

        vm.stopPrank();
    }

    function test_unbalanced_deposits() external deployerInit deployerAddsFirstLiquiditySuccess {
        vm.startPrank(deployer);

        vm.warp(37);
        pair.deposit(20 ether, 40 ether, deployer); // + 20 LP

        (uint128 reserve0, uint128 reserve1) = pair.totalAssets();
        assertEq(reserve0, 30 ether, "unexpected reserve0");
        assertEq(reserve1, 50 ether, "unexpected reserve1");

        uint256 decimalsOffset = 5;
        assertApproxEqAbs(
            pair.balanceOf(deployer),
            30 ether,
            10 * (10 ** decimalsOffset),
            "should approximately equal original + added"
        );

        vm.stopPrank();
    }

    function test_redeem() external deployerInit deployerAddsFirstLiquiditySuccess {
        vm.startPrank(deployer);

        vm.warp(37);

        uint256 token0BalanceBeforeRedeem = token0.balanceOf(deployer);
        uint256 token1BalanceBeforeRedeem = token1.balanceOf(deployer);

        pair.approve(address(pair), type(uint256).max);
        uint256 shares = pair.balanceOf(deployer); // 10 ether
        pair.redeem(shares, deployer, deployer);

        uint256 token0BalanceAfterRedeem = token0.balanceOf(deployer);
        uint256 token1BalanceAfterRedeem = token1.balanceOf(deployer);

        uint256 decimalsOffset = 5;

        (uint128 reserve0, uint128 reserve1) = pair.totalAssets();
        assertApproxEqAbs(reserve0, 0 ether, 10 * (10 ** decimalsOffset), "unexpected reserve0");
        assertApproxEqAbs(reserve1, 0 ether, 10 * (10 ** decimalsOffset), "unexpected reserve1");

        assertApproxEqAbs(
            pair.balanceOf(deployer),
            0 ether,
            10 * (10 ** decimalsOffset),
            "initial share should be sqrt( token0 * token1 )"
        );
        assertApproxEqAbs(pair.totalSupply(), 0 ether, 10 * (10 ** decimalsOffset), "unexpected total supply");

        assertApproxEqAbs(
            token0BalanceAfterRedeem,
            token0BalanceBeforeRedeem + 10 ether,
            10 * (10 ** decimalsOffset),
            "unexpected token0 balance of deployer"
        );
        assertApproxEqAbs(
            token1BalanceAfterRedeem,
            token1BalanceBeforeRedeem + 10 ether,
            10 * (10 ** decimalsOffset),
            "unexpected token1 balance of deployer"
        );

        vm.stopPrank();
    }

    function test_appoveSomeoneThen_redeem() external deployerInit deployerAddsFirstLiquiditySuccess {
        vm.startPrank(deployer);

        pair.approve(alice, type(uint256).max);
        pair.approve(address(pair), type(uint256).max);

        vm.stopPrank();
        vm.startPrank(alice);

        vm.warp(37);
        
        uint256 token0BalanceBeforeRedeem = token0.balanceOf(alice);
        uint256 token1BalanceBeforeRedeem = token1.balanceOf(alice);

        uint256 shares = pair.balanceOf(deployer); // 10 ether
        pair.redeem(shares, alice, deployer);

        uint256 token0BalanceAfterRedeem = token0.balanceOf(alice);
        uint256 token1BalanceAfterRedeem = token1.balanceOf(alice);

        uint decimalsOffset = 5;

        (uint128 reserve0, uint128 reserve1) = pair.totalAssets();
        assertApproxEqAbs(reserve0, 0 ether, 10*(10**decimalsOffset) , "unexpected reserve0");
        assertApproxEqAbs(reserve1, 0 ether, 10*(10**decimalsOffset), "unexpected reserve1");

        assertApproxEqAbs(pair.balanceOf(deployer), 0 ether, 10*(10**decimalsOffset), "initial share should be sqrt( token0 * token1 )");
        assertApproxEqAbs(pair.totalSupply(), 0 ether, 10*(10**decimalsOffset), "unexpected total supply");

        assertApproxEqAbs(token0BalanceAfterRedeem, token0BalanceBeforeRedeem + 10 ether, 10*(10**decimalsOffset), "unexpected token0 balance of deployer" );
        assertApproxEqAbs(token1BalanceAfterRedeem, token1BalanceBeforeRedeem + 10 ether, 10*(10**decimalsOffset), "unexpected token1 balance of deployer" );

        vm.stopPrank();
    }

    function test_swap() external deployerInit deployerAddsFirstLiquiditySuccess {

        vm.startPrank(alice);

        deal({token: address(token0), to: alice, give: 1 ether});

        uint256 amountOut = 0.90 ether;
        token0.transfer(address(pair), 1 ether);
        pair.swap(0, amountOut, alice);

        assertEq(token0.balanceOf(alice), 0 ether, "unexpected token0 balance" );
        assertEq(token1.balanceOf(alice), 0.90 ether, "unexpected token1 balance" );

        (uint128 reserve0, uint128 reserve1) = pair.totalAssets();
        assertEq(reserve0, 10 ether + 1 ether, "unexpected reserve0");
        assertEq(reserve1, 10 ether - 0.90 ether, "unexpected reserve1");


        vm.stopPrank();

    }

    function test_flashLoan() external deployerInit deployerAddsFirstLiquiditySuccess {
        vm.startPrank(alice);
        deal({token: address(token0), to: alice, give: 1 ether});

        FlashLoanReceiver receiver = new FlashLoanReceiver( address(pair), address(token0), alice );

        token0.transfer(address(receiver), 1 ether);
        uint256 fee = pair.flashFee(address(token0), pair.maxFlashLoan(address(token0)) );
        receiver.borrow();

        (uint128 reserve0, ) = pair.totalAssets();
        assertEq(reserve0, 10 ether + fee, "unexpected reserve0");

        vm.stopPrank();

    }
    
}
