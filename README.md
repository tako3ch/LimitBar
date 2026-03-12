# LimitBar

Minimal macOS menu bar monitor for Codex and Claude Code usage.

![screenshot](https://github.com/user-attachments/assets/f49103e8-10e4-4e22-911f-9cda8c5f16b8)

## Download

Download the latest version

https://github.com/tako3ch/LimitBar/releases/latest

## Features

- Monitor Codex / Claude Code usage
- Bar indicator
- Usage limit notifications

- Codex / Claude Code の利用率表示
- メニューバー常駐 UI
- フローティングウィジェット表示（サイズ / 位置 / 不透明度 / 表示順 / 常に手前の設定あり）
- 使用量レポート表示（履歴グラフ）
- 自動更新 / 手動更新
- しきい値通知 / リセット通知
- 日本語 / 英語表示切り替え（システム言語に追従）
- 表示モード切り替え（minimal / normal）



## Installation

1 Download DMG
2 Move LimitBar.app to Applications
3 Launch

## About Session Connection

### Codex (OpenAI)

Connection is attempted in the following priority order:

1. **Codex CLI authentication file** — Token saved in `~/.codex/auth.json`
2. **Supported browser session** — Login status to chatgpt.com / openai.com

### Claude Code (Anthropic)

Connection is attempted in the following priority order:

1. **In-app login** — Log in and save the session via the "Connect" button on the settings screen
2. **Supported browser session** — Login status to claude.ai / anthropic.com
3. **Claude desktop app session**

### Supported Browsers

Chrome / Brave / Edge / Arc / Chromium

## Notes

- Due to its reliance on local sessions, it may not be able to retrieve usage status depending on login status or changes in service specifications.
- Notification features and login startup are only effective when installed as an `.app` bundle.

---

# LimitBar

LimitBar は、Codex と Claude Code の利用率を macOS のメニューバーとフローティングウィジェットで確認できる常駐アプリです。

ローカル環境に存在するログインセッションを利用して使用率を取得し、現在の利用率を一覧表示します。設定したしきい値に近づいたときや利用率がリセットされたときには通知できます。

## 主な機能

- Codex / Claude Code の利用率表示
- メニューバー常駐 UI
- フローティングウィジェット表示（サイズ / 位置 / 不透明度 / 表示順 / 常に手前の設定あり）
- 使用量レポート表示（履歴グラフ）
- 自動更新 / 手動更新
- しきい値通知 / リセット通知
- 日本語 / 英語表示切り替え（システム言語に追従）
- 表示モード切り替え（minimal / normal）

## 必要環境

- macOS 14 以降

## セッション接続について

### Codex（OpenAI）

次の優先順で接続を試みます：

1. **Codex CLI の認証ファイル** — `~/.codex/auth.json` に保存されたトークン
2. **対応ブラウザのセッション** — chatgpt.com / openai.com へのログイン状態

### Claude Code（Anthropic）

次の優先順で接続を試みます：

1. **アプリ内ログイン** — 設定画面の「接続」ボタンからログインしてセッションを保存
2. **対応ブラウザのセッション** — claude.ai / anthropic.com へのログイン状態
3. **Claude デスクトップアプリのセッション**

### 対応ブラウザ

Chrome / Brave / Edge / Arc / Chromium

## 補足

- ローカルセッション依存のため、ログイン状態やサービス側の仕様変更によって利用状況を取得できない場合があります
- 通知機能とログイン起動は、`.app` バンドルとしてインストールした場合のみ有効です

## ライセンス / License

MIT License — © 2026 X: [@tako3](https://x.com/tako3) / [umi.design](https://umi.design/)
