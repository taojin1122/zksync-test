/**
 *Submitted for verification at Etherscan.io on 2019-11-14
*/

// hevm: flattened sources of /nix/store/im7ll7dx8gsw2da9k5xwbf8pbjfli2hc-multicall-df1e59d/src/Multicall.sol
pragma solidity >=0.5.0;
pragma experimental ABIEncoderV2;

////// /nix/store/im7ll7dx8gsw2da9k5xwbf8pbjfli2hc-multicall-df1e59d/src/Multicall.sol
/* pragma solidity >=0.5.0; */
/* pragma experimental ABIEncoderV2; */

/// @title Multicall - Aggregate results from multiple read-only function calls
/// @author Michael Elliot <mike@makerdao.com>
/// @author Joshua Levine <joshua@makerdao.com>
/// @author Nick Johnson <arachnid@notdot.net>

// 这是一个名为 Multicall 的合约，用于在以太坊上聚合多个只读函数调用的结果。
contract Multicall {
    // Call 结构：定义了一个只读函数调用的目标地址（target）和调用数据（callData）
    struct Call {
        address target;
        bytes callData;
    }
    //接收一个 Call 数组，对每个调用进行迭代，执行函数调用，检查成功，并将返回的数据存储在 returnData 中。
    // 最后，返回块号和所有调用的返回数据。
    function aggregate(Call[] memory calls) public returns (uint256 blockNumber, bytes[] memory returnData) {
        blockNumber = block.number;
        returnData = new bytes[](calls.length);
        for(uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.call(calls[i].callData);
            require(success);
            returnData[i] = ret;
        }
    }
    // Helper functions
    function getEthBalance(address addr) public view returns (uint256 balance) {
        balance = addr.balance;
    }
    function getBlockHash(uint256 blockNumber) public view returns (bytes32 blockHash) {
        blockHash = blockhash(blockNumber);
    }
    function getLastBlockHash() public view returns (bytes32 blockHash) {
        blockHash = blockhash(block.number - 1);
    }
    function getCurrentBlockTimestamp() public view returns (uint256 timestamp) {
        timestamp = block.timestamp;
    }
    function getCurrentBlockDifficulty() public view returns (uint256 difficulty) {
        difficulty = block.difficulty;
    }
    function getCurrentBlockGasLimit() public view returns (uint256 gaslimit) {
        gaslimit = block.gaslimit;
    }
    function getCurrentBlockCoinbase() public view returns (address coinbase) {
        coinbase = block.coinbase;
    }
}