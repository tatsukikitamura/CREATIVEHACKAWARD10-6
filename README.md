# MBTI性格診断テスト（CREATIVEHACKAWARD10-6）

本番サイト: https://mbti-search-854b363bf31b.herokuapp.com/

AIが動的に生成する質問に答えるだけで、MBTI性格タイプを診断・可視化するWebアプリです。4つの次元（外向性/内向性、感覚/直感、思考/感情、判断/知覚）をもとに回答し、16タイプから最適なタイプを推定します。

## 目次
- アプリケーションの概要
  - 目的（Purpose）
  - 対象ユーザー（Who）
  - 提供価値（Value Proposition）
  - 代表的ユースケース（Use Cases）
  - 体験フロー（User Journey）
  - 差別化ポイント（USP）
  - 設計思想（Design Principles）
  - 今後の展望（Roadmap）
- 開発者向け付録
  - 要件（Ruby / Rails / DB / 外部サービス）
  - クイックスタート
  - ローカル開発（bin/setup）
  - Dockerでの起動
  - 環境変数
  - 技術スタック
  - 主要機能
  - APIエンドポイント
  - 開発メモ（UI/ナビゲーション）
  - デプロイ（Heroku）
  - 補助ドキュメント
  - トラブルシューティング / FAQ
  - ライセンス

## アプリケーションの概要
### 目的（Purpose）
自己理解を深める対話的な体験を提供し、MBTIの枠を越えて「物語」「音楽」「画像」を通じて多面的にパーソナリティを可視化します。

### 対象ユーザー（Who）
- 自己分析・キャリア探索・創作インスピレーションを求める個人
- ワークショップやカウンセリングでのアイスブレイクを行うファシリテーター
- 企画・コンテンツ制作におけるアイデア発火装置を求めるクリエイター

### 提供価値（Value Proposition）
- AIが物語文脈に沿って質問を生成し、直感的に回答しやすい
- 結果を静的なラベルではなく、音楽・画像・物語の多層表現として提示
- 回答の蓄積から文脈に沿った解釈・示唆を返すため、自己理解が深まる

### 代表的ユースケース（Use Cases）
- 個人のセルフリフレクション（定期的な内省のトリガー）
- チームビルディングでの相互理解のきっかけ作り
- 作品制作前のキャラクター・世界観設計のインスピレーション獲得

### 体験フロー（User Journey）
1. 物語モードを選ぶ（ホラー/アドベンチャー/ミステリー/クリエイター/カスタム）
2. 物語調の質問に回答（AIが履歴と設定に応じて次の質問を生成）
3. 結果画面でタイプ傾向と根拠のストーリーを確認
4. 音楽提案・画像生成・レポートで多面的に理解を補強

### 差別化ポイント（USP）
- 物語モードで回答のハードルを下げ、自然な自己開示を促進
- 個別化AI分析により、単純なタイプ分類を超えた意味づけ
- 音楽・画像・物語の多面的な表現で解釈の幅を拡張

### 設計思想（Design Principles）
- ラベル付けではなく、文脈と関係性を重視した解釈
- 説明可能性（根拠の提示）と詩的表現（インスピレーション）の両立
- ユーザー主導（カスタム物語）とAI支援のハイブリッド

### 今後の展望（Roadmap）
- セッションの長期学習（再訪時の継続的パーソナライズ）
- コミュニティ共有用の匿名プロファイル/プレイリスト
- マルチモーダル入力（画像・音声）対応

## 開発者向け付録

## 要件（Requirements）
- Ruby: 3.3.0（`.ruby-version`）
- Rails: 8.0系（`Gemfile`）
- DB: PostgreSQL
- 外部サービス: OpenAI（テキスト生成）、DALL·E 3（画像）


## クイックスタート
```bash
bundle install
bin/rails db:setup
bin/rails s
```
ブラウザで http://localhost:3000 を開きます。

## ローカル開発（bin/setup）
初回セットアップや依存関係更新は以下で自動化されています。

```bash
bin/setup
```

実行内容の要点:
- Bundlerのインストールと `bundle install`
- `bin/rails db:prepare` によるDB準備
- ログ/一時ファイルのクリアとアプリの再起動

