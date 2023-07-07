// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {UniswapV2PairVault} from "@main/UniswapV2PairVault.sol";

contract FlashLoanReceiver is IERC3156FlashBorrower {
    UniswapV2PairVault pool;
    IERC20 token;
    address receiver;

    error UnsupportedCurrency();

    constructor(address _pool, address _token, address _receiver) {
        pool = UniswapV2PairVault(_pool);
        token = IERC20(_token);
        receiver = _receiver;
    }

    function borrow() external {
        pool.flashLoan(
            IERC3156FlashBorrower(address(this)), address(token), pool.maxFlashLoan(address(token)), bytes("")
        );
    }

    function onFlashLoan(address, address _token, uint256 amount, uint256 fee, bytes calldata)
        external
        returns (bytes32)
    {
        uint256 amountToBeRepaid = amount + fee;
        SafeERC20.safeTransfer(IERC20(_token), address(pool), amountToBeRepaid);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
