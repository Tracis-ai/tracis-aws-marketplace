# Secret の準備


## 作業内容

1. DB secret、Slack secret のそれぞれに必要な値を格納する


## 前提条件

- [Slack App の作成](/docs/create_environment/03_create_slack_app/README.md) までの手順が完了していること

- 本製品の AI エージェントが使用する DB ユーザーが作成済みであること（本手順書の手順とは別に用意いただく必要があります）


## Secret に格納が必要な項目

### DB secret

> [エージェント構築基盤の準備](/docs/create_environment/01_setup_agent_builder/README.md) の手順で `MySqlSecretArn` を未指定でスタック作成した場合に自動作成される Secret 名は [`mysql_secret_name`](/docs/create_environment/02_build_agent/README.md#控えておくべき主要な出力値) で確認できます。

| キー（key） | 値（value）                                                          | 使用用途                                                                         |
| ----------- | -------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| username    | （AIエージェントがDBアクセスに使用するDBユーザー名を入力）           | 本製品の AI エージェントが DB データを参照するための DB ユーザー認証に使用します |
| password    | （AIエージェントがDBアクセスに使用するDBユーザーのパスワードを入力） | 本製品の AI エージェントが DB データを参照するための DB ユーザー認証に使用します |


### Slack secret

> [エージェント構築基盤の準備](/docs/create_environment/01_setup_agent_builder/README.md) の手順で `SlackSecretArn` を未指定でスタック作成した場合に自動作成される Secret 名は [`slack_secret_name`](/docs/create_environment/02_build_agent/README.md#控えておくべき主要な出力値) で確認できます。

| キー（key）     | 値（value）                            | 使用用途                                                                                                             |
| :-------------- | :------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| SIGNING_SECRET  | （Slack App の Signing Secret）        | Slack から本製品の AI エージェントあてに送られたリクエストの認証に使用します                                         |
| SLACK_BOT_TOKEN | （Slack App の Bot User OAuth Token ） | 本製品の AI エージェントがSlackに回答を送信する際に使用し、Slackあてのメッセージ送信リクエストの認証時に参照されます |

#### Signing Secret の取得方法

1. https://api.slack.com/apps に移動（Slack アカウントでサインイン）
2. 表示された Slack App 一覧から本製品用 Slack App を選択
3. 左サイドメニューの [Basic Information] を選択
4. `Signing Secret` セクションの [Show] をクリックし、表示された値を取得

#### Bot User OAuth Token の取得方法
1. 上記の「Signing Secret の取得方法」1. ~ 2. の要領で本製品用 Slack App の管理画面を開く
2. 左サイドメニューの [OAuth & Permissions] を選択
3. `OAuth Tokens` セクションの [Copy] をクリックして Bot User OAuth Token を取得


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
