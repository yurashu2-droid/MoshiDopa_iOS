# 計測・保存・金額モデル監査と移行案

2026-09-14。設計のみ。Androidの未コミットファイルを含む作業ツリーと旧iOSを読み取った。コード・実データ・Git履歴は変更していない。以下の「提案」は現行実装の保証ではない。

## 現行の事実

参照略称: **A** = `C:/Users/raito/AndroidStudioProjects/TimeCostView/app/src`、**I** = `C:/Users/raito/AndroidStudioProjects/MoshiDopa_iOS`。A配下のmainは `main/java/com/example/timecostview`、test/androidTestも同パッケージ。

| 項目 | Android | 旧iOS |
|---|---|---|
| 計時 | `domain/TrackingSession.kt:20–42`。壁時計とmonotonicを別入力、時間はmonotonic差の非負値。開始時保存、完了失敗はactive維持。 | `I/modules/moshidopa-intents/ios/MoshidopaIntentsModule.swift:93–143`。Date差で終了時間算出、負値を0へ。同一activityIDの重複開始は無視するが、別activityIDは同時に開始できる。 |
| 保存 | `data/Store.kt:11–50`。SQLite v2、recordsに時刻・時間・レート・project/category/note。完了分割をtransaction。active状態やイベントIDはDBにない。 | `I/src/db.ts:28–134`。SQLite `sessions/settings/native_events/diagnostics`、eventIDで再取り込み抑止。nativeはApplication Support/Moshidopa/native-event-queue.jsonをNSLockで保護しatomic書込、JS起動時にSQLiteへ移す。 |
| 金額 | `domain/Cost.kt:9–29`。`durationMs × hourlyRate / 3600000`、Double、表示は小数2桁。月給÷月間時間。 | `I/src/db.ts:186–188`。同式を円単位でfloor。nullレートはnull金額。nativeも開始時レートを固定する。 |
| 日付 | `domain/DaySegments.kt:8–43`。`start + duration`を端点としてカレンダー境界分割。自動は完了時に日別保存、手動は1件。履歴は両者を表示時に再分割。 | 旧保存モデルにzone・日別分割なし。 |
| 集計 | `domain/HistorySummary.kt:28–51`、`HomeSummary.kt:8–20`、`ReportSummary.kt:20–48`。日/月/範囲でclipして合算。HomeはSPENDのみ。手動/INVESTはproject/categoryを含むグループ、自動SPENDはapp単位。 | `I/app/index.tsx:24–46`。全sessionを取得、最初のactiveを表示。 |

追加の要修正点（ソースからの判断）:

- `I/src/db.ts:174–183` の手動終了はSQLiteだけを書き、nativeのactiveを閉じない。後続のnative snapshot upsertで終了を上書きできる。取り込みは複数SQLをtransactionにまとめず、revision比較もないため、競合・順序逆転を保証していない。
- native `read/write:66–76` は失敗を握りつぶす。破損読込が空データに見え、後続書込で置換され得る。NSLockの保護範囲は同一プロセスであり、複数プロセスの共有保存には使えない。
- `I/app/settings.tsx:27–29` はSQLite設定とnative設定を別々に保存する。異なるレートが残り得る。
- Android `tracking/TrackingService.kt:83,208` はoverlay権限を計測条件にしている。iOSには移植しない。`START_NOT_STICKY`、5秒checkpoint（同:236）、active復元なしから、強制終了後の最後の区間の完全保存は保証されない。
- Android `Store.today:70` は開始日の下限だけで絞り込み上限がない。新設計は全画面で同じ半開区間clipを使う。週の先頭は `HistoryWindow.weekStart` と同じ日曜にそろえる（`ReportSummary.build` の月曜との差は初版で解消する）。

## 提案する共通契約

「共通」はSwift/Kotlin間の同じ仕様・fixtureを意味し、バイナリやソースの共有は必須にしない。iOSの計測・書込主体をnativeのSessionService + Repositoryに一本化し、App Intent・アプリUIは同じコマンド入口を使う。SQLiteを正本とし、拡張との共有が必要ならApp Group内に配置する（実機でアクセス経路を検証）。プロセス内直列化に加えてDB transactionで競合を扱う。

