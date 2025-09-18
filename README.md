# MBTI性格診断テスト（CREATIVEHACKAWARD10-6）

本番サイト: https://mbti-search-854b363bf31b.herokuapp.com/

本アプリは、AIが動的に生成する質問に答えるだけで、あなたのMBTI性格タイプを診断・可視化するWebアプリです。4つの次元（外向性/内向性、感覚/直感、思考/感情、判断/知覚）をもとに12問の質問に回答し、16タイプから最適なタイプを推定します。

## 主な特徴
- AI生成質問: OpenAIを用いて、回答内容に応じた物語仕立ての質問を逐次生成
- 物語モード: 「ホラー」「アドベンチャー」「ミステリー」から選択して遊び感覚で診断
- 進捗管理: 回答履歴や現在の質問位置をサーバ側セッションモデルで保持
- 詳細分析: 各次元のスコアやタイプ名を分かりやすく提示
- リアルタイム: 回答に応じて即座に次の質問・結果へ反映

## 使い方
1. トップページで「診断を開始する」をクリック
2. セッションIDが発行され、物語モードを選択
3. 12問の質問に回答
4. 結果画面でMBTIタイプとスコアを確認

## 技術概要
- フレームワーク: Ruby on Rails 7
- 言語/ランタイム: Ruby 3.2.2
- フロントエンド: Turbo/Stimulus, Importmap
- データベース: 本番は PostgreSQL（Heroku Postgres）、開発/テストは SQLite3
- モデル: `MbtiSession` に質問・回答・進行状況・物語モードを保存
- 外部API: OpenAI（質問生成）

## 環境変数
- `OPENAI_API_KEY`: OpenAIのAPIキー（結果画面の「さらに分析する」で利用）
- `DATABASE_URL`: 本番(PostgreSQL)の接続URL（Herokuで自動付与）
- `RAILS_MASTER_KEY`: Railsの本番資格情報を使う場合に設定

### .env での設定例（開発）
```
OPENAI_API_KEY=sk-xxxxx
```

## ローカル開発
```bash
bundle install
bin/rails db:setup
bin/rails s
```
http://localhost:3000 にアクセス。

## デプロイ（Heroku）
```bash
git push heroku main
heroku run rails db:migrate
```
リリース時に自動でマイグレーションを走らせたい場合は `Procfile` に下記を追加:
```
release: bundle exec rails db:migrate
```

## ライセンス
このリポジトリの内容はプロジェクトの目的に従って利用してください。
