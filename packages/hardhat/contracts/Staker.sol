// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Staker {
    using SafeMath for uint256;

    ExampleExternalContract public exampleExternalContract;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public depositTimestamps;
    mapping(address => bool) public whiteList;
    uint256 public constant rewardInterest = 40; //reward interest per 30 sec in %
    uint256 public withdrawalDeadline = block.timestamp + 120 seconds;
    uint256 public claimDeadline = block.timestamp + 240 seconds;
    uint256 public currentBlock = 0;

    // Events
    event Stake(address indexed sender, uint256 amount);
    event Received(address, uint256);
    event Execute(address indexed sender, uint256 amount);

    // Modifiers
    /*
  Checks if the withdrawal period been reached or not
  */
    modifier withdrawalDeadlineReached(bool requireReached) {
        uint256 timeRemaining = withdrawalTimeLeft();
        if (requireReached) {
            require(timeRemaining == 0, "Withdrawal period is not reached yet");
        } else {
            require(timeRemaining > 0, "Withdrawal period has been reached");
        }
        _;
    }

    /*
  Checks if the claim period has ended or not
  */
    modifier claimDeadlineReached(bool requireReached) {
        uint256 timeRemaining = claimPeriodLeft();
        if (requireReached) {
            require(timeRemaining == 0, "Claim deadline is not reached yet");
        } else {
            require(timeRemaining > 0, "Claim deadline has been reached");
        }
        _;
    }

    /*
  Requires that contract only be completed once!
  */
    modifier notCompleted() {
        bool completed = exampleExternalContract.completed();
        require(!completed, "Stake already completed!");
        _;
    }

    constructor(address exampleExternalContractAddress) {
        exampleExternalContract = ExampleExternalContract(
            exampleExternalContractAddress
        );
    }

    // Stake function for a user to stake ETH in our contract
    function stake()
        public
        payable
        withdrawalDeadlineReached(false)
        claimDeadlineReached(false)
    {
        balances[msg.sender] = balances[msg.sender] + msg.value;
        depositTimestamps[msg.sender] = block.timestamp;
        whiteList[msg.sender] = true;

        emit Stake(msg.sender, msg.value);
    }

    /*
  Withdraw function for a user to remove their staked ETH inclusive
  of both principle and any accured interest
  */
    function withdraw()
        public
        withdrawalDeadlineReached(true)
        claimDeadlineReached(false)
        notCompleted
    {
        require(balances[msg.sender] > 0, "You have no balance to withdraw!");
        uint256 individualBalance = balances[msg.sender];
        uint256 t = block.timestamp - depositTimestamps[msg.sender];
        t=t.div(30);
        uint256 indBalanceRewards = individualBalance+((individualBalance*t*rewardInterest).div(100));
        balances[msg.sender] = 0;

        // Transfer all ETH via call! (not transfer) cc: https://solidity-by-example.org/sending-ether
        (bool sent, bytes memory data) = msg.sender.call{
            value: indBalanceRewards
        }("");
        require(sent, "RIP; withdrawal failed :( ");
    }

    function restore() public claimDeadlineReached(true) {
        require(
            whiteList[msg.sender] == true,
            "You are not whitelisted to restore your balance"
        );
        exampleExternalContract.restore(address(this));
        whiteList[msg.sender] = false;
        claimDeadline = block.timestamp + 240 seconds;
        withdrawalDeadline = block.timestamp + 120 seconds;
    }

    /*
  Allows any user to repatriate "unproductive" funds that are left in the staking contract
  past the defined withdrawal period
  */
    function execute() public claimDeadlineReached(true) notCompleted {
        uint256 contractBalance = address(this).balance;
        exampleExternalContract.complete{value: address(this).balance}();
    }

    /*
  READ-ONLY function to calculate time remaining before the minimum staking period has passed
  */
    function withdrawalTimeLeft()
        public
        view
        returns (uint256 withdrawalTimeLeft)
    {
        if (block.timestamp >= withdrawalDeadline) {
            return (0);
        } else {
            return (withdrawalDeadline - block.timestamp);
        }
    }

    /*
  READ-ONLY function to calculate time remaining before the minimum staking period has passed
  */
    function claimPeriodLeft() public view returns (uint256 claimPeriodLeft) {
        if (block.timestamp >= claimDeadline) {
            return (0);
        } else {
            return (claimDeadline - block.timestamp);
        }
    }

    /*
  Time to "kill-time" on our local testnet
  */
    function killTime() public {
        currentBlock = block.timestamp;
    }

    /*
  \Function for our smart contract to receive ETH
  cc: https://docs.soliditylang.org/en/latest/contracts.html#receive-ether-function
  */
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
