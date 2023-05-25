// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPancakeFactory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint
    );

    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);

    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);
}

interface IPancakeRouter02 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )
        external
        payable
        returns (uint amountToken, uint amountETH, uint liquidity);
}

contract PepePoliceToken is ERC20, Ownable {
    using SafeMath for uint256;

    mapping(address => bool) controllers;

    uint256 constant MAXIMUMSUPPLY = 100_000_000_000 * 10 ** 18;

    IPancakeRouter02 public router;
    address public pair;
    uint256 public sellTax;
    uint256 public buyTax;

    constructor() ERC20("PepePoliceToken", "PPT") {
        address _router = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1;
        router = IPancakeRouter02(_router);
        pair = IPancakeFactory(router.factory()).createPair(
            router.WETH(),
            address(this)
        );
        sellTax = 5;
        buyTax = 3;

        _mint(msg.sender, 73_000_000_000 * 10 ** 18); // 7% for team, 20% for marketing
        emit Transfer(address(0), msg.sender, totalSupply());
    }

    function mint(address to, uint256 amount) external {
        require(controllers[msg.sender], "Only controllers can mint");
        require(
            (totalSupply() + amount) <= MAXIMUMSUPPLY,
            "Maximum supply has been reached"
        );
        _mint(to, amount);
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transferFromFee(msg.sender, recipient, amount);
        return true;
    }

    function _transferFromFee(address sender, address recipient, uint256 amount) internal  returns (bool) {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        uint256 taxAmount = 0;

        if (sender == pair) {
            // This is a buy transaction
            taxAmount = amount.mul(buyTax).div(100); // 3% tax for buys
        } else if (recipient == pair) {
            // This is a sell transaction
            taxAmount = amount.mul(sellTax).div(100); // 5% tax for sells
        } else {
            // This is a normal transfer
            taxAmount = 0;
        }

        uint256 transferAmount = amount.sub(taxAmount);

        _transfer(sender, recipient, transferAmount);
        _transfer(sender, owner(), taxAmount);

        emit Transfer(sender, recipient, transferAmount);
        return true;
    }

    function setTax(uint256 buy, uint256 sell) external {
        require(
            (controllers[msg.sender]) || (msg.sender == owner()),
            "Only owner and controller is allowed"
        );
        sellTax = sell;
        buyTax = buy;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {

        _transferFromFee(sender, recipient, amount);
        _approve(
            sender,
            msg.sender,
            allowance(sender, msg.sender).sub(amount)
        );
        return true;
    }

    function burnFrom(address account, uint256 amount) public {
        _burn(account, amount);
    }

    function addController(address controller) external onlyOwner {
        controllers[controller] = true;
    }

    function removeController(address controller) external onlyOwner {
        controllers[controller] = false;
    }

    function maxSupply() public pure returns (uint256) {
        return MAXIMUMSUPPLY;
    }

    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
}
