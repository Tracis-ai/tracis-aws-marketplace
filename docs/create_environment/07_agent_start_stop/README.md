# エージェント（ECS Service）の起動・停止


## 作業内容

1. エージェント（ECS Service）の起動または停止を行う


## 前提条件

- [Anthropic モデルアクセスの有効化](/docs/create_environment/06_enable_anthropic_model_access/README.md) までの手順が完了していること


## エージェント（ECS Service）の起動手順

1. AWS コンソールで「AWS CodeBuild」の画面を開く
2. 左サイドメニューの [ビルドプロジェクト] を選択
3. `ビルドプロジェクト` セクションの [[prefix]-tracis-start-agent] を選択
4. [ビルドを開始] をクリック
5. ビルドが正常に完了し、ステータスが `成功` になったことを確認

### 起動確認方法
1. AWS コンソールで「Amazon ECS」の画面を開く 
2. 左サイドメニューの [クラスター] を選択
3. [prefix]-tracis-agent-cluster を選択しクラスター詳細画面を開く
4. [prefix]-tracis-agent-service のサービス詳細画面を開き、[タスク] タブの `前回のステータス` が `正常` になっていることを確認


## エージェント（ECS Service）の停止手順

1. AWS コンソールで「AWS CodeBuild」の画面を開く
2. 左サイドメニューの [ビルドプロジェクト] を選択
3. `ビルドプロジェクト` セクションの [[prefix]-tracis-stop-agent] を選択
4. [ビルドを開始] をクリック
5. ビルドが正常に完了し、ステータスが `成功` になったことを確認

### 停止確認方法
1. AWS コンソールで「Amazon ECS」の画面を開く 
2. 左サイドメニューの [クラスター] を選択
3. [prefix]-tracis-agent-cluster を選択しクラスター詳細画面を開く
4. [prefix]-tracis-agent-service のサービス詳細画面を開き、[タスク] タブの `前回のステータス` が `停止済み` になっていることを確認
