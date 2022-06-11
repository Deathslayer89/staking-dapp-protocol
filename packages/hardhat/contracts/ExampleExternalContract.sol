// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

contract ExampleExternalContract {

  bool public completed;

  function complete() public payable {
    completed = true;
  }

  function restore(address staker) public payable{
    uint256 amount = address(this).balance;
  (bool sent, bytes memory data) = staker.call{value: amount}("");
    require(sent, "restoration failed :( ");
    completed=false;
  }
}
