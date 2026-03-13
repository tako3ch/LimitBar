# LimitBar Other-Mac Launch Checklist

このドキュメントは、開発機以外の Mac で `LimitBar.app` が正常起動するか確認するための受け入れチェックリストです。

## 成功条件

- `LimitBar.app` を初回起動して 30 秒以上終了しない
- メニューバー項目、またはフローティングウィジェットのどちらかが表示される
- Settings 画面を開いても即終了しない
- `Refresh now` 実行後もクラッシュしない
- Console / crash report に致命的な例外が残っていない

## 事前に渡すもの

- `scripts/build_app.sh` で生成した `dist/LimitBar.app`
- 可能なら notarize 済み DMG
- 検証者向けメモ
  - macOS バージョン
  - Apple Silicon / Intel
  - Xcode 未導入でもよい
  - 初回起動時に出たダイアログ文言

## 最小テストケース

### 1. 配布物の健全性確認

検証者の Mac で以下を実行してもらう。

```bash
codesign --verify --deep --strict /Applications/LimitBar.app
spctl --assess --type execute -vv /Applications/LimitBar.app
xattr -l /Applications/LimitBar.app
```

確認ポイント:

- `codesign` が成功する
- `spctl` が reject しない
- 不要な quarantine が残っていないか確認できる

### 2. App Translocation を避けた起動

このアプリは `.app` バンドルかどうかと App Translocation を見て挙動を変える。
必ず DMG 内から直接起動せず、`/Applications/LimitBar.app` にコピーしてから起動する。

```bash
open /Applications/LimitBar.app
```

確認ポイント:

- 「Applications フォルダに移動してください」のアラートが出ない
- 起動直後に終了しない

### 3. 画面確認

起動後に以下を確認する。

- メニューバーに `LimitBar` の項目が出るか
- フローティングウィジェットが出るか
- Settings を開いて 10 秒以上保持されるか
- Settings の `Refresh now` を押しても終了しないか

### 4. 未ログイン環境テスト

Codex / Claude のどちらにもログインしていない Mac でも確認する。

期待結果:

- アプリ自体は起動し続ける
- メニューバー表示はセットアップ文言になる
- Settings のアカウント接続操作で適切な案内が出る
- ログインセッション未検出だけでアプリ全体は落ちない

### 5. ログイン済み環境テスト

次のいずれかがある Mac でも確認する。

- `~/.codex/auth.json` がある
- Claude desktop app のセッションがある
- 対応ブラウザで chatgpt.com / claude.ai にログイン済み

期待結果:

- 起動後に自動 refresh が走る
- 使用率取得エラーがあってもアプリが終了しない
- Settings から接続済み表示が確認できる

## 症状別の切り分け

### 症状: 一瞬表示されてすぐ消える

優先確認順:

1. DMG 内から直接起動していないか
2. `/Applications` にコピー後も再現するか
3. `open /Applications/LimitBar.app` で再現するか
4. 直接実行したときに標準エラーが出るか

```bash
/Applications/LimitBar.app/Contents/MacOS/LimitBar
```

5. Console.app で `LimitBar`, `runningboardd`, `amfid`, `syspolicyd` を検索
6. crash report が `~/Library/Logs/DiagnosticReports/` に生成されていないか確認

### 症状: Settings が一瞬出て閉じる

確認ポイント:

- アプリ自体が終了しているか、Settings だけ閉じているか
- メニューバー項目は残っているか
- Widget は残っているか
- Console に SwiftUI / AppKit 例外が出ていないか

## Console で見てほしいもの

Console.app で process を `LimitBar` に絞り、起動直後 1 分のログを保存してもらう。

CLI なら以下でもよい。

```bash
log stream --style compact --predicate 'process == "LimitBar"'
```

起動直後だけ過去ログを見るなら:

```bash
log show --last 5m --style compact --predicate 'process == "LimitBar"'
```

## このコードベースで特に疑うポイント

### 1. App Translocation による即終了

`LimitBar/Sources/LimitBar/App/AppEnvironment.swift` と
`LimitBar/Sources/LimitBar/App/AppModel.swift` では、
`Bundle.main.bundlePath` に `AppTranslocation` が含まれるとアラート表示後に `NSApp.terminate(nil)` を実行する。

そのため、検証者が DMG から直接起動した場合は「一瞬出て消える」に見える可能性が高い。

### 2. 起動直後の自動 refresh

`LimitBar/Sources/LimitBar/Stores/UsageStore.swift` では起動時に notification 権限確認と `refresh()` が走る。
セッション未検出は通常エラー処理される想定だが、他環境依存のブラウザ cookie / SQLite 読み取り失敗がないかログで確認する。

### 3. `.app` バンドル前提機能

`supportsLaunchAtLogin` と `supportsUserNotifications` は `.app` 前提。
バイナリ単体実行や不完全な bundle だと一部挙動が変わるため、検証は必ず完成した `.app` で行う。

### 4. フローティングウィジェットの既定値

`SettingsStore` では `widgetEnabled` が既定で `true`。
他人の環境でウィジェット生成時の AppKit 問題があれば、切り分けとして `UserDefaults` を初期化した上で widget を無効にした build でも再確認する価値がある。

## 検証依頼テンプレート

```text
LimitBar.app の初回起動確認をお願いします。

手順:
1. DMG からではなく /Applications に LimitBar.app をコピー
2. `open /Applications/LimitBar.app` で起動
3. 30 秒待って、メニューバー項目またはウィジェットが出るか確認
4. Settings を開いて 10 秒以上維持されるか確認
5. もし一瞬で消えたら、以下を送ってください
   - macOS バージョン
   - Apple Silicon / Intel
   - どう起動したか
   - Console の LimitBar ログ
   - `~/Library/Logs/DiagnosticReports/` の crash report

補助コマンド:
`spctl --assess --type execute -vv /Applications/LimitBar.app`
`log show --last 5m --style compact --predicate 'process == "LimitBar"'`
```
