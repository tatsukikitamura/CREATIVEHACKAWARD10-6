# API Reference

## 診断フロー
| Method | Path | 説明 |
|--------|------|------|
| GET | `/mbti` | 診断開始（セッションID発行） |
| GET | `/mbti/mode_selection` | エンジン選択画面 |
| GET | `/mbti/select_mode` | 物語モード選択画面 |
| POST | `/mbti/set_mode` | モード設定・診断開始 |
| GET | `/mbti/make_mode` | カスタム物語作成画面 |
| POST | `/mbti/create_story` | カスタム物語保存 |
| GET | `/mbti/show` | 質問表示 |
| POST | `/mbti/answer` | 回答送信 |
| POST | `/mbti/back` | 前の質問に戻る |
| GET | `/mbti/result` | 基本結果表示 |
| GET | `/mbti/result_ai` | AI診断結果表示 |
| GET | `/mbti/resume` | 診断再開 |

## ゲームマスター方式
| Method | Path | 説明 |
|--------|------|------|
| GET | `/mbti/game_master` | ゲームマスター画面 |
| POST | `/mbti/game_master/answer` | 選択送信 |
| GET | `/mbti/game_master/ending` | エンディング表示 |

## AI生成API
| Method | Path | 説明 |
|--------|------|------|
| POST | `/mbti/analyze` | 詳細分析生成 |
| POST | `/mbti/personalized_report` | パーソナライズドレポート生成 |
| POST | `/mbti/generate_music` | 音楽提案生成 |
| POST | `/mbti/generate_image` | 画像生成 |
