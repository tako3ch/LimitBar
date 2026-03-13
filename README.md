# LimitBar

Minimal macOS menu bar monitor for Codex and Claude Code usage.

![screenshot](https://tako3ch.github.io/LimitBar/imgs/cover.avif)

## Download

Download the latest version

https://github.com/tako3ch/LimitBar/releases/latest

## Features

- Monitor Codex / Claude Code usage
- Bar indicator
- Usage limit notifications

## Installation

1. Download DMG
2. Move LimitBar.app to Applications
3. Launch

## About Session Connection

### Codex (OpenAI)

LimitBar checks the following in order:

1. **Codex app or CLI authentication file** — Token saved in `~/.codex/auth.json`

### Claude Code (Anthropic)

LimitBar checks the following in order:

1. **Supported browser session** — Signed-in session on claude.ai / anthropic.com
2. **Claude desktop app session**

### Supported Browsers

Chrome / Brave / Edge / Arc / Chromium / Safari

Safari requires Full Disk Access permission.

## Notes

- Due to its reliance on local sessions, it may not be able to retrieve usage status depending on login status or changes in service specifications.

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

LimitBar は次の順で確認します：

1. **Codex アプリまたは CLI の認証ファイル** — `~/.codex/auth.json` に保存されたトークン

### Claude Code（Anthropic）

LimitBar は次の順で確認します：

1. **対応ブラウザのセッション** — claude.ai / anthropic.com にサインイン済みの状態
2. **Claude デスクトップアプリのセッション**

### 対応ブラウザ

Chrome / Brave / Edge / Arc / Chromium / Safari

Safari を利用する場合は、フルディスクアクセスの許可が必要です。

## 補足

- ローカルセッション依存のため、ログイン状態やサービス側の仕様変更によって利用状況を取得できない場合があります

## ライセンス / License

MIT License — © 2026 X: [@tako3](https://x.com/tako3) / [umi.design](https://umi.design/)
