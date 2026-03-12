# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ビルド・実行

- Xcode で `Package.swift` を開いてビルド・実行する
- Swift Package Manager ベース（Xcode プロジェクトファイルなし）
- 最小ターゲット: macOS 14 / Swift 6.2
- テストターゲットは現時点で存在しない

## アーキテクチャ概要

`LimitBar/Sources/LimitBar/` 以下を階層化：

```
App/        エントリーポイントとオーケストレーション
Models/     ドメインモデル（ServiceKind, UsageSnapshot, UsageStatus）
Providers/  使用状況取得の抽象化層（UsageProvider プロトコル）
Stores/     状態管理（SettingsStore, UsageStore）
Services/   OS 統合（通知、ログイン起動）
Theme/      カラー・スタイル定数
Views/      SwiftUI ビュー（MenuBar, Widget, Settings, Components）
```

### データフロー

1. `UsageStore.refresh()` が全プロバイダーを並列で呼び出す
2. 各プロバイダーが `UsageSnapshot` を返す
3. `AppModel` が `SettingsStore` と `UsageStore` を Combine で監視
4. ビューは `@ObservedObject` / `@StateObject` でリアクティブに更新

### UI 構成

- **メニューバー**: `MenuBarExtra` + `MenuBarDashboardView`（ドロップダウン）
- **フローティングウィジェット**: `NSPanel` を `WidgetWindowController` で管理。透明・常時前面オプションあり
- **設定画面**: `Settings` シーン + `SettingsView`（Form ベース）

### Providers の実装状態

現在 `MockUsageProvider` のみ有効（時間ベースのサイクル値を返す）。
`CodexUsageProvider` と `ClaudeCodeUsageProvider` はスタブ（`notImplemented` をスロー）。
実装時はそれぞれ OpenAI / Anthropic API と統合する。

### 機能制限

`AppEnvironment.swift` で `.app` バンドルかどうかを判定し、以下をフラグで制御：
- `supportsLaunchAtLogin` — `SMAppService` 登録（バンドルアプリのみ）
- `supportsUserNotifications` — UNUserNotificationCenter（バンドルアプリのみ）

### 状態管理のポイント

- `AppModel`, `SettingsStore`, `UsageStore` はすべて `@MainActor`
- `SettingsStore` の各プロパティは `didSet` で `UserDefaults` に同期
- `WidgetWindowController` はウィジェットのサイズ・スタイル・ウィンドウレベルを動的に更新し、変更時に SwiftUI ビューをホストするウィンドウを再構築する
