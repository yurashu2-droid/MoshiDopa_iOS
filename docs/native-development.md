# ネイティブ版のビルドと検証

対象は `project.yml` から生成するSwiftUIアプリ。リポジトリに残る `app/`、`src/`、`modules/`、npm/Expo設定は旧PoCの履歴参照用で、新ネイティブターゲットには含めない。旧DBを削除・移行する処理はこの段階にはない。

## ローカルMac

Xcode 26.3、XcodeGen 2.46.0を使用する。対応OSはiOS 17以降。

```sh
bash ci/prepare-assets.sh
xcodegen generate
xcodebuild -list -project MoshiDopa.xcodeproj
open MoshiDopa.xcodeproj
```

schemeは `MoshiDopa`。Simulatorなら署名不要。実機へ入れるにはホストターゲットのDevelopment Teamとその端末に有効な署名設定が必要。bundle IDは既存と同じ `com.moshidopa.app` なので、旧版への上書き前にデータを保全すること。別Teamの署名で旧sandboxが維持されるとは限らない。

## GitHub Actions

`Native iOS build and visual verification` が作業ブランチpush/PR/manualで実行される。重い処理はネイティブ関連変更に限定。

- `Tests.xcresult`: unit/UIテストと添付画像。
- `screenshots/`: 実際のSimulatorから撮影した画面。
- `whatif-preview.mp4`: もしも便の実行画面録画。
- `MoshiDopa-simulator.zip`: Simulator用.app。実機用ではない。
- `MoshiDopa-unsigned.ipa`: iphoneos Releaseの未署名成果物。そのまま端末へインストールできない。
- 環境・対象commit・選択Simulator・ビルドログを同じartifactに保存。

成果物名は `ios-evidence-<commit SHA>`、保存期間14日。Actionsが成功するまでは、この一覧は成果物の仕様であり生成済みの証拠ではない。

## UI再現と実計測の区別

通常の画面再現は固定サンプルの読み取りモデルを使う。サンプルは本番履歴へ書き込まない。計測画面/設定から開くPiP検証画面は、実際の開始・終了・SQLite保存を行う別の経路。

再現用起動引数:

```text
--screen home --fixture empty
--screen history --fixture populated
--screen receipt --fixture large
```

screen: `home/history/settings/counter/receipt/statement/onboarding/whatif/measurement`。
fixture: `empty/populated/large`。CIは同じ入力で画面を比較する。値札設定のLive Activityはこの段階では面別プレビューであり、実ActivityKit連携はP3。

## 実機で確認すること

[PiP実機試験](pip-device-test.md)に従い、時給・機種・OS・SNSバージョン・署名経路とログを記録する。毎秒のフレーム生成コードやSimulatorテストが通っても、他アプリ使用中に継続更新できた証拠にはならない。署名、Shortcuts、Live Activityの実起動、SNSとの共存、電池消費も別途検証する。
