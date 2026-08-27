# 利用終了時の環境削除手順


## 作業内容

1. エージェント関連リソースを削除する
2. エージェント構築基盤の CloudFormation スタックを削除する


## 前提条件

- 本製品を今後利用する予定がないこと
- 本製品に関連するリソースを削除しても支障がないこと


## エージェント関連リソースの削除

1. AWS コンソールで「AWS CodeBuild」の画面を開く
2. 左サイドメニューの [ビルドプロジェクト] を選択
3. `ビルドプロジェクト` セクションの [[prefix]-tracis-delete-agent] を選択
4. [ビルドを開始] をクリック
5. ビルドが正常に完了し、ステータスが `成功` になったことを確認

### 削除確認方法
1. AWS コンソールで「Amazon Bedrock AgentCore」の画面を開く
2. [Runtimes] を選択
3. Prefix 内のハイフンをアンダースコアに置換した Runtime 名（最大 48 文字）が存在しないことを確認
4. AWS コンソールで「EC2」の画面を開き、[セキュリティグループ] を選択
5. `[prefix]-tracis-ai-agentcore-runtime-sg` が残っている場合は、選択して [アクション] から [セキュリティグループを削除] を選択し、削除する

> AgentCore Runtime の削除後も、サービス管理のネットワークインターフェイス（ENI）が最大 8 時間残る場合があります。Security Group を削除できない場合は、ENI が解放された後に再度削除してください。詳細は [Amazon Bedrock AgentCore Runtime の VPC 接続に関する AWS ドキュメント](https://docs.aws.amazon.com/ja_jp/bedrock-agentcore/latest/devguide/agentcore-vpc.html#vpc-connectivity-agentcore) を参照してください。


## CloudFormation スタックの削除

1. AWS コンソールで「AWS CloudFormation」の画面を開く
2. `スタック` セクションで環境構築時に作成したスタックを選択
3. [スタックを削除] をクリック
4. 確認画面にて、`スタック名` を入力し、[スタックを削除] をクリック
5. ステータスが `DELETE_COMPLETE` になったことを確認
