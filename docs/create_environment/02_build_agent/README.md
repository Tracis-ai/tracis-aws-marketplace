# エージェント関連リソースの初期構築


## 作業内容

1. CodeBuild を実行し、Terraform でエージェント関連リソースを構築する
2. Terraform の出力結果を確認し、後続の手順で必要となる値（Slack 用リクエスト URL、Secret 名など）を控える


## 前提条件

- [エージェント構築基盤の準備](/docs/create_environment/01_setup_agent_builder/README.md) の手順が完了していること


## Terraform により作成されるリソース

エージェント関連リソースの初期構築では、主に以下のリソースが作成されます（プレフィックスは CloudFormation スタックで指定した `Prefix` 値が使用されます）。

### エージェント実行基盤（ECS / ネットワーク）

| 種別                    | リソース名（例）                                                                                                                                                 | 用途                                                                                                                 |
| :---------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------- |
| ECS クラスター          | `[prefix]-log-analyze-agent-cluster`                                                                                                                             | エージェント実行用の Fargate クラスター                                                                              |
| ECS Service             | `[prefix]-log-analyze-orchestrator-agent-service`<br>`[prefix]-log-analyze-cloudwatch-search-agent-service`<br>`[prefix]-log-analyze-mysql-search-agent-service` | オーケストレーター／CloudWatch 検索／MySQL 検索 の各エージェント。初期構築時は `desired_count = 0`（停止状態）で作成 |
| セキュリティグループ    | `[prefix]-log-analyze-orchestrator-sg`<br>`[prefix]-log-analyze-cloudwatch-search-sg`<br>`[prefix]-log-analyze-mysql-search-sg`                                  | 各 ECS Service 用のセキュリティグループ                                                                              |
| IAM ロール              | `[prefix]-log-analyze-<svc>-task-exec-role`<br>`[prefix]-log-analyze-<svc>-tasks-role`                                                                           | 各 ECS Service のタスク実行ロール／タスクロール                                                                      |
| Service Discovery (PHZ) | `[prefix]-log-analyze.local`                                                                                                                                     | エージェント間通信用のプライベート DNS 名前空間                                                                      |

### Slack 受信基盤

| 種別        | リソース名（例）                                                                      | 用途                                                                      |
| :---------- | :------------------------------------------------------------------------------------ | :------------------------------------------------------------------------ |
| API Gateway | `[prefix]-slack-receive-api`                                                          | Slack からの webhook を受け付ける HTTP API                                |
| Lambda      | `[prefix]-log-analyze-slack-auth-function`<br>`[prefix]-log-analyze-enqueue-function` | Slack リクエストの署名検証 (`slack-auth`) と SQS への enqueue (`enqueue`) |
| SQS（FIFO） | `[prefix]-log-analyze-request-queue`                                                  | Slack イベントを enqueue し、オーケストレーターがポーリングするキュー     |

### ナレッジベース（Bedrock Knowledge Base）

| 種別                       | リソース名（例）                                      | 用途                                                                                 |
| :------------------------- | :---------------------------------------------------- | :----------------------------------------------------------------------------------- |
| Knowledge Base             | `[prefix]-log-analyze-kb`                             | エージェントが参照するメタ情報（ロググループ／DB スキーマ等）の RAG 用ナレッジベース |
| データソース用 S3 バケット | `[prefix]-log-analyze-kb-data-sources-[アカウントID]` | ナレッジベースに同期するドキュメントのアップロード先                                 |
| Vector ストア              | `[prefix]-log-analyze-kb-vectors-[アカウントID]`      | S3 Vectors 形式のベクター格納先                                                      |

### Secrets Manager（Secret ARN を未指定でスタック作成した場合のみ）

| 種別                   | リソース名（例）                                                       | 用途                                                   |
| :--------------------- | :--------------------------------------------------------------------- | :----------------------------------------------------- |
| Secrets Manager Secret | `[prefix]-tracis-slack-credentials-XXXXXXXX`<br>※ 末尾はランダム文字列 | Slack の `SIGNING_SECRET` / `SLACK_BOT_TOKEN` の格納先 |
| Secrets Manager Secret | `[prefix]-tracis-mysql-credentials-XXXXXXXX`<br>※ 末尾はランダム文字列 | DB 接続用の `username` / `password` の格納先           |

