# Slack App の作成


## 作業内容

1. エージェントとの会話に使用するための Slack App を新規作成する
2. 作成した Slack App に必要な設定を行う
3. 作成した Slack App を使用するために Slack チャンネルに招待する


## 前提条件

- [エージェント関連リソースの初期構築](/docs/create_environment/02_build_agent/README.md) までの手順が完了していること

- 上記手順で [`slack_receive_api_url`](/docs/create_environment/02_build_agent/README.md#控えておくべき主要な出力値) を確認していること

- 登録済みの Slack アカウントを所持していること


## Slack App の作成手順

1. https://api.slack.com/apps に移動（Slack アカウントでサインイン）
2. [Create New App] をクリック
3. [From scratch]を選択
4. `App Name` にアプリ名を入力
5. `Pick a workspace to develop your app in:` に導入先の Slack Workspace を選択
6. [Create App] をクリックし、新しい Slack App が追加されていることを確認


## Slack App の設定手順

### Event Subscriptions の設定

1. 作成した Slack App の管理画面において、左サイドメニューの [Event Subscriptions] を選択
2. `Enable Events` のトグルスイッチを **On** に切り替え
3. [`slack_receive_api_url`](/docs/create_environment/02_build_agent/README.md#控えておくべき主要な出力値) の値を `Request URL` に入力
4. `Subscribe to bot events` セクションで [Add Bot User Event] をクリックし、次のイベントを追加
  - `app_mention`
5. 画面右下の [Save Changes] をクリックし、設定が保存されていることを確認

### 権限の設定

1. 左サイドメニューの [OAuth & Permissions] を選択
2. `スコープ` セクションの `ボットトークンのスコープ` で [OAuth スコープを追加する] をクリックし、次の権限を追加
  - `app_mentions:read`
  - `chat:write`
3. 権限が追加されていることを確認

### Workspace へのインストール

1. 左サイドメニューの [Install App] を選択
2. [Install to <ワークスペース名>] をクリック
3. Slack へのアクセス許可確認画面に遷移するので [許可する] をクリック
4. Slack App が Workspace にインストール済みであることを確認


## Slack App のチャンネル招待手順

1. Slack App を使用したい Slack チャンネルを開く
2. 下記メッセージを送信し、Slack App を招待
  ```
  /invite @<Slack App の名前>
  ```
3. Slack App が招待されていることを確認


## 次の手順
[Secret の準備](/docs/create_environment/04_prepare_secret/README.md)
