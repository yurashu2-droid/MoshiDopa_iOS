# iOS platform / CI 設計監査

調査日: 2026-09-14。設計のみ。Windows上のソース読解とApple/GitHub公式資料の確認であり、Xcode・Simulator・署名・実機・審査を実行した結果ではない。

## 現状の事実

- `package.json` は Expo 57 / React Native 0.86。`modules/moshidopa-intents/ios/MoshidopaIntentsModule.swift` は開始・終了・最新明細を開くAppIntentとJSONイベントキュー。開始・終了は `openAppWhenRun = false`、明細表示のみtrue。PiP/ActivityKit実装ではない。
- `app.plugin.js` は最低iOS 16.4とURL schemeを設定。Widget extension、App Group、PiP用Background Modes、Live Activities設定は存在しない。新ネイティブ構成にExpo由来の最低OSを無条件継承しない。
- キューはApplication Support内で、NSLockによるプロセス内直列化とatomic write。読み書き失敗を `try?` で捨てるため、保存成功を判定できない。別プロセス拡張との共有・競合制御には不足する。新構成では共有ストアのトランザクションとエラー伝播を設計する。
- `.github/workflows/ios-unsigned-ipa.yml` は `macos-15` + Xcode 26.3、Expo prebuild、Pods、未署名Release iphoneos build、IPA梱包、14日artifact保存。`xcodebuild test`、UIテスト、スクリーンショット、xcresultはない。workflowの存在は実行成功の証拠ではない。

## 技術事実と採用判断