### その他

| 種別                 | リソース名（例）                                                     | 用途                                               |
| :------------------- | :------------------------------------------------------------------- | :------------------------------------------------- |
| Bedrock Guardrail    | `[prefix]-log-analyze-guardrail`                                     | エージェントの入出力に対する Guardrail             |
| KMS Key              | `[prefix]-log-analyze-*` 各種                                        | SQS / CloudWatch Logs / Secrets などの暗号化用キー |
| CloudWatch Log Group | `/aws/ecs/[prefix]-log-analyze-<svc>-agent-service/<container>` ほか | 各 ECS タスクおよび Knowledge Base のログ出力先    |


## CodeBuild 実行手順

> 初期構築時は `desired_count = 0`（ECS Service 停止状態）でリソースを作成するため、 `[prefix]-tracis-stop-agent` プロジェクトを使用します。Secret やナレッジベース投入後に `[prefix]-tracis-start-agent` で起動します。

1. AWS コンソールで「AWS CodeBuild」の画面を開く
2. 左サイドメニューの [ビルドプロジェクト] を選択
3. `ビルドプロジェクト` セクションの [[prefix]-tracis-stop-agent] を選択
4. [ビルドを開始] をクリック
5. ビルドが正常に完了し、ステータスが `成功` になったことを確認


## Terraform 出力結果の確認

CodeBuild の `terraform apply` 完了時に出力される `Outputs` セクションから、後続手順で使用する値を控えておきます。

### 確認手順

1. AWS コンソールで「AWS CodeBuild」の画面を開く
2. 左サイドメニューの [ビルド履歴] を選択
3. 上記 CodeBuild 実行手順で完了した `[prefix]-tracis-stop-agent` のビルド実行を選択
4. [ビルドログ] タブを開き、ログ末尾付近の `Outputs:` セクションを確認する
5. 下記の値を控える（または `Apply complete!` 直後の出力をテキストとして保存しておく）

### 控えておくべき主要な出力値

| Output 名                                | 値の例                                                                                                      | 利用先（次手順）                                                                                                                    |
| :--------------------------------------- | :---------------------------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------- |
| `slack_receive_api_url`                  | `https://xxxxxxxxxx.execute-api.ap-northeast-1.amazonaws.com/slack`                                         | [Slack App の作成](/docs/create_environment/03_create_slack_app/README.md) の Event Subscriptions の Request URL に設定             |
| `slack_secret_name`                      | `[prefix]-tracis-slack-credentials-XXXXXXXX`<br>※ `SlackSecretArn` を未指定で作成した場合のみ値が出力される | [Secret の準備](/docs/create_environment/04_prepare_secret/README.md) で値を格納する Slack Secret 名                                |
| `mysql_secret_name`                      | `[prefix]-tracis-mysql-credentials-XXXXXXXX`<br>※ `MySqlSecretArn` を未指定で作成した場合のみ値が出力される | [Secret の準備](/docs/create_environment/04_prepare_secret/README.md) で値を格納する DB Secret 名                                   |
| `knowledge_base_data_source_bucket_name` | `[prefix]-log-analyze-kb-data-sources-[アカウントID]`                                                       | [ナレッジベースの準備](/docs/create_environment/05_prepare_knowledgebases/README.md) でドキュメントをアップロードする S3 バケット名 |

> ECS クラスター名・ECS Service 名（`[prefix]-log-analyze-agent-cluster` / `[prefix]-log-analyze-<svc>-agent-service`）は Terraform 出力には含まれませんが、上記 Prefix から命名規則どおりに導出できます。実際の起動状態は AWS コンソールの「Amazon ECS」画面からも確認できます（[起動・停止手順](/docs/create_environment/06_agent_start_stop/README.md)）。


## 次の手順
[Slack App の作成](/docs/create_environment/03_create_slack_app/README.md)
