// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
//import "@openzeppelin/contracts/access/Ownable.sol";

contract WETHToken is ERC20 {
     // Event for deposit and withdrawal
    event Deposit(address indexed account, uint256 amount);
    event Withdraw(address indexed account, uint256 amount);

    constructor() ERC20("Wrapped Ether", "WETH") {
        //super(); // Call the base contract's constructor
    }

    // Deposit Ether and mint Wrapped Token
    function deposit() external payable {
        require(msg.value > 0, "Cannot deposit zero Ether");

        // Mint equivalent WETH to the sender
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    // Withdraw WETH and receive Ether
    function withdraw(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        // Burn WETH from the sender
        _burn(msg.sender, amount);

        // Transfer the equivalent Ether back to the sender
        payable(msg.sender).transfer(amount);
        emit Withdraw(msg.sender, amount);
    }

    // Prevent accidental Ether transfers directly to the contract
    receive() external payable {
        revert("Send Ether via the deposit function");
    }
}
