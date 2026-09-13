# 設計レビュー記録

2026-09-14。親エージェントによる統合レビュー。コード実装の検証記録ではない。

## 修正した事項

- 旧iOSはSwiftUIではなくExpo+Swift Moduleという調査事実を統合設計へ反映。旧Actionsも未署名ビルド定義として扱い、成功実績は未確認とした。
- 表示方式と計測状態を分離。PiP閉鎖やLive Activity終了だけで保存済み計測を終了させない。
- PiPの無条件背景起動を約束せず、前面でのユーザー開始を基準PoCとした。1Hz金額更新・SNS音声共存は実機ゲート。
- 旧iOSのSQLiteとnative JSONの競合を移行設計に含め、手動終了の上書き・時給の二重保存・読書失敗の握りつぶしを新実装に引き継がない。
- Decimal/丸めはAndroid fixture照合後に決める。集計zoneは端末追従、週は現行履歴と同じ日曜。安易な仕様変更を除いた。
- 別々のShortcutsでsession tokenが自動共有されるという前提を除外。高速再訪時のイベント識別は未検証として残す。
- XcodeGen、Simulatorテスト、画面添付、未署名実機build、署名検証の境界を統一。docs-onlyで重いCIを回さず、必須チェックPendingを避ける設計を追加。
- サブエージェント構成をユーザー指定のLuna MAX / Sol Mid / Astra Midへ更新。既存成果の再利用を明記。

## 実施した確認

- 親自身が旧iOSのREADME・app設定・依存・Actions・設計・native保存/AppIntent・SQLiteコードを読んだ。
- 親自身が3調査書を読み、Androidのホームと値札設定の実画像を確認。UI担当は別途10画像を確認済み。iOSの新画面はまだ存在しない。
- Android baselineの480ファイルをSHA-256再照合し変更0件、Git状態も一致。
- 設計文書の相対Markdownリンクの存在を検証。
- 本段階でアプリのテスト、ビルド、署名、実機確認は実施しない。設計文書だけを作業ブランチへコミットする。

## 実装へ持ち越す事項

最低OS・固定Xcode/runnerの組、PiPの毎秒背景描画、SNS共存、Shortcuts挙動、署名資材、旧版更新移行の実機結果は未確定。次のPoCで検証する条件が設計されているため、設計完成とこれらの機能完成を区別する。

次の作業は [実装引き継ぎ](implementation-handoff.md)。統合仕様は [刷新設計](../ios-redesign-plan.md)。
