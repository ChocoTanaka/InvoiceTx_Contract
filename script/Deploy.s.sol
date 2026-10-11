// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/InvoiceTx.sol";

contract DeployScript is Script {
    function run() external {
        // 環境変数からデプロイ用アカウントの秘密鍵を取得
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // トランザクション送信開始
        vm.startBroadcast(deployerPrivateKey);

        // コントラクトのデプロイ
        InvoiceTx escrow = new InvoiceTx();

        // 送信終了
        vm.stopBroadcast();

        console.log("InvoiceTx deployed to:", address(escrow));
    }
}