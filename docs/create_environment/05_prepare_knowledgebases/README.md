# ナレッジベースの準備


## 作業内容

1. ナレッジベース同期用 S3 バケットにエージェントに参照させたいデータをアップロードする
2. ナレッジベース同期用 S3 バケットにアップロードしたデータをナレッジベースに同期する


## 前提条件

- [エージェント関連リソースの初期構築](/docs/create_environment/02_build_agent/README.md) までの手順が完了し、[`knowledge_base_data_source_bucket_name`](/docs/create_environment/02_build_agent/README.md#控えておくべき主要な出力値) の S3 バケットが作成されていること

## ナレッジベースにアップロードが必要な情報
- 探索対象となるロググループの情報 ~ ※1
- ログやデータベースに関するメタ情報 ~ ※2

**※1 本製品ではナレッジベースの情報を元に探索対象のロググループを決定・調査する仕様のため、探索対象のロググループ情報をアップロードする必要があります。**
**※2 本製品による調査精度を向上させるためにはロググループやデータベースに関するメタ情報をアップロードしてください。**

### 「ログやデータベースに関するメタ情報」の例

例えば次に記載するような内容を情報として含めていただくことで、本製品による調査精度の向上が見込まれます。

- どのロググループにどのような内容のログが入っているかなどのメタ情報
- ログの正常系・異常系の判断基準
- データベースのどのテーブルにどのような情報が保存されているかなどのメタ情報
- ロググループとデータベースの相関関係

#### Amazon CloudWatch ロググループ情報の記載例
 
````
# ログ調査ナレッジベース

## EC注文系API

log_group:
`API-Gateway-Execution-Logs_qldo7qqb71/api`

description:
EC注文・決済関連APIのログ

keywords:

* 注文
* 決済
* payment
* order
* card
* checkout

status_codes:

| code      | 日本語           | 用途         |
| --------- | ---------------- | ------------ |
| ORDER_000 | 注文成功         | success      |
| ORDER_001 | 在庫不足         | 業務エラー   |
| ORDER_002 | 注文タイムアウト | システム障害 |
| ORDER_003 | DBエラー         | システム障害 |
| ORDER_004 | 外部APIエラー    | 外部依存障害 |



sample_logs:

```json
{
  "timestamp": "2026-05-05 02:01:13",
  "request_id": "payment-2521072",
  "user_id": 8191,
  "order_id": 2531931,
  "payment_id": 2521072,
  "action": "payment_process",
  "status": "failed",
  "error": "card_declined"
}
```

```json
{
  "timestamp": "2026-05-05 16:48:58",
  "request_id": "order-2531932",
  "user_id": 8294,
  "order_id": 2531932,
  "product_id": 84,
  "action": "order_create",
  "status": "success",
  "error": null,
  "total_price": 26271
}
```
````

#### データベーススキーマ情報の記載例

````
# schema_overview

## tables

| テーブル名    | 説明                 |
| ------------- | -------------------- |
| `users`       | ユーザーアカウント   |
| `products`    | 商品マスタ           |
| `orders`      | 注文ヘッダー         |
| `order_items` | 注文明細             |
| `payments`    | 決済情報             |
| `batch_jobs`  | バッチジョブ実行履歴 |

---

## relationships

| 関係                       | カーディナリティ     | 外部キー                                 |
| -------------------------- | -------------------- | ---------------------------------------- |
| `users` → `orders`         | 1 対 多              | `orders.user_id` → `users.id`            |
| `orders` → `order_items`   | 1 対 多              | `order_items.order_id` → `orders.id`     |
| `products` → `order_items` | 1 対 多              | `order_items.product_id` → `products.id` |
| `orders` → `payments`      | 1 対 多              | `payments.order_id` → `orders.id`        |
| `batch_jobs`               | 独立（外部キーなし） | —                                        |

````
````
# orders

description: ユーザーの注文ヘッダー情報を管理するテーブル

keywords: orders, 注文, order, user, status, total_price, shipping, 配送, 合計金額, completed

## relations
- `users.id` ← `user_id`

## columns

| column        | type        | description                                            |
| ------------- | ----------- | ------------------------------------------------------ |
| id            | int         | 主キー                                                 |
| user_id       | int         | 注文したユーザーID（FK → users.id）                    |
| status        | varchar(50) | 注文ステータス（例: `completed`）                      |
| total_price   | int         | 注文合計金額                                           |
| created_at    | datetime    | 注文作成日時                                           |
| shipping_info | json        | 配送先情報（keys: `name`, `phone`, `address`, `note`） |

````
````
# payments

description: 注文に紐づく決済情報を管理するテーブル

keywords: payments, 決済, payment, order, stripe, provider, token, status, card, 支払い

## relations
- `orders.id` ← `order_id`

## columns

| column                 | type         | description                                                                                             |
| ---------------------- | ------------ | ------------------------------------------------------------------------------------------------------- |
| id                     | int          | 主キー                                                                                                  |
| order_id               | int          | 紐づく注文ID（FK → orders.id）                                                                          |
| status                 | varchar(50)  | 決済ステータス（例: `success`）                                                                         |
| provider               | varchar(50)  | 決済プロバイダー名（例: `stripe`）                                                                      |
| created_at             | datetime     | レコード作成日時                                                                                        |
| payment_method_details | json         | 決済手段の詳細情報（keys: `type`, `brand`, `last4`, `expiry`, `cardholder_name`, `card_number_masked`） |
| payment_token          | varchar(100) | 決済プロバイダー発行のトークン（例: `tok_XXXXXXXX`）                                                    |


## payments.last_error_code

| code        | 日本語           |
| ----------- | ---------------- |
| PAYMENT_001 | カード拒否       |
| PAYMENT_002 | 残高不足         |
| PAYMENT_003 | 決済事業者エラー |
| PAYMENT_004 | 決済タイムアウト |
| PAYMENT_005 | 決済DBエラー     |
````


## データのアップロード手順

1. AWS コンソールで「Amazon S3」の画面を開く 
2. 左サイドメニューの [汎用バケット] を選択
3. `バケット` 一覧から [`knowledge_base_data_source_bucket_name`](/docs/create_environment/02_build_agent/README.md#控えておくべき主要な出力値) で確認した名前のバケットを開く
4. `オブジェクト` セクションの [アップロード] をクリック
5. 準備したファイルをアップロード画面に追加して `アップロード` をクリック
6. ファイルがアップロードされていることを確認する


## ナレッジベースの同期手順

1. AWS コンソールで「Amazon Bedrock」の画面を開く 
2. 左サイドメニューの [ナレッジベース] を選択し、対象のナレッジベースをクリック
3. `データソース` セクションの対象のデータソースを選択する
4. [同期] をクリック
5. ステータスが `進行中` から `利用可能` に変わったことを確認する


## エージェント起動後のデータ更新手順
1. 上記の「データのアップロード手順」を参考にナレッジベース同期用 S3 バケットの内容を更新する
2. 上記の「ナレッジベースの同期手順」の要領でナレッジベースの同期を行う
3. エージェント（ECS Service）が起動済みの場合、エージェントを一旦停止させて再起動する（[エージェント（ECS Service）の起動・停止](/docs/create_environment/07_agent_start_stop/README.md) 参照）


## 次の手順

[Anthropic モデルアクセスの有効化](/docs/create_environment/06_enable_anthropic_model_access/README.md)