| データ | 必須フィールド・規約 |
|---|---|
| Session | UUID、activityID/displayName、mode(SPEND/INVEST)、source(manual/shortcut/platform)、sourceZone、startWallMs/endWallMs、elapsedMs、rateSnapshot(nullable)、project/category/note、state(running/finished/interrupted)、revision、endReason、quality、originalSourceID |
| 時間アンカー | sessionID、bootEpoch、monotonicStart、checkpointMonotonic、checkpointElapsedMs、checkpointWallMs。壁時計は表示・診断、金額は時間差から算出する。 |
| Event | UUIDのcommandID/eventID、sessionID、sessionRevision、kind、observedWallMs、payload。commandID uniqueと期待revisionで同じ開始/終了を一度だけ反映。 |
| Settings | version付きレート入力、対象活動、週開始日、displayMode(pip/liveActivity)。displayModeをsession開始可否に使わない。 |

ライフサイクルと中断:

1. 同時activeは全体で1件。開始は設定snapshotとactive行を同transactionで作り、永続化成功を返してから表示する。同じcommandIDは既存結果を返す。同じ活動の二重開始はno-op。別活動開始は前活動終了＋新開始を1 transactionにする。
2. 終了は対象sessionIDとrevisionを指定する。終了済みへの再送はno-op、遅れた終了が新しいsessionを閉じることを禁止。activityIDだけの旧Intentには活動の現activeへの解決と診断を付けるが、古い終了との識別不能は残る。新入口はsession tokenを返すものの、独立した開始/終了Shortcuts間でtokenは自動共有されない。配布可能な設定手順と同一活動の高速再訪時の競合は未検証である。
3. タイマーtickは描画だけ。実行機会にcheckpoint、開始/終了/設定変更は即保存。PiPを閉じる、Live Activityをdismissする、表示権限がない、描画更新が止まることは終了イベントではない。明示的な「計測終了」だけが終了コマンドを出す。
4. 手動/shortcutは開始から明示終了までの区間という意味を持つ。他アプリの実利用時間と同一視しない。サスペンド中の定期実行は前提にせず、同じbootで信頼できる連続clockアンカーがあれば終了時に差分を確定する。プラットフォーム自動計測はOSが観測できた対象利用区間だけを記録する。
5. reboot/アンカー不整合/旧データの終了欠落はinterrupted。確認できるcheckpointまでを保持し、現在時刻までの推定加算・勝手な再開はしない。修正は元値を保持した訂正操作。DB書込失敗時は成功や保存済み明細を出さず、同じcommandIDで再試行可能にする。

金額・日付:

- 開始時にレート固定。設定変更は次sessionから適用。新入力はAndroidと同じ正数・有限・上限10億、月間時間は0超〜744時間。旧データの範囲外値は削除せず移行診断へ。
- 計算契約は `Σ(elapsedMs × snapshotRate / 3600000)`。入力・snapshotは10進文字列、月給換算は分子/分母も保持する。Decimal系で内部計算し、合算後に小数2桁・half-upで表示する案は候補だが、AndroidのDouble計算・表示との一致は未検証である。実装時に共通fixtureを比較し、丸め方式と順序を決定する。日別に丸めてから月合計しないこと、表示された行の合計と総計に差が出る場合の扱いも同じfixtureで決める。
- nullレートは0円に変換しない。「未設定」を表示し、集計に未換算時間/件数を併記。小額・0秒も保存でき、明細自動表示閾値と保存条件は別にする。
- UTC整数msとsessionごとのsourceZoneを保存する。初版の集計はAndroidと同様に集計時の端末zoneへ追従させ、sourceZoneとは分けて扱う。集計zoneを設定に固定しない。1日24時間の固定値を使わず、日/月境界をカレンダーから求める。`[start, end)` でclipし、分割ms合計を元elapsedと一致させる。壁時計変更時も金額が増減しないよう、会計上の区間はAndroidと同様 `start + elapsed`、観測終了時刻は別保持して診断を付ける。
- 1つのsession正本を日/月別の読み取りモデルへ分け、表示用分割を新sessionとして数えない。初版の集計は端末zoneに追従し、sourceZoneは計測時の保存情報として集計zoneとは別に扱う。週の先頭は現行 `HistoryWindow.weekStart` と同じ日曜にする。端末zone/週開始日の変更は集計の再計算で、元sessionは変更しない。

