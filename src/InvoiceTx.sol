// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// OpenZeppelinのインターフェースをインポート
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

using SafeERC20 for IERC20;
contract InvoiceTx {

    // 請求書のステータスを定義
    enum InvoiceStatus {
        Unpaid,   // 未払い（有効期限内）
        Paid,     // 支払済み
        Expired,   // 期限切れ
        Undefined   //存在しない
    }

    error InvoiceNotFound();    //インボイスがない
    error TagAlreadyExists();   //使用済みタグ
    error InvoiceAlreadyPaid();     //支払済み
    error InvoiceExpired();     //時間切れ
    
    struct Invoice {
        uint256 tag16;      // 管理番号（4ブロックの数値を結合した値など）
        address payee;      // 受取人アドレス (例: BBBのアドレス)
        address tokenAddress; // ★ 請求書ごとにどのトークンで払うかを保持
        uint256 amount;     // 金額 (JPYC)
        uint256 deadline;   // 締め切り（翌日の00:00:00のUnix time）
        InvoiceStatus status; // 状態をenumで保持
    }

    // キーを「payee + tag16」のハッシュにして一意性を担保する
    mapping(bytes32 => Invoice) public invoices;

    event InvoiceRegistered(bytes32 indexed key, address indexed payee, uint256 amount, uint256 deadline);
    event InvoicePaid(bytes32 indexed key, address indexed payer, uint256 amount);

    // 1. 請求書の発行（トランザクション登録）
    function registerInvoice(
        uint256 tag16,
        address tokenAddress,
        uint256 amount,
        uint256 deadline
    ) external {
        require(tokenAddress != address(0), "Invalid token");
        require(amount > 0, "Invalid amount");

        bytes32 key = keccak256(abi.encodePacked(msg.sender, tag16));
        
        // すでに同じタグが存在しないか確認
        if(invoices[key].payee != address(0)){
            revert TagAlreadyExists(); 
        }

        require(block.timestamp <= deadline, "Invalid deadline");

        invoices[key] = Invoice({
            tag16: tag16,
            payee: msg.sender,
            tokenAddress: tokenAddress,
            amount: amount,
            deadline: deadline,
            status: InvoiceStatus.Unpaid
        });

        emit InvoiceRegistered(key, msg.sender, amount, deadline);
    }

    // 2. 請求書への支払い実行（払い手側からの呼び出し想定）
    function payInvoice(address payee, uint256 tag16) external {
        bytes32 key = keccak256(abi.encodePacked(payee, tag16));
        Invoice memory inv = invoices[key];

        if(inv.payee == address(0)){
            revert InvoiceNotFound();
        }

        // ★ここで getInvoiceStatus を呼んで、ステータスが Unpaid であることを一発で担保する！
        InvoiceStatus currentStatus = getInvoiceStatus(payee, tag16);


        if(currentStatus == InvoiceStatus.Paid){
            revert InvoiceAlreadyPaid();
        }
        if(currentStatus == InvoiceStatus.Expired){
            revert InvoiceExpired();
        }

        // 4. JPYC (ERC-20) の転送実行
        // msg.sender（払い手）から payee（受取人）へ直接トークンを移動させる場合
        IERC20(inv.tokenAddress).safeTransferFrom(msg.sender, payee, inv.amount);

        invoices[key].status = InvoiceStatus.Paid;

        emit InvoicePaid(key, msg.sender, inv.amount);
    }

    function getInvoiceStatus(address payee, uint256 tag16) public view returns (InvoiceStatus) {
    bytes32 key = keccak256(abi.encodePacked(payee, tag16));
    Invoice memory inv = invoices[key];

    //存在しない場合
    if (inv.payee == address(0)) {
        return InvoiceStatus.Undefined;
    }

    if (inv.status == InvoiceStatus.Paid) {
        return InvoiceStatus.Paid;
    }
    
    // 期限を過ぎている場合は Expired を返す
    if (block.timestamp > inv.deadline) {
        return InvoiceStatus.Expired;
    }
    
    return InvoiceStatus.Unpaid;
}
}