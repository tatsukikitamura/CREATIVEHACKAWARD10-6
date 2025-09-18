# MBTI性格診断Webアプリケーション

OpenAIのAPIを利用して、AIが質問を生成し、ユーザーの回答に基づいてMBTIタイプを判定するWebアプリケーションです。

## 機能

- AIが生成する動的な質問（12問）
- インタラクティブな質問フォーム
- リアルタイムの進捗表示
- 詳細なMBTIタイプ判定結果
- 各次元のスコア表示
- 結果の共有機能

## セットアップ

### 1. 依存関係のインストール

```bash
cd Creative
bundle install
```

### 2. 環境変数の設定

OpenAIのAPIキーを設定する必要があります。以下のいずれかの方法で設定してください：

#### 方法1: 環境変数として設定
```bash
export OPENAI_API_KEY="your_openai_api_key_here"
```

#### 方法2: .envファイルを作成（推奨）
プロジェクトルートに`.env`ファイルを作成し、以下を記述：
```
OPENAI_API_KEY=your_openai_api_key_here
```

### 3. データベースのセットアップ

```bash
rails db:create
rails db:migrate
```

### 4. アプリケーションの起動

```bash
rails server
```

ブラウザで `http://localhost:3000` にアクセスしてください。

## 使用方法

1. アプリケーションにアクセスすると、自動的にAIが質問を生成します
2. 表示された質問に答えて「次の質問へ」ボタンをクリック
3. 全12問に回答すると、MBTIタイプの判定結果が表示されます
4. 結果画面では、各次元のスコアも確認できます

## 技術仕様

- **フレームワーク**: Ruby on Rails 7.1
- **AI API**: OpenAI GPT-3.5-turbo
- **フロントエンド**: HTML, CSS, JavaScript (Vanilla)
- **データベース**: SQLite3

## ファイル構成

```
app/
├── controllers/
│   └── mbti_controller.rb          # MBTI診断のコントローラー
├── models/
│   ├── mbti_question.rb            # 質問モデル
│   └── mbti_result.rb              # 結果モデル
├── services/
│   └── openai_service.rb           # OpenAI API連携サービス
└── views/
    └── mbti/
        ├── index.html.erb          # 開始ページ
        ├── show.html.erb           # 質問ページ
        └── result.html.erb         # 結果ページ
```

## カスタマイズ

### 質問数の変更
`app/services/openai_service.rb`の`generate_fallback_questions`メソッドで質問数を調整できます。

### スタイルの変更
`app/views/layouts/application.html.erb`の`<style>`セクションでCSSをカスタマイズできます。

### MBTIタイプの説明を変更
`app/models/mbti_question.rb`の`MBTI_TYPES`ハッシュで各タイプの説明を変更できます。

## トラブルシューティング

### OpenAI APIキーが設定されていない場合
APIキーが設定されていない場合、フォールバック用の固定質問が使用されます。

### エラーが発生した場合
ログファイル（`log/development.log`）を確認してください。

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。

