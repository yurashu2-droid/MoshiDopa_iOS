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
- `Compact.xcresult`: iPhone SEのタブ移動・選択明細テスト。`screenshots/compact/` に大きな金額の7画面。
- `test-attachments/`: 共有PNGと、もしも便の決定的な入口・会話・品物・金額・反応・終了フレームを含む。
- `screenshots/`: 実際のSimulatorから撮影した画面。
- `whatif-preview.mp4`: もしも便の実行画面録画。
- `MoshiDopa-simulator.zip`: Simulator用.app。実機用ではない。
- `MoshiDopa-unsigned.ipa`: iphoneos Releaseの未署名成果物。そのまま端末へインストールできない。
- 環境・対象commit・選択Simulator・ビルドログを同じartifactに保存。

成果物は `ios-visual-<commit SHA>`（画像・動画）、`ios-tests-<commit SHA>`（xcresult・ログ）、`ios-builds-<commit SHA>`（Simulator/実機向け未署名ビルド）に分ける。各成果物に環境・commit情報を含め、保存期間は14日。Actionsが成功するまでは、この一覧は成果物の仕様であり生成済みの証拠ではない。

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


## 署名した実機試験へ渡す手順（未実施）

1. Macで本ブランチの検証対象commitをcheckoutし、上記のasset準備とXcodeGen生成を行う。CI成果物の `environment.txt` とcommitを照合する。
2. iPhoneをMacへ接続し、端末の信頼確認・Developer Modeを有効にする。Xcodeの実行先からそのiPhoneを選ぶ。
3. `MoshiDopa` ターゲットのSigning & Capabilitiesで、利用者のDevelopment TeamとAutomatically manage signingを設定する。既存アプリの更新試験では旧版と同じTeam・bundle IDが必要。別IDを使う場合は旧データ移行の検証にはならない。
4. `MoshiDopa` schemeをDebugでRunする。Apple側の証明書・端末登録が不足する場合は、そのエラーを解決してから進む。未署名IPAをそのまま転送してもこの手順の代わりにはならない。
5. 本体の設定画面を下へスクロールしてPiP検証を開く。時給を設定→「計測開始」→本体の金額増加→「PiP開始」→SNSへ移動、の順で試す。通常のサンプル画面は実記録の履歴ではない。
6. 本体へ戻り「停止・保存」。検証画面の保存済み履歴を確認し、ログを書き出す。実機試験表のケースごとに録画・ログ・機種・OS・署名条件を残す。
7. 結果を `docs/pip-device-test.md` の各未実施項目に対応付ける。ビルド成功や本体内の金額増加だけで、背景表示・音声共存を成功に変更しない。

この手順は引き継ぎ用で、署名済みビルドの生成・実機インストール・実機試験を実施済みとするものではない。証明書、秘密鍵、プロビジョニングプロファイルをリポジトリへ追加しない。
