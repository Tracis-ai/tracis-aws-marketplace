# エージェント構築基盤の準備


## 作業内容

1. CloudFormation でエージェント構築基盤（Terraform 実行基盤）を作成する


## 前提条件

- CloudFormationおよび関連リソース（S3, CodeBuild, IAM）の作成権限があること


## CloudFormation により作成されるリソース

- tfstate 保管用 S3 バケット
- CodeBuild project
  - エージェント（ECS service）スタート用（desired_count = 1）
  - エージェント（ECS service）ストップ用（desired_count = 0）
  - エージェント削除用
- CodeBuild サービスロール
- CodeBuild ロググループ


## CloudFormation スタックの作成手順

1. AWS コンソールで「AWS CloudFormation」の画面を開く
2. [スタックの作成] をクリックし [新しいリソースを使用 (標準)] を選択
3. `テンプレートの指定` セクションで [テンプレートファイルのアップロード] を選択
4. [ファイルの選択] をクリックし builder/CloudFormation.yml を選択して [次へ] をクリック
5. `スタックの名前` に任意のスタック名を入力
6. `パラメータ` セクションにて デフォルト値が空の項目に必要な値を入力し [次へ] をクリック

| パラメータ名                     | 説明                                              | 入力例・補足                                                                                                                                                                |
| :------------------------------- | :------------------------------------------------ | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **AgentSubnetIds**               | Tracis Agentの展開用サブネットID                  | `subnet-0123xx,subnet-0456yy`<br>※複数指定する場合は、カンマ区切りで入力してください。                                                                                      |
| **BedrockModelId**               | BedrockモデルID                                   | `global.anthropic.claude-sonnet-4-6`                                                                                                                                        |
| **BedrockModelMaxTokens**        | Bedrockモデルの最大トークン数                     | `2048`<br>※この上限を超えるトークンを処理しようとした場合、エージェント処理が失敗する可能性があります。値を大きくすることで回避できますが、トークン使用コストが増加します。 |
| **ImageUrlForCloudWatchMcp**     | CloudWatch MCP Server用のECRイメージURL           | `123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/my-repo:tag`                                                                                                             |
| **ImageUrlForLogRouter**         | Firelens ログルーター用のECRイメージURL           | `123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/my-repo:tag`                                                                                                             |
| **ImageUrlForMySqlMcp**          | MySQL MCP Server用のECRイメージURL                | `123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/my-repo:tag`                                                                                                             |
| **ImageUrlForOrchestratorAgent** | Orchestrator Agent用のECRイメージURL              | `123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/my-repo:tag`                                                                                                             |
| **ImageUrlForToolAgent**         | Tool Agent用のECRイメージURL                      | `123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/my-repo:tag`                                                                                                             |
| **MySqlDbName**                  | MySQLデータベースの名前                           | `project_db`                                                                                                                                                                |
| **MySqlEndpoint**                | MySQL データベースのエンドポイント                | `mydb.cluster-ro-123456789012.ap-northeast-1.rds.amazonaws.com`                                                                                                             |
| **MySqlPort**                    | MySQLデータベースのポート番号                     | `3306`                                                                                                                                                                      |
| **MySqlSecretArn**               | AWS Secrets Manager 内の MySQL シークレットの ARN | `arn:aws:secretsmanager:...`<br>※指定がない場合は、新しい空のシークレットが作成されます。                                                                                   |
| **MySqlSecurityGroupIds**        | MySQLデータベースのセキュリティグループID         | `sg-0abc123...`<br>※複数指定する場合は、カンマ区切りで入力してください。                                                                                                    |
| **Prefix**                       | すべてのリソースに対するプレフィックス            | `my-app-dev`                                                                                                                                                                |
| **SlackSecretArn**               | AWS Secrets Manager 内の Slack シークレットの ARN | `arn:aws:secretsmanager:...`<br>※指定がない場合は、新しい空のシークレットが作成されます。                                                                                   |
| **UseFargateSpot**               | Fargate Spot 実行環境を利用するかどうか           | `true` または `false`<br>※有効 (true) にする場合、割引料金で ECS タスクを実行できる一方で、タスク中断の可能性があります。                                                   |

1. `スタックオプションの設定` 画面で [次へ] をクリック
2. 内容を確認し [送信] をクリック
3. ステータスが `CREATE_COMPLETE` になり、リソースが作成されたことを確認する


## 次の手順

[エージェント関連リソースの初期構築](/docs/create_environment/02_build_agent/README.md)
