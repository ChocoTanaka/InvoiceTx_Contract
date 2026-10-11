// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/InvoiceTx.sol";

contract InvoiceTest is Test {
    InvoiceTx manager;
    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        manager = new InvoiceTx();
    }

    // 1. 請求書の発行とステータス確認のテスト
    function testRegisterAndStatus() public {
        vm.prank(alice);
        uint256 tag16 = 2026101112345678;
        uint256 amount = 10000;
        uint256 deadline = block.timestamp + 1 days;

        manager.registerInvoice(tag16, amount, deadline);

        // ステータスが Unpaid であることの確認
        InvoiceTx.InvoiceStatus status = manager.getInvoiceStatus(alice, tag16);
        assertEq(uint(status), uint(InvoiceTx.InvoiceStatus.Unpaid));
    }

    // 2. 支払いが成功し、Paid に変わるテスト
    function testPayInvoice() public {
        uint256 tag16 = 2026101112345678;
        uint256 amount = 10000;
        uint256 deadline = block.timestamp + 1 days;

        // Aliceが請求書を発行
        vm.prank(alice);
        manager.registerInvoice(tag16, amount, deadline);

        // Bobが支払いを実行
        vm.prank(bob);
        manager.payInvoice(alice, tag16);

        // ステータスが Paid に変わっていることの確認
        InvoiceTx.InvoiceStatus status = manager.getInvoiceStatus(alice, tag16);
        assertEq(uint(status), uint(InvoiceTx.InvoiceStatus.Paid));
    }

    // 3. 期限切れ（Expired）のテスト
    function testExpiredInvoice() public {
        uint256 tag16 = 2026101112345678;
        uint256 amount = 10000;
        uint256 deadline = block.timestamp + 1 days;

        vm.prank(alice);
        manager.registerInvoice(tag16, amount, deadline);

        // 時間を期限の翌日まで進める (warp)
        vm.warp(deadline + 1 hours);

        // ステータスが Expired になっていることの確認
        InvoiceTx.InvoiceStatus status = manager.getInvoiceStatus(alice, tag16);
        assertEq(uint(status), uint(InvoiceTx.InvoiceStatus.Expired));
    }
}