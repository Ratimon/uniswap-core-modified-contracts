// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {IUniswapV2Factory} from "@main/interfaces/IUniswapV2Factory.sol";
import {UniswapV2PairVault} from "@main/UniswapV2PairVault.sol";

contract UniswapV2Factory is IUniswapV2Factory {

    uint8 public flashLoanFee;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    constructor(uint8 _flashLoanFee ) {
        flashLoanFee = _flashLoanFee;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(UniswapV2PairVault).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        UniswapV2PairVault(pair).initialize(token0, token1, flashLoanFee);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }


}