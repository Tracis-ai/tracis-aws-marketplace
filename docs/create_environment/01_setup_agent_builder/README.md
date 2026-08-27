# エージェント構築基盤の準備


## 作業内容

1. CloudFormation でエージェント構築基盤（Terraform 実行基盤）を作成する


## 前提条件

- CloudFormation および関連リソース（S3, CodeBuild, IAM）の作成権限があること


## CloudFormation により作成されるリソース

- tfstate 保管用 S3 バケット
- CodeBuild project
  - エージェント（AgentCore Runtime）配備用
  - エージェント削除用
- CodeBuild サービスロール
- CodeBuild ロググループ


## CloudFormation スタックの作成手順

1. AWS コンソールで「AWS CloudFormation」の画面を開く
2. [スタックの作成] をクリックし [新しいリソースを使用 (標準)] を選択
3. `テンプレートの指定` セクションで [テンプレートファイルのアップロード] を選択
4. [ファイルの選択] をクリックし builder/CloudFormation.yml を選択して [次へ] をクリック
5. `スタックの名前` に任意のスタック名を入力
6. `パラメータ` セクションにて 必要な値を入力し [次へ] をクリック

    | パラメータ名                     | 説明                                                                                  | 入力例・補足                                                                                                                                                                                                                                     |
    | :------------------------------- | :------------------------------------------------------------------------------------ | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
    | **AgentImageUrl**                | TracisAI Agent 用の ECR イメージ URL                                                  | 通常は空のまま使用してください。空の場合は、このリリースで定義された標準イメージが使用されます。独自イメージを使用する場合のみ ECR イメージ URL を指定してください。                                                                             |
    | **AgentSubnetIds**               | TracisAI AgentCore Runtime の配置用サブネット ID                                      | `subnet-0123xx,subnet-0456yy`<br>※ 複数指定する場合は、カンマ区切りで入力してください。                                                                                                                                                          |
    | **BedrockModelId**               | BedrockモデルID                                                                       | `global.anthropic.claude-sonnet-4-6`                                                                                                                                                                                                             |
    | **BedrockModelMaxTokens**        | Bedrockモデルの最大トークン数                                                         | `8192`<br>※ エージェントがこの上限を超えるトークンを処理しようとした場合、処理が失敗する可能性があります。この値を大きくすることで失敗を回避できる可能性が高まりますが、トークン使用コストが増加します。                                         |
    | **EnabledDbTypes**               | 接続するデータベースの種別                                                            | `mysql`<br>MySQL のみ指定できます。               |
    | **MySqlDbName**                  | MySQL データベースの名前                                                              | `project_db`<br>※ MySQL を利用する場合に入力が必要です。                                                                                                                                                                                         |
    | **MySqlEndpoint**                | MySQL データベースのエンドポイント                                                    | `mydb.cluster-ro-123456789012.ap-northeast-1.rds.amazonaws.com`<br>※ MySQL を利用する場合に入力が必要です。                                                                                                                                      |
    | **MySqlPort**                    | MySQLデータベースのポート番号                                                         | `3306` <br>※ MySQL を利用する場合に入力が必要です。                                                                                                                                                                                              |
    | **MySqlSecretArn**               | AWS Secrets Manager 内の MySQL シークレットの ARN                                     | `arn:aws:secretsmanager:...`<br>※ MySQL を利用する場合で、既存シークレットを使用する場合に入力してください。<br>※ 指定がない場合は、新しいシークレットが作成されます。（値の格納が別途必要です）                                                 |
    | **MySqlSecurityGroupIds**        | MySQL データベースのセキュリティグループ ID                                           | `sg-0abc123...`<br>※ MySQL を利用する場合に入力が必要です。<br>複数指定する場合はカンマ区切りで入力してください。<br>指定したセキュリティグループのインバウンドルールに、エージェントのセキュリティグループからのアクセス許可を追加します。      |
    | **Prefix**                       | すべてのリソースに対するプレフィックス                                                | `my-app`<br>※ S3 バケット名にも使用します。英小文字、数字、ハイフンのみを使用し、先頭・末尾をハイフンにしない 36 文字以内の値を入力してください。この条件に合わない値では、CloudFormation でスタックを作成できません。                           |
    | **ChatToolsSecretArn**           | AWS Secrets Manager 内のチャットツール（Slack／Chatwork）認証情報用共有 Secret の ARN | `arn:aws:secretsmanager:...`<br>※ 各チャットツールの認証情報を同じ Secret に格納する場合に入力してください。<br>※ 指定がない場合は、新しい共有 Secret が作成されます。（値の格納が別途必要です）                                                 |
    | **SourceVersion**                | Terraform 実行時に取得する公開リポジトリのソースバージョン                            | 通常は空のまま使用してください。空の場合は、このリリースで定義されたソースバージョンが使用されます。特定の Git ref を使用する場合のみ指定してください。                                                                                          |

7. `スタックオプションの設定` 画面で [次へ] をクリック
8. 内容を確認し [送信] をクリック
9. ステータスが `CREATE_COMPLETE` になり、リソースが作成されたことを確認する


## 次の手順

[エージェント関連リソースの初期構築](/docs/create_environment/02_build_agent/README.md)
