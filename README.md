# 請求書付きトランザクションのスマートコントラクト
TANAKA SENKI　代表　田中　直行


## 参考
これを運用するにあたって以下のスマートコントラクトを書くことにした。<br>
[リンク](https://github.com/ChocoTanaka/Metamask_EIP-681_Pay_Web)

## 概要
現在のトランザクションは証憑の突合作業に大きなコストをかけることとなり、実際に運用するに
あたって大きな問題がある。
そのため、請求書とトランザクションを連動することのできるスマートコントラクトを作成した。

## 構造

```
struct Invoice {
        uint256 tag16;      // 管理番号（MetaMask JPYC Sub-Payment Systemにおける、16桁のID）
        address payee;      // 受取人アドレス (例: BBBのアドレス)
        uint256 amount;     // 金額 (JPYC)
        uint256 deadline;   // 締め切り（翌日の00:00:00のUnix time）
        InvoiceStatus status; // 状態をenumで保持
    }

    // 請求書のステータスを定義
    enum InvoiceStatus {
        Unpaid,   // 未払い（有効期限内）
        Paid,     // 支払済み
        Expired   // 期限切れ
    }
```

```
// 1. 請求書の発行（トランザクション登録）
    function registerInvoice(
        uint256 tag16,
        uint256 amount,
        uint256 deadline
    ) external {
        bytes32 key = keccak256(abi.encodePacked(msg.sender, tag16));
        
        // すでに同じタグが存在しないか確認
        require(invoices[key].payee == address(0), "Invoice already exists");
        require(block.timestamp <= deadline, "Invalid deadline");

        invoices[key] = Invoice({
            tag16: tag16,
            payee: msg.sender,
            amount: amount,
            deadline: deadline,
            status: InvoiceStatus.Unpaid
        });

        emit InvoiceRegistered(key, msg.sender, amount, deadline);
    }
```

これを通して請求書インデックスを作成する。また、請求書支払い時にこのデータは参照されるものとする。

```
// 2. 請求書への支払い実行（払い手側からの呼び出し想定）
    function payInvoice(address payee, uint256 tag16) external payable {
        bytes32 key = keccak256(abi.encodePacked(payee, tag16));
        Invoice memory inv = invoices[key];

        require(inv.payee != address(0), "Invoice not found");
        require(inv.status == InvoiceStatus.Paid, "Already paid");
        require(block.timestamp <= inv.deadline, "Invoice expired");

        // ※実際にはここで ERC-20 (JPYC) の transferFrom などが入る
        invoices[key].status = InvoiceStatus.Paid;

        emit InvoicePaid(key, msg.sender, inv.amount);
    }
```

先ほど作成した請求書インデックスに対し、支払を行う。

## 実用
現在テスト運用中