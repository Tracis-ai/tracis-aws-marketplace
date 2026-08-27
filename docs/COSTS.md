# 参考コスト

本ドキュメントに記載されている料金は参考値です。
実際の費用は、ログ量、利用頻度、利用モデル、AWSリージョン等により変動します。

## 想定インフラ構成（ap-northeast-1 / 東京リージョン）

### リクエスト受信・実行インフラ

* チャットツール（Slack／Chatwork）
* Amazon Bedrock AgentCore Runtime
* Amazon API Gateway / AWS Lambda / Amazon SQS
* Amazon Bedrock Knowledge Bases

### 想定月額（参考）

AgentCore Runtime、API Gateway、Lambda、SQS、Knowledge Bases、データ転送量、CloudWatch Logs 出力量は、実行回数や処理時間によって変動します。

---

## AI 利用料（参考）

本製品は利用状況に応じて AWS 利用料金および AI 利用料金が発生します。
以下は、ユーザー環境で別途発生する Amazon Bedrock（Claude Sonnet）利用料の参考値です。

対象モデル:

* Claude Sonnet 4.6

---

### 1 回あたりの推定 AI 利用料

| 処理内容       | トークン構成                                                       | 推定料金            |
| -------------- | ------------------------------------------------------------------ | ------------------- |
| 識別子あり検索 | Cache Read 25,000 / Cache Write 10,000 / Input 200 / Output 1,500  | 約 $0.02〜0.04 / 回 |
| 識別子なし検索 | Cache Read 150,000 / Cache Write 70,000 / Input 700 / Output 3,500 | 約 $0.15〜0.30 / 回 |

---

## 料金試算条件（参考環境）

以下の環境を前提とした参考値です。

### 検索対象データベース

* Amazon RDS for MySQL
* テーブル数: 6

  * マスターテーブル: 2
  * トランザクションテーブル: 4
* データ量:

  * 各テーブルあたり 約15万レコード / 日

### CloudWatch Logs

* ロググループ数: 3
* データ量:

  * 各ロググループあたり 約15万レコード / 日

---

## 備考

* 価格改定により参考コストと乖離が生じる場合があります。
* Prompt Cache（Cache Read / Cache Write）を活用することで、継続利用時のトークンコスト削減を行っています。
* 実際の料金は、検索対象データ量・検索条件・応答長・利用頻度等により変動します。
* NAT Gateway、VPC Endpoint の料金は本試算には含んでおりません。