## Dockerでの起動
アプリのDockerイメージは `Dockerfile` で定義されています。DBをDockerで使う場合は `docker-compose.yml` の `postgres` サービスを起動してください。

1) PostgreSQL の起動
```bash
docker compose up -d postgres
```

2) アプリの起動（例: ビルドして起動）
```bash
docker build -t mbti-app .
docker run --rm -p 3000:3000 \
  -e RAILS_ENV=development \
  -e DATABASE_URL=postgres://postgres:password@host.docker.internal:5432/creativehackaward10_6_development \
  --name mbti-app mbti-app
```

メモ: ネットワークやホスト名は環境に合わせて調整してください（WSL2の場合は `host.docker.internal` が使える前提）。

## 環境変数
`.env`（`dotenv-rails`）で管理します。

```bash
OPENAI_API_KEY=sk-xxxxx
```

必要に応じて以下も設定:
- `DATABASE_URL`（本番: PostgreSQL）
- `RAILS_MASTER_KEY`（本番資格情報使用時）

## 技術スタック（Tech Stack）
- Backend: Rails 8 / Ruby 3.3.0
- Frontend: Turbo / Stimulus / Importmap
- Database: 本番 PostgreSQL（Heroku Postgres）/ 開発 SQLite3
- AI/ML: OpenAI GPT-4, DALL·E 3
- 主要モデル:
  - `MbtiSession`（質問・回答・進行状況・物語モードを保存）
  - `MbtiResult`（MBTIタイプ計算・分析）
- 外部API:
  - OpenAI（質問生成・分析・音楽提案・画像生成）
  - DALL·E 3（高品質な画像生成）
- 主要サービス:
  - `OpenaiService`（質問生成・分析）
  - `AiMusicService`（音楽提案・プレイリスト生成）
  - `AiPhotoService`（画像生成・プロンプト管理）

## 主要機能
### 基本診断機能
- AI生成質問（物語仕立て）
- 物語モード（ホラー/アドベンチャー/ミステリー/クリエイター）
- 進捗管理（サーバセッション）
- 結果表示（各次元スコアとタイプ）
- リアルタイム更新

### AI診断機能
- 個別化分析（回答と物語設定に基づく）
- 音楽提案（ジャンル/アーティスト/楽曲）
- 画像生成（抽象・自然/風景・日常シーン）
- プレイリスト作成

### 物語設定機能
- カスタム物語（舞台/テーマ/雰囲気/キャラ背景）
- 文脈に応じた生成
- 多様な表現

## APIエンドポイント
### 診断関連
- `GET /mbti` - 診断開始
- `POST /mbti/answer` - 質問回答
- `GET /mbti/result` - 基本結果表示
- `GET /mbti/result_ai` - AI診断結果表示

### AI生成関連
- `POST /mbti/generate_music` - 音楽提案生成
- `POST /mbti/generate_image` - 画像生成
- `POST /mbti/personalized_report` - 個別化レポート生成


## デプロイ（Heroku）
```bash
git push heroku main
heroku run rails db:migrate
```
リリース時に自動マイグレーションを行う場合は `Procfile` に以下を追加:
```
release: bundle exec rails db:migrate
```

## 補助ドキュメント
- `MBTI_README.md`: 差別化ポイントの要約
- `docs/production.txt`: 本番運用に関するメモ
- `docs/2024.txt`: 開発履歴・補足

## トラブルシューティング / FAQ
- サーバ起動時にRuby/Railsの不整合が出る
  - `ruby -v` が `3.3.0` であることを確認し、`bundle install` を再実行
  - Docker利用時は `Dockerfile` の `ARG RUBY_VERSION` を `3.3.0` に揃える
- DB接続エラー（Postgres）
  - `docker compose ps` で `postgres` が `healthy` か確認
  - 接続情報（ユーザ/パスワード/ポート）を `docker-compose.yml` と一致させる
- OpenAIのエラー
  - `OPENAI_API_KEY` が正しいか、API利用制限を超えていないか確認

## ライセンス
このリポジトリの内容はプロジェクトの目的に従って利用してください。
