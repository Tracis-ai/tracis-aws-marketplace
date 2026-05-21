# Anthropic モデルアクセスの有効化


## 作業内容

1. Anthropic モデルアクセスに必要なユーザーユースケースの提出を行い、Amazon Bedrock サービスを介する Anthropic モデルへのアクセスを有効化する


## 前提条件

- 利用する AWS アカウントまたは同アカウントが所属する AWS Organization の Amazon Bedrock サービスを通じてこれまでに Anthropic モデルにアクセスしたことがないこと
- 作業者に Amazon Bedrock のモデルアクセス権限があること


## 提出が必要な情報
以下の情報の入力を求められます。あらかじめ内容を整理しておいてください。

- 会社名 / 組織名
- WebサイトのURL
- 事業を展開している業界
- AIエージェントを使用する対象ユーザー
- ユースケースの内容

#### 参考ドキュメント

 - [モデルへのアクセスをリクエストする - Amazon Bedrock ~ ステップ 2: [Anthropic モデルでのみ 1 回のみ必要] 初めて使用するユーザーのユースケースを設定する](https://docs.aws.amazon.com/ja_jp/bedrock/latest/userguide/model-access.html#model-access-sdk-step2)


## Anthropic モデルアクセスの有効化手順

### ユーザーユースケースの提出

1. AWS コンソールで「Amazon Bedrock」の画面を開く
2. 左サイドメニューの [モデルカタログ] を選択
3. 一覧から利用したい Anthropic モデル（例：`Claude Sonnet 4.6`）をクリック
4. モデル詳細画面の右上にある [プレイグラウンドで開く] をクリック
5. ユースケース提出フォームが表示されるため、提出が必要な情報を入力し [Submit use case details] をクリック  
   
    **※ ユースケース提出フォームが表示されるのは利用中の AWS アカウントまたは AWS Organization で Anthropic モデルに初めてアクセスする場合のみです。ユースケース提出フォームが表示されない場合は本ページの手順は不要です。**

    | パラメータ名                                                                                                 | 説明                                 | 入力例・補足                                      |
    | :----------------------------------------------------------------------------------------------------------- | :----------------------------------- | :------------------------------------------------ |
    | **Company name**                                                                                             | 会社名 / 組織名                      | `株式会社BTM`                                     |
    | **Company website URL**                                                                                      | WebサイトのURL                       | `https://www.example.com`                         |
    | **What industry do you operate in?**                                                                         | 事業を展開している業界               | `Customer Service`                                |
    | **Who are the intended users you are building for?**                                                         | AIエージェントを使用する対象ユーザー | `Internal users (employees, staff, team members)` |
    | **Describe your use cases (do not share any Personally Identifiable Information or Intellectual Property).** | ユースケースの内容                   | `ログの分析・調査`                                |


### モデルアクセスの確認

1. ユースケース提出完了後、Amazon Bedrock プレイグラウンドで Anthropic モデルが指定されている状態で任意のプロンプトを送信（例：`こんにちは`）
2. モデル呼び出しが成功し、モデルから回答がレスポンスされることを確認する


## 次の手順

[エージェント（ECS Service）の起動・停止](/docs/create_environment/07_agent_start_stop/README.md)
