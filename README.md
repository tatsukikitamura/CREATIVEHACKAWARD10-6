# MBTI性格診断テスト（CREATIVEHACKAWARD10-6）

本番サイト: https://mbti-search-854b363bf31b.herokuapp.com/

AIが動的に生成する質問に答えるだけで、MBTI性格タイプを診断・可視化するWebアプリです。4つの次元（外向性/内向性、感覚/直感、思考/感情、判断/知覚）をもとに回答し、16タイプから最適なタイプを推定します。

## 機能（Features）
- AI生成質問: OpenAIで回答内容に応じた物語仕立ての質問を逐次生成
- 物語モード: 「ホラー」「アドベンチャー」「ミステリー」から選択
- 進捗管理: サーバ側セッションモデルで質問位置・回答履歴を保持
- 結果表示: 各次元のスコアとタイプ名をわかりやすく提示
- リアルタイム: 回答に応じて直ちに次の質問・結果へ反映

## 差別化ポイント（USP）
- 物語モードにより回答のしやすさが向上
- 回答数無制限でより詳細な分析が可能
- MBTIにとどまらず「自己認識・アイデンティティ形成プロセス」を探究
- AIを「個性の均質化」ではなく「個性の多様化」を促すツールとして再定義

## クイックスタート（Quick Start）
```bash
bundle install
bin/rails db:setup
bin/rails s
```
ブラウザで http://localhost:3000 を開きます。

### 環境変数（.env例）
```
OPENAI_API_KEY=sk-xxxxx
```

必要に応じて以下も設定:
- `DATABASE_URL`（本番: PostgreSQL）
- `RAILS_MASTER_KEY`（本番資格情報使用時）

## 技術スタック（Tech Stack）
- Rails 7 / Ruby 3.2.2
- Frontend: Turbo / Stimulus / Importmap
- DB: 本番 PostgreSQL（Heroku Postgres）/ 開発 SQLite3
- モデル: `MbtiSession`（質問・回答・進行状況・物語モードを保存）
- 外部API: OpenAI（質問生成・分析）

## 開発メモ（UI/ナビゲーションの注意点）
- 質問UIの安定化: EIほか全テーマでサイズ・位置の変形を禁止
  - 対応ファイル: `app/assets/stylesheets/mbti_show.scss`, `mbti_themes.scss`
  - hover/selectedのtransformを無効化し、色・影のみトランジション
- 「前の質問」ボタン: フォーム外に独立配置し、POSTで`/mbti/back`へ送信
  - ルート: `post '/mbti/back' => mbti#back`
  - コントローラ: `back`で`current_question_index`を1つ戻し、303で`/mbti/show`へ
- CSRF: 回答系（`answer`, `back`）で検証スキップ（必要に応じて厳密化可）

## デプロイ（Heroku）
```bash
git push heroku main
heroku run rails db:migrate
```
リリース時に自動マイグレーションを行う場合は `Procfile` に以下を追加:
```
release: bundle exec rails db:migrate
```

## ライセンス
このリポジトリの内容はプロジェクトの目的に従って利用してください。
