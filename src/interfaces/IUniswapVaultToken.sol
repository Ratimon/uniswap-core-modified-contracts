// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (interfaces/IERC4626.sol)

pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IUniswapVaultToken is IERC20, IERC20Metadata {
    event Deposit(address indexed sender, address indexed owner, uint256 assets0, uint256 assets1, uint256 shares);

    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets0,
        uint256 assets1,
        uint256 shares
    );

    function initialize(address token0_, address token1_, uint8 flashLoanFee_) external;

    function asset0() external view returns (address assetTokenAddress);

    function asset1() external view returns (address assetTokenAddress);

    function totalAssets() external view returns (uint128 totalManagedAssets0, uint128 totalManagedAssets1);

    function convertToShares(uint256 assets0, uint256 assets1) external view returns (uint256 shares);

    function convertToAssets(uint256 shares) external view returns (uint256 assets0, uint256 assets1);

    function maxDeposit(address receiver) external view returns (uint256 maxAssets0, uint256 maxAssets1);

    function previewDeposit(uint256 assets0, uint256 assets1) external view returns (uint256 shares);

    function deposit(uint256 assets0, uint256 assets1, address receiver) external returns (uint256 shares);

    // function maxMint(address receiver) external view returns (uint256 maxShares);

    // function previewMint(uint256 shares) external view returns (uint256 assets0, uint256 assets1);

    // function mint(uint256 shares, address receiver) external returns (uint256 assets0, uint256 assets1);

    // function maxWithdraw(address owner) external view returns (uint256 maxAssets0, uint256 maxAssets1 );

    // function previewWithdraw(uint256 assets0, uint256 assets1) external view returns (uint256 shares);

    // function withdraw(uint256 assets0, uint256 assets1, address receiver, address owner) external returns (uint256 shares);

    function maxRedeem(address owner) external view returns (uint256 maxShares);

    function previewRedeem(uint256 shares) external view returns (uint256 assets0, uint256 assets1);

    function redeem(uint256 shares, address receiver, address owner)
        external
        returns (uint256 assets0, uint256 assets1);

    function swap(uint amount0Out, uint amount1Out, address receiver) external;
}