## 旧iOSデータの移行手順（実装時の必須条件）

1. 同じbundle identity/containerを維持。旧保存入口を止めるmigration gateを新native側に置き、旧SQLite `moshidopa.db`（`I/app/_layout.tsx:7`）はSQLite backup方式でWALを含む整合snapshot、native JSONはロック中に別名backup、hashと件数をmanifestに記録。生DBファイルだけのコピーや旧queueのack/deleteを先に行わない。Git履歴保持は端末データ保全の代替にならない。
2. 旧SQL schemaとJSON双方を読める移行readerで新DBを別名作成。旧DBがないfresh installと、破損・権限エラーを区別。失敗時は旧データを残し読み取り/再試行状態にする。取り込み中の新commandは永続待機させるか明確な再試行エラーにし、成功扱いで捨てない。
3. 旧session UUIDでSQLite・native session・pending event snapshotを照合。import済eventIDは再適用せず、未反映終了を回収。SQLite finished/manuallyClosedとnative runningなら終了済みを優先。終了値が互いに違う場合は双方を競合記録へ残し、SQLite値を暫定表示して要確認。createdAtだけで勝者を決めない。終了履歴のないrunning/needsWageはinterruptedにして現在まで延長しない。
4. `id/activityId/displayName/mode/startedAt/endedAt/elapsedMs/hourlyWage/diagnostics`を保持、project/category/noteは空文字。elapsedMsを壁時計から再計算しない。元のDoubleレートとfloor表示の旧金額は移行監査に保存し、統一表示で小数が現れる差を追跡可能にする。nullレートの遡及補完はしない。未知state・不正JSON・負時間・重複ID競合は隔離記録へ残す。
5. レート設定は旧SQLiteの有効値を採用、なければnative設定。相違は診断に保存しsession snapshotには触れない。旧autoDisplayは明細設定としてのみ移し、PiP/Live Activityの自動開始同意に転用しない。旧zoneは不明なのでmigration時の端末zoneをsourceZoneに仮置きし `legacy_zone_assumed` を保持する。
6. 新DB transactionで全行・event marker・旧ID対応・migrationVersionをcommit。前後の元ID件数、確定elapsed総量、レート別未丸め金額、null件数、診断/隔離件数を照合し、すべて説明可能なときのみ新DBへ切替。同じmigrationVersion/sourceID uniqueで再実行しても増殖させない。ackが必要ならcommit後のみ。旧backupは検証済み移行後も明示的な削除まで保持する。

## 検証計画と未検証

ソースにある既存テスト: `A/test/java/com/example/timecostview/TrackingSessionTest.kt` はmonotonic・深夜跨ぎ・二重finish・保存失敗再試行、`CostTest.kt` は時給/月給・DST・分割合計、`A/androidTest/java/com/example/timecostview/StoreTransactionTest.kt` は途中insert失敗時rollbackを検証する。本監査では実行していない。旧iOS package.jsonにtest scriptはなく、探索範囲で専用テストを確認できなかった。

新しい共通fixtureに 1800円/時×100ms=0.05円、28分=840円、320000÷160=2000円、深夜1秒+2秒、DST23/25時間、月末、時計巻戻り、レート変更、nullレート、重複/順序逆転、再起動、commit/ack各段階の強制終了、旧手動終了競合を含める。全表示（Home・履歴・明細・PiP・Live Activity）が同じsession revisionを参照することも確認する。

iOSのboot判定/連続clockの実装選択、App Intentsの実際の実行プロセス・保護データアクセス、App Groupへの既存container移行、PiP/Live Activityの更新可能頻度・停止挙動、実端末データの存在/内容は未検証。機能・保存保証として扱わず、native試作と実機受入の確認項目にする。
