# Secret の準備


## 作業内容

1. DB Secret と、チャットツール（Slack／Chatwork）の認証情報用共有 Secret に必要な値を格納する


## 前提条件

- [Slack App の作成](/docs/create_environment/03_1_create_slack_app/README.md) または [Chatwork Webhook の設定](/docs/create_environment/03_2_create_chatwork_webhook/README.md) が完了していること

- 本製品の AI エージェントが使用する DB ユーザーが作成済みであること（本手順書の手順とは別に用意いただく必要があります）


## Secret に格納が必要な項目

> [エージェント構築基盤の準備](/docs/create_environment/01_setup_agent_builder/README.md) の手順で CloudFormation の入力パラメータに Secret ARN を指定せずにスタック作成している場合、自動作成される Secret 名は [エージェント関連リソースの初期構築](/docs/create_environment/02_build_agent/README.md) 手順の [出力結果](/docs/create_environment/02_build_agent/README.md#控えておくべき主要な出力値) で確認できます。

### DB Secret （MySQL 利用時）

| キー（key） | 値（value）                                                               | 使用用途                                                                         |
| ----------- | ------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| username    | （AI エージェントが DB アクセスに使用する DB ユーザー名を入力）           | 本製品の AI エージェントが DB データを参照するための DB ユーザー認証に使用します |
| password    | （AI エージェントが DB アクセスに使用する DB ユーザーのパスワードを入力） | 本製品の AI エージェントが DB データを参照するための DB ユーザー認証に使用します |

### チャットツール認証情報用共有 Secret

| キー（key）            | 値（value）                                  | 使用用途                                                                           |
| :--------------------- | :------------------------------------------- | :--------------------------------------------------------------------------------- |
| SLACK_SIGNING_SECRET   | （Slack App の Signing Secret を入力）       | Slack から本製品の AI エージェントあてに送られたリクエストの認証に使用します       |
| SLACK_BOT_TOKEN        | （Slack App の Bot User OAuth Token を入力） | 本製品の AI エージェントが Slack に回答を送信する際に使用します                    |
| CHATWORK_WEBHOOK_TOKEN | （Chatwork Webhook のトークンを入力）        | Chatwork から受信する Webhook リクエストの署名検証に使用します                     |
| CHATWORK_API_TOKEN     | （Chatwork API トークンを入力）              | 本製品の AI エージェントが Chatwork に受付・回答メッセージを送信する際に使用します |

> `ChatToolsSecretArn` を指定せずにスタックを作成した場合は、`chat_tools_secret_name` の出力値で自動作成された共有 Secret 名を確認できます。Slack と Chatwork を併用する場合は、4 つのキーを同じ Secret に格納してください。

#### Slack Signing Secret の取得方法

1. https://api.slack.com/apps に移動（Slack アカウントでサインイン）
2. 表示された Slack App 一覧から本製品用 Slack App を選択
3. 左サイドメニューの [Basic Information] を選択
4. `Signing Secret` セクションの [Show] をクリックし、表示された値を取得

#### Slack Bot User OAuth Token の取得方法
1. 上記の「Slack Signing Secret の取得方法」1. ~ 2. の要領で本製品用 Slack App の管理画面を開く
2. 左サイドメニューの [OAuth & Permissions] を選択
3. `OAuth Tokens` セクションの [Copy] をクリックして Bot User OAuth Token を取得

#### Chatwork Webhook トークンの取得方法

1. [Chatwork Webhook の設定画面](https://www.chatwork.com/service/packages/chatwork/subpackages/webhook/list.php) に移動（Chatwork アカウントでサインイン）
2. 対象の Webhook の [編集] を選択する
3. Webhook の編集画面に表示される Webhook トークンを取得する

#### Chatwork API トークンの取得方法

1. [Chatwork API トークンの設定画面](https://www.chatwork.com/service/packages/chatwork/subpackages/api/token.php) に移動（Chatwork アカウントでサインイン）
2. `APIトークン` の欄にある [コピー] を選択して API トークンを取得する


## Secret の格納手順（AWS コンソールを使用する場合）

1. AWS コンソールで「AWS Secrets Manager」の画面を開く
2. 左サイドメニューの [シークレット] を選択
3. シークレット一覧から格納先の Secret を開く
4. `シークレットの値` セクションの [シークレットの値を取得する] をクリック
5. [編集する] をクリックし、[キー/値] タブで行を追加して必要な `キー` と `値` を入力
6. 入力内容を確認して [保存] をクリック
7. 入力内容が保存されていることを確認


## 次の手順

[ナレッジベースの準備](/docs/create_environment/05_prepare_knowledgebases/README.md)
