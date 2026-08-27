# Chatwork Webhook の設定

## 作業内容

1. TracisAI の Chatwork 受信 URL を登録した Webhook を作成する

## 前提条件

- [エージェント関連リソースの初期構築](/docs/create_environment/02_build_agent/README.md) が完了していること
- `request_api_urls["chatwork"]` の出力値を確認していること
- Webhook を設定する Chatwork アカウントで API 管理画面を利用できること

## Webhook の作成

1. [Chatwork Webhook の設定画面](https://www.chatwork.com/service/packages/chatwork/subpackages/webhook/list.php) に移動（Chatwork アカウントでサインイン）
2. [新規作成] を選択する
3. `Webhook名` に用途がわかる名前を入力する
4. `Webhook URL` に `request_api_urls["chatwork"]` の値を入力する
5. `イベント` で [アカウントイベント] の「ご自身へのメンション」を選択する
6. [作成] を選択する
7. Webhook の一覧で、作成した Webhook のステータスが「有効」と表示されていることを確認する

> TracisAI は `mention_to_me` イベントだけを処理します。利用する Chatwork ルームで TracisAI の連携アカウントにメンションしてリクエストしてください。

## 次の手順

[Secret の準備](/docs/create_environment/04_prepare_secret/README.md)
