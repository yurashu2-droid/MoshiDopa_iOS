# もしドパ iOS 最小技術検証設計

## 今回の範囲

Expo Development Build とローカル Expo Module を使い、YouTube のショートカット・オートメーションから開始／終了イベントを受け、セッション明細を表示する最小実装を対象にする。Screen Time、FamilyControls、DeviceActivityReport、Live Activities、画像共有、INVEST の完成 UI は実装しない。

## データ経路

1. App Intent が実行されると、React Native の起動を前提にせず、Swift の `MoshidopaNativeStore` が Application Support 内の `native-event-queue.json` にイベントを追記する。
2. 開始時に、その時点でネイティブ側へ保存済みの時給をセッションへコピーする。設定されていなければ `needsWage` のままにし、既定値を勝手に適用しない。
3. アプリ起動時に `expo-sqlite` がキューを取り込み、`native_events.event_id` の一意制約で再取り込みを防ぐ。SQLite への取り込みが完了した後だけネイティブキューを ACK する。
4. 終了時は同じ `activityID` の実行中セッションだけを閉じる。開始なしの終了、重複開始、時計の巻き戻しは診断情報に残す。

Swift と JavaScript は同じ SQLite ファイルを直接同時更新しない。Swift はイベントキュー、JavaScript は取り込み後の表示用 SQLite を担当する。

## 明細自動表示

App Intents の終了アクションは記録だけを行い、開始・終了のどちらも無条件にアプリを前面表示しない。自動表示をONにする場合、ショートカット側で終了アクションの後に `もしドパ：最新の明細を開く` をユーザーが追加する。OFF の場合はこのアクションを追加しない。iOS が個人用オートメーションをアプリから無断作成する前提にはしない。

## 再生成とネイティブコード

Swift は `modules/moshidopa-intents/ios/MoshidopaIntentsModule.swift` のローカル Expo Module として管理する。`app.plugin.js` が URL scheme と iOS deployment target を prebuild 時に設定するため、生成された `ios/` への手編集に依存しない。App Intents はホストアプリターゲットに含まれる構成であり、現段階では別の Intent Extension ターゲットを作らない。

## 対応OSと未検証事項

- App Intents は iOS 16.0 以降を対象にする。
- 実装は Expo SDK 57 / React Native 0.83 系を前提にする（安定版での対応状況は EAS ビルド時に再確認する）。
- Windows 環境では iOS Simulator、Xcode、Apple Developer 署名を検証できないため、今回のコード検証に実機成功の判定は含めない。
- App Intents のホストアプリ実行が端末・OS・署名条件でどう扱われるか、YouTube の開閉オートメーション、ロック中、通知センター、素早い開閉は Mac と iPhone 実機で確認が必要。
- App Groups、FamilyControls の配布 entitlement、DeviceActivityReport のプライバシー境界は後続検証で扱う。

公式資料：

- https://docs.expo.dev/develop/development-builds/introduction/
- https://developer.apple.com/documentation/appintents
- https://support.apple.com/guide/shortcuts/apde31e9638b/ios
- https://developer.apple.com/documentation/deviceactivity/deviceactivityreport
