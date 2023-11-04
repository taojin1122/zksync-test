//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.8;

contract Transfer {

    mapping(address=>bool) private payAddressMap;
    mapping(address=>uint256) private addressBalanceMap;


    uint256 private payFee = 5000000000000000;



    address private owner;

    modifier isOwner(){
        require(msg.sender == owner, "Caller is not owner");
        _;
    }
    
    constructor(address[] memory initAddress) {
        owner = msg.sender;
        for(uint i=0; i < initAddress.length; i++) {
            payAddressMap[initAddress[i]] = true;
        }
    }
    
    function setTransferAddress () public payable {
		require(!payAddressMap[msg.sender], "Address is already set");
		require(msg.value >= payFee, "Insufficient payment");

		// Transfer the excess amount back to the sender
        addressBalanceMap[msg.sender] = msg.value - payFee;
		payAddressMap[msg.sender] = true;
    }

    // 返回合约ETH余额
    function getBalance() view public returns(uint) {
        return address(this).balance;
    }
    

    function checkAddressExists(address _address) public view  returns(bool) {
        return payAddressMap[_address];
    }

    function transferTo(address payable _to, uint256  _amount) public  {
        require(payAddressMap[msg.sender], "Sender address is not allowed to transfer");
		require(addressBalanceMap[msg.sender] >= _amount, "Insufficient balance");
		
        addressBalanceMap[msg.sender] -= _amount;
        _to.transfer(_amount);
    }

    // receive方法，接收eth时被触发
    receive() external payable{
        if(!payAddressMap[msg.sender]) {
            if(msg.value >= payFee) {
                uint256 amount = msg.value - payFee;
                addressBalanceMap[msg.sender] = amount;
                payAddressMap[msg.sender] = true;
            } else {
                addressBalanceMap[msg.sender] = msg.value;
            }
        } else {
            addressBalanceMap[msg.sender] += msg.value;
        }
    }
    

    function getPayBalance() view public returns(uint256) {
        return addressBalanceMap[msg.sender];
    }

    function withdraw () public isOwner payable  {
         payable(owner).transfer(address(this).balance);
    }

    function setPayAddressMap(address _address) public isOwner {
         payAddressMap[_address] = true;
    }

}
