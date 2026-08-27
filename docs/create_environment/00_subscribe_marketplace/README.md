# AWS Marketplace でのサブスクライブ

## 作業内容

1. AWS Marketplace で TracisAI の利用規約と料金を確認する
2. 対象 AWS アカウントでサブスクライブを完了する

## 前提条件

- AWS Marketplace の購入またはサブスクライブ権限があること
- AWS Organizations の Private Marketplace を利用している場合、TracisAI が管理者により承認済みであること

## 手順

1. 利用する AWS アカウントで AWS コンソールにサインインする
2. [TracisAI の AWS Marketplace 製品ページ](https://us-east-1.console.aws.amazon.com/marketplace/search/listing/prodview-rxr4dzl4tfh5o?applicationId=AWS-Marketplace-Console) を開く
3. ページの [料金] と [法的] で、製品料金とベンダー利用規約を確認する。あわせて、[利用規約 追加条項](/docs/TERMS.md) を確認する
4. [購入オプションを表示] を選択する
5. 「TracisAI をサブスクライブ」ページで、表示される製品料金と利用規約を確認する
6. 内容に同意できる場合は、[サブスクライブ] を選択する
7. 処理が完了したら、AWS Marketplace の [サブスクリプションを管理] にある [アクティブなサブスクリプション] で、TracisAI が表示されていることを確認する

> サブスクライブ時の料金は AWS Marketplace の製品ページに表示される内容が適用されます。契約条件については、ベンダー利用規約および [利用規約 追加条項](/docs/TERMS.md) をご確認ください。AWS Marketplace Standard Contract と利用規約 追加条項の内容に矛盾がある場合は、利用規約 追加条項が優先します。本製品の利用に必要な AWS サービスの料金は、製品料金とは別に利用状況に応じて発生します。詳細は [参考コスト](/docs/COSTS.md) を参照してください。

## 次の手順

[エージェント構築基盤の準備](/docs/create_environment/01_setup_agent_builder/README.md)
