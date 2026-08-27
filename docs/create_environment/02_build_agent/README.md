# エージェント関連リソースの初期構築


## 作業内容

1. CodeBuild を実行し、Terraform でエージェント関連リソースを構築する
2. Terraform の出力結果を確認し、後続の手順で必要となる値（チャットツール（Slack／Chatwork）用リクエスト URL、Secret 名など）を控える


## 前提条件

- [エージェント構築基盤の準備](/docs/create_environment/01_setup_agent_builder/README.md) の手順が完了していること


## Terraform により作成されるリソース

エージェント関連リソースの初期構築では、主に以下のリソースが作成されます（プレフィックスは CloudFormation スタックで指定した `Prefix` 値が使用されます）。

### エージェント実行基盤（AgentCore Runtime / ネットワーク）

| 種別                 | リソース名（例）                            | 用途                                                                                                                       |
| :------------------- | :------------------------------------------ | :------------------------------------------------------------------------------------------------------------------------- |
| AgentCore Runtime    | `[prefix]_tracis_ai_agent`                  | TracisAI Agent を実行する AgentCore Runtime。Prefix 内のハイフンはアンダースコアに置換され、Runtime 名は最大 48 文字です。 |
| セキュリティグループ | `[prefix]-tracis-ai-agentcore-runtime-sg`   | AgentCore Runtime から AWS サービスおよび接続先 DB へ通信するためのセキュリティグループ                                    |
| IAM ロール           | `[prefix]-tracis-ai-agentcore-runtime-role` | AgentCore Runtime が ECR、Bedrock、Secrets Manager などへアクセスする実行ロール                                            |
| Bedrock Guardrail    | `[prefix]-tracis-ai-guardrail`              | エージェントの入出力に対する Guardrail                                                                                     |

### チャット受信基盤

| 種別                            | リソース名（例）                                                                                                                                                                                                                                                                                                                                                      | 用途                                                                                                 |
| :------------------------------ | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------- |
| API Gateway                     | `[prefix]-tracis-ai-request-api`                                                                                                                                                                                                                                                                                                                                      | チャットツールの Webhook を受け付ける HTTP API                                                       |
| Lambda                          | <ul><li>`[prefix]-tracis-ai-slack-auth-function`</li><li>`[prefix]-tracis-ai-slack-enqueue-function`</li><li>`[prefix]-tracis-ai-chatwork-auth-function`</li><li>`[prefix]-tracis-ai-chatwork-enqueue-function`</li><li>`[prefix]-tracis-ai-agent-invoker-function`</li><li>`[prefix]-tracis-ai-response-dispatcher-function`</li></ul>                               | チャットツールからのリクエストを認証・キューイングし、AgentCore Runtime の呼び出しと応答の送信を行う |
| Lambda 実行ロール               | <ul><li>`[prefix]-tracis-ai-slack-auth-function-role`</li><li>`[prefix]-tracis-ai-slack-enqueue-function-role`</li><li>`[prefix]-tracis-ai-chatwork-auth-function-role`</li><li>`[prefix]-tracis-ai-chatwork-enqueue-function-role`</li><li>`[prefix]-tracis-ai-agent-invoker-function-role`</li><li>`[prefix]-tracis-ai-response-dispatcher-function-role`</li></ul> | 各 Lambda が Secrets Manager、SQS、AgentCore Runtime などへアクセスする実行ロール                    |
| SQS（FIFO）                     | <ul><li>`[prefix]-tracis-ai-request-queue.fifo`</li><li>`[prefix]-tracis-ai-response-queue.fifo`</li></ul>                                                                                                                                                                                                                                                            | request キューは AgentCore Runtime 呼び出し用、response キューはチャットツールへの応答送信用         |
| Lambda イベントソースマッピング | <ul><li>request キュー → Agent invoker Lambda</li><li>response キュー → Response dispatcher Lambda</li></ul>                                                                                                                                                                                                                                                          | 各 FIFO キューのメッセージを Lambda で処理する設定                                                   |

### ナレッジベース（Bedrock Knowledge Bases）

| 種別                       | リソース名（例）                                | 用途                                                                                 |
| :------------------------- | :---------------------------------------------- | :----------------------------------------------------------------------------------- |
| Knowledge Bases            | `[prefix]-tracis-ai-kb`                         | エージェントが参照するメタ情報（ロググループ／DB スキーマ等）の RAG 用ナレッジベース |
| データソース               | `s3-data-src`                                   | S3 バケットのドキュメントを Knowledge Bases に取り込むデータソース                   |
| データソース用 S3 バケット | `[prefix]-tracis-ai-kb-data-src-[アカウントID]` | ナレッジベースに同期するドキュメントのアップロード先                                 |
| Vector ストア              | `[prefix]-tracis-ai-kb-vectors-[アカウントID]`  | S3 Vectors 形式のベクター格納先                                                      |
| Vector インデックス        | `embeddings`                                    | ナレッジベースで使用するベクトルインデックス                                         |
| IAM ロール                 | `[prefix]-tracis-ai-kb-role`                    | Knowledge Bases が S3、S3 Vectors、KMS、Bedrock にアクセスする実行ロール             |