| 項目 | 公式資料で確認した事実 | 設計判断 / 未検証 |
|---|---|---|
| 金額PiP | AVKitにsample buffer layer向けPiP playback delegateがある。再生状態・時間範囲・サイズ変更などを実装する。[Apple API](https://developer.apple.com/documentation/avkit/avpictureinpicturesamplebufferplaybackdelegate) | SwiftUIとは別にCore Graphics → pixel buffer → CMSampleBuffer → AVSampleBufferDisplayLayerへ金額を描くPoC。任意SwiftUIボタンをPiPに置ける前提にしない。背景1Hz供給・消費電力・安定性は未検証。 |
| PiP開始 | custom playerはユーザー操作による開始が必要。[Apple custom player](https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-in-a-custom-player)。inlineの自動開始は再生中コンテンツから背景へ移行する機能。[Apple standard player](https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-in-a-standard-player) | 基準経路は「アプリ前面でユーザーがPiP開始→SNSを開く」。未起動・背景のShortcutsから無条件にPiPを出す設計は採用しない。前面復帰と開始可否の明示が必要。 |
| 背景更新 | 背景実行は目的別APIで管理され、汎用の無期限毎秒タイマーではない。[Apple DTS](https://developer.apple.com/forums/thread/685525) | 計測の正本は開始時刻・停止時刻・時給スナップショット。タイマー発火数を積算しない。PiP描画が止まっても復帰時に再計算。無音音声ループで延命する方式は採用しない。 |
| SNS音声 | `.playback` は既定では非mixable。`.mixWithOthers` は他アプリ音声とのmixを許す。[Apple audio](https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/mixwithothers) | PoC候補はplayback+mixWithOthers、duckなし、不要時deactivate。相手アプリ・通話・音声経路変更での中断や別PiPとの競合は別途実機評価し、常時共存を保証しない。 |
| Shortcuts | Appトリガーは選択アプリの開く/閉じる・切替で実行できる。[Apple Shortcuts](https://support.apple.com/en-ae/guide/shortcuts/apde31e9638b/ios) | ユーザー自身が個人用オートメーションを設定する。イベント間計測でありScreen Time取得ではない。未設定/無効/重複/遅延/開始のみを処理。SNS起動による計測開始とPiP開始を別状態にする。 |
| Live Activity | 通常は前面で開始。`LiveActivityIntent` を採用するApp Intentなら背景から開始できる例外がある。[Apple ActivityKit](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities) | ロック画面/Dynamic Island用。SNS画面上の自由配置オーバーレイではない。最新SDKでの例外を最低OSへ一律外挿せず、availabilityと実機を確認。汎用AppIntentの現実装はこの例外を実装していない。 |
| Live Activity更新 | ActivityKitはアプリ/APNsから更新し、Widget timelineとは異なる。[Apple overview](https://developer.apple.com/documentation/activitykit) | システムの時刻表示と独自金額の毎秒再計算は同義ではない。最終更新金額+更新時刻、経過時間、終了操作を候補とし、毎秒正確な金額をLive Activityの約束にしない。 |
| 審査 | background servicesは本来の目的に限定される（2.5.4）。[App Review](https://developer.apple.com/app-store/review/guidelines/) | 「金額だけのPiP」が審査で受理されるか未検証。公開APIで動く事実と審査適合性は分離する。PiP必須ならPoCと配布方針の決定を製品着手ゲートにする。 |

## 新SwiftUI構成の候補（未実装）

SwiftUI App + SessionCore +永続ストア + AppIntents + PiPCoordinator（AVKit/UIKit境界）+任意Widget extensionに分離する。PiP/Live Activity/ホーム画面は同じセッションの投影で、表示終了と計測終了を混同しない。共有データが必要ならApp Groupとトランザクション可能な保存方式を採用し、JSキュー依存を解消する。既存JSON/SQLiteからの移行は実装範囲に含む。旧実データ・配布実績の有無は未確認であり、旧署名版からの更新とShortcuts互換を別途試験する。ネイティブ化だけでiOSの背景制限が消えるわけではない。

最低OSはPoC結果で確定。候補はiOS 17以上（インタラクティブLive Activityを使う場合）。旧OSを残すなら非対応機能を分岐する。新しいSDKだけにある背景開始経路を製品必須条件にしない。

## 実機PoC試験表

全件未実施。OS/端末/SNSバージョン/commit/時給/開始経路を記録し、外部カメラ動画、delegateログ、render timestamp、終了時金額を証跡にする。最低対応OS候補と現行安定OS、Dynamic Island有/無で実施。

| 試験 | 手順 | 提案合格条件 / 判断 |
|---|---|---|
| 基本PiP | 前面ボタン→ホーム→SNSで15分以上、連続60分で観察 | 1Hz目標の表示遅延p95≤2秒、5秒超停止なし。失敗なら原因と代替候補を提示して製品判断へ戻す。時間のみのアプリへ縮退しない。 |
| 音声共存 | YouTube/Instagram/TikTok/Xの動画をPiP開始前後に再生、ミュート切替 | SNS音声の意図しない停止/音量低下なし。相手PiP開始時は自PiP停止を安全処理。 |
| OS介入 | ロック、低電力、着信、Bluetooth切替、長時間背景 | 停止理由を記録、復帰後金額整合。ロック中のPiP表示継続は要求しない。 |
| 終了・強制終了 | PiP閉じる、停止、アプリ強制終了、再起動 | セッション終了と表示停止が仕様通り。再起動時に未完了を説明し修正可能。 |
| Shortcuts | cold/warm/backgroundから開始・終了、重複、順序逆転、無効化 | 保存確認後成功。重複で二重課金しない。PiPが出ない状態を成功扱いしない。 |
| LiveActivityIntent | ロック中/背景/coldで開始・終了、許可OFF、最低OS | 対応環境のみ成功、失敗時もセッションを破損せず前面導線へ。 |
| 金額・時計 | 1,800円/h、端数、日跨ぎ、タイムゾーン/時計変更 | 共通計算規則と終了明細一致。時計変更時の扱いを明記、tick数依存なし。 |
| 負荷 | 60分のPiPあり/なしを同条件比較 | CPU/メモリ/thermal/電池を記録。許容予算は実測後に設定、事前に省電力保証しない。 |

## GitHub Actions設計（未実装）

PR/push/manualは署名不要Simulator検証を行う（docs-onlyは除外）。XcodeGenの `project.yml`、shared scheme `MoshiDopa`、unit/UI test targetsをバージョン管理し、生成器のバージョンも固定する。生成後にschemeを検証する。runner/Xcodeは検証済み組を固定し、起動時に `xcodebuild -version` と `xcrun simctl list devices available` を保存する。現行 `macos-15` の公式inventoryにはXcode 26.3があるが、runner内容は変動するため毎run確認する。[GitHub inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-arm64-Readme.md)

1. checkout→固定版XcodeGenで生成→依存解決（Package.resolved固定）→scheme検証→Simulator作成/boot→ `xcodebuild -project MoshiDopa.xcodeproj -scheme MoshiDopa -destination 'platform=iOS Simulator,id=<booted-UDID>' -resultBundlePath artifacts/TestResults.xcresult CODE_SIGNING_ALLOWED=NO test`。プロジェクト名は新構成確定時に合わせる。`set -o pipefail`でログ保存時もテスト失敗を伝播する。
2. unit: 時給/端数/時刻・再開・重複/逆順イベント・永続化失敗。UI: 初期設定→計測→終了→明細、空/進行中/終了/エラー、長文、Dynamic Type、日本語、小画面/大画面。固定clockとfixtureをlaunch argumentsで与える。
3. UIテストの各基準画面を `XCTAttachment(screenshot:)` + `.keepAlways` で保存。通常は成功時に破棄されるため明示が必要。[Apple XCTest](https://developer.apple.com/documentation/xctest/adding-attachments-to-tests-activities-and-issues)。テスト結果のPNG添付を抽出する手順は固定Xcodeの `xcresulttool help` で確認して組み込む。xcresultそのものも必ず残す。
4. `if: always()` のartifact stepでxcresult、PNG、build/test log、環境manifest（SHA、runner image、Xcode、Simulator OS）をupload。14日保存、OS/端末別の一意な名前。artifact欠落を検知し、ログ中の個人情報は使用しない。[GitHub artifacts](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts)
5. device Release未署名buildはSimulator検証に続く別job。未署名IPAはコンパイル成果物で、インストール/entitlement/実機成功の証拠ではない。署名済みarchive/export/TestFlightは別の保護environmentと署名資材で運用し、Simulator PR jobには秘密情報を渡さない。

Simulator合格と実機PoC合格は別ゲート。PiPの他アプリ音声、背景実行、Shortcuts、ロック、Live Activityの実際の起動権限、App Group entitlement、消費電力は署名済み実機で検証する。CIのスクリーンショットでこれらを合格扱いしない。App Store審査もさらに別の結果である。
