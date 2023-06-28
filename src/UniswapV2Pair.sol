// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import {UniswapVaultToken} from './UniswapVaultToken.sol';


import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";



contract UniswapV2Pair is UniswapVaultToken {

    address public factory;

    uint112 private reserve0;           // uses single storage slot, accessible via getReserves
    uint112 private reserve1;           // uses single storage slot, accessible via getReserves

    constructor() {
        factory = msg.sender;
    }

    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, 'UniswapV2: FORBIDDEN'); // sufficient check
        __UniswapVaultToken_init(IERC20(_token0), IERC20(_token1));
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }

    function totalAssets() public view virtual override returns (uint256 totalManagedAssets_) {

        if (totalSupply() == 0) return 0;

        (uint112 _reserve0, uint112 _reserve1) = getReserves();

        return Math.max(_reserve0, _reserve1);


    }

    function deposit(uint256 assets, address receiver) public virtual override returns (uint256) {
        return 0;
    }


    function mint(uint256 shares, address receiver) public virtual override returns (uint256) {
        return 0;
    }


    function withdraw(uint256 assets, address receiver, address owner) public virtual override returns (uint256) {
        return 0;
    }


    function redeem(uint256 shares, address receiver, address owner) public virtual override returns (uint256){
        return 0;
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override{

    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override{

    }
    

}