### Secrets Manager（Secret ARN を未指定でスタック作成した場合のみ）

| 種別                   | リソース名（例）                                                            | 用途                                                                                                                           |
| :--------------------- | :-------------------------------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------- |
| Secrets Manager Secret | `[prefix]-tracis-chat-tools-credentials-XXXXXXXX`<br>※ 末尾はランダム文字列 | チャットツール認証情報（`SLACK_SIGNING_SECRET` / `SLACK_BOT_TOKEN` / `CHATWORK_WEBHOOK_TOKEN` / `CHATWORK_API_TOKEN`）の格納先 |
| Secrets Manager Secret | `[prefix]-tracis-mysql-credentials-XXXXXXXX`<br>※ 末尾はランダム文字列      | MySQL 接続用の `username` / `password` の格納先<br>※ MySQL を利用する場合                                                      |

## CodeBuild 実行手順

> AgentCore Runtime と、Secret ARN を未指定の場合に作成される Secret は、初回の Terraform apply で作成・配備されます。CodeBuild 完了後に Secret とナレッジベースを準備してください。

1. AWS コンソールで「AWS CodeBuild」の画面を開く
2. 左サイドメニューの [ビルドプロジェクト] を選択
3. `ビルドプロジェクト` セクションの [[prefix]-tracis-deploy-agent] を選択
4. [ビルドを開始] をクリック
5. ビルドが正常に完了し、ステータスが `成功` になったことを確認


## Terraform 出力結果の確認

CodeBuild の `terraform apply` 完了時に出力される `Outputs` セクションから、後続手順で使用する値を控えておきます。

### 確認手順

1. AWS コンソールで「AWS CodeBuild」の画面を開く
2. 左サイドメニューの [ビルド履歴] を選択
3. 上記 CodeBuild 実行手順で完了した `[prefix]-tracis-deploy-agent` のビルド実行を選択
4. [ビルドログ] タブを開き、ログ末尾付近の `Outputs:` セクションを確認する
5. 下記の値を控える（または `Apply complete!` 直後の出力をテキストとして保存しておく）

### 控えておくべき主要な出力値

| Output 名                                | 値の例                                                                                                                                     | 利用先（次手順）                                                                                                                    |
| :--------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------- |
| `request_api_urls["slack"]`              | `https://xxxxxxxxxx.execute-api.ap-northeast-1.amazonaws.com/slack`                                                                        | [Slack App の作成](/docs/create_environment/03_1_create_slack_app/README.md) の Event Subscriptions の Request URL に設定           |
| `request_api_urls["chatwork"]`           | `https://xxxxxxxxxx.execute-api.ap-northeast-1.amazonaws.com/chatwork`                                                                     | [Chatwork Webhook の設定](/docs/create_environment/03_2_create_chatwork_webhook/README.md) の Webhook URL に設定                    |
| `chat_tools_secret_name`                 | `[prefix]-tracis-chat-tools-credentials-XXXXXXXX`<br>※ `ChatToolsSecretArn` を未指定で作成した場合のみ値が出力される                       | [Secret の準備](/docs/create_environment/04_prepare_secret/README.md) でチャットツール認証情報を格納する共有 Secret 名              |
| `mysql_secret_name`                      | `[prefix]-tracis-mysql-credentials-XXXXXXXX`<br>※ `MySqlSecretArn` を未指定かつ `EnabledDbTypes` に `mysql` を含める場合のみ値が出力される | [Secret の準備](/docs/create_environment/04_prepare_secret/README.md) で値を格納する DB Secret 名                                   |
| `knowledge_base_data_source_bucket_name` | `[prefix]-tracis-ai-kb-data-src-[アカウントID]`                                                                                            | [ナレッジベースの準備](/docs/create_environment/05_prepare_knowledgebases/README.md) でドキュメントをアップロードする S3 バケット名 |

> AgentCore Runtime の作成状況は AWS コンソールの「Amazon Bedrock AgentCore」の [Runtimes] で確認できます。Runtime 名は Prefix 内のハイフンをアンダースコアに置換した `[prefix]_tracis_ai_agent` です（最大 48 文字）。


## 次の手順

- [Slack App の作成](/docs/create_environment/03_1_create_slack_app/README.md)
- [Chatwork Webhook の設定](/docs/create_environment/03_2_create_chatwork_webhook/README.md)
