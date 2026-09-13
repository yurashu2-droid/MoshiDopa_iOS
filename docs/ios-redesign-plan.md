# もしドパ iOS 全面刷新設計

更新: 2026-09-14。状態: 設計。アプリ実装・新CI実行・実機検証は未着手。

関連資料: [親レビュー記録](planning/review.md)、[次の実装Goal](planning/implementation-handoff.md)。

## 1. 目的と資料の優先順

他アプリ使用中に「働いていたら」の金額が増える体験をiOSで成立させ、最新Androidと同じブランド・機能体系へ刷新する。時間だけを表示して中核要件の達成としない。

- 対象: `yurashu2-droid/MoshiDopa_iOS`。調査元HEAD: `1fba7b7b0688112eeef24c65c1976bc1ed130870`。
- 設計ブランチ: `codex/ios-redesign-plan`。旧コード・履歴はこの段階では維持する。
- Android基準: `C:/Users/raito/AndroidStudioProjects/TimeCostView` の作業ツリー。HEADは `c6252f8778e94eb269fafa3c5f63d752eb4c2e2f` だが、未コミット・未追跡ファイルも含む。対象480ファイルのSHA-256とGit状態を [baseline](planning/android-baseline.json) に記録。
- 優先順: この会話の決定 → 実コードとテスト → 実画面 → 更新日付き仕様 → 古いREADME。`docs/tasks.md` の未完了改善を実装済み仕様に混ぜない。
- 本書は統合した決定事項。各調査文書は根拠と詳細。矛盾があれば本書を修正してから実装する。

## 2. 調査結果と方針

**確認済み:** 旧iOSはExpo Router/React NativeとローカルSwift Expo ModuleのPoCであり、SwiftUIアプリではない。`app.json` のbundle IDは `com.moshidopa.app`、URL schemeは `moshidopa`。Widget Extension、PiP、Live Activityは存在しない。`.github/workflows/ios-unsigned-ipa.yml` はExpo prebuild→CocoaPods→iphoneos Release未署名ビルド→IPA保存を行う定義で、シミュレーターテスト・画面撮影はない。既存Actionsの成功履歴は本設計で検証していない。

**設計判断:** SwiftUIのホストアプリ、純Swiftの共通ドメイン、SQLite永続化、AVKit PiP、ActivityKit用Widget Extensionへ移行する。JavaScriptランタイムを必要としない単一の計測経路とする。XcodeGenの宣言的 `project.yml` と共有schemeを使い、Windowsで編集しmacOS CIで生成・検証する。生成器のバージョンも固定する。iOS最低対応は17.0を候補とし、PoCで利用APIのavailabilityと旧16.4利用者への影響を確認して確定する。未対応APIはavailability分岐し、未検証の最新SDK機能を必須にしない。

**未検証:** PiP中の継続フレーム更新、音声共存、ShortcutsだけでのPiP開始、署名後の旧アプリ上書き移行、既存Shortcutsの識別子互換性。これらを達成済みと表記しない。

## 3. 実装境界

```text
App / Features (SwiftUI)
  └─ SessionService ── SessionRepository (SQLite)
       ├─ Clock / WageCalculator / PeriodAggregator
       └─ PresentationCoordinator
            ├─ PiPPresenter → FrameRenderer → AVKit
            └─ LiveActivityPresenter → ActivityKit
App Intents ── 同じSessionService
Widget Extension ── ActivityAttributesと読み取り用表示モデル
LegacyImporter ── 旧SQLite + native-event-queue.json → 新DB
```

予定ディレクトリ: `MoshiDopaApp/Features`, `Core/Domain`, `Core/Persistence`, `Platform/PiP`, `Platform/LiveActivity`, `Intents`, `MoshiDopaWidgets`, `Tests`, `UITests`, `ci`。型・プロジェクト設定・署名設定の変更責任者は親エージェント。

- `SessionService.start(command)` / `stop(command)` は保存完了を返す。表示開始の失敗は保存結果と別の `PresentationStatus` で返す。
- `SessionSnapshot` はsession ID、活動ID、SPEND/INVEST、開始時単価、確定/暫定時間、計測根拠、状態を含む。不変スナップショットを表示側へ渡す。
- PiP/Live Activityが閉じられたこととセッション終了を同一視しない。外部表示の停止はアプリ内に示し、終了ボタンは明示的なstop commandを発行する。
- 最初はホストアプリがDBを書き、Widget表示はActivityContentを利用する。App Groupは必要性を検証して導入し、拡張からの多重書き込みを増やさない。導入時も共有UserDefaultsをセッションDBとして使わない。

## 4. 計測・表示設定の契約

計測元 (`manual` / `shortcut`) と表示方式 (`pip` / `liveActivity`) とデザインIDを別々に保存する。OS制約で計測元と表示方式の組み合わせが不成立の場合は、設定画面で必要な操作を示す。

値札設定は「表示方式」→「対応デザイン」→「実寸に近いプレビューと試す操作」の順。PiPは実機PoC成功後に推奨方式とする。両方式に選択肢を用意するが、利用不可端末・権限無効時は理由と復旧導線を出す。Live Activityを選んでも、金額の連続増加を約束しない。モックの金額アニメーションを実機の保証として見せない。

| 項目 | PiP | Live Activity |
|---|---|---|
| 中核表示 | 金額を大きく、時間・時給を補助表示 | 更新時点の金額・更新時刻、システム経過時間、時給 |
| 更新 | 金額計算結果を映像フレーム化。1HzをPoC目標 | 合法的な実行機会にContentState更新。任意の毎秒金額更新は前提にしない |
| 操作 | OSの移動・サイズ・閉じる操作に従う | OSのcompact/minimal/expanded/ロック画面に合わせる |
| 開始 | まず本体で開始→他アプリへ。自動開始は別試験 | 本体とLiveActivityIntentの経路を試験 |
| 制約 | 透明窓・任意位置・OS操作UIの除去を約束しない | 表示寿命・OS裁量・無効化・非Island端末を扱う |

方式・デザインの変更は計測中でも保存できるが、初版は次回セッションから適用し、その旨を表示する。これにより切替による二重計測を避ける。デザイン選択は方式別に保持。時給変更も開始済みセッションには遡及させない。

## 5. 状態・精度・障害

新規計測は全方式で同時に1セッション。`idle → running → finished` を主経路とし、復旧不能な時刻・終了不明は `interrupted / needsReview` として推測で確定しない。手動計測とShortcuts計測は同時開始しない。Shortcuts同一活動の重複開始はno-op。別活動開始は旧活動を受信時点で切替終了し、診断付きで新活動を開始する。古い活動IDのstopで新活動を閉じない。同一活動の高速再訪にはIDだけで解決できない遅延イベントがあるため、直列化・イベントID・世代管理に加えて実機試験と異常診断を行う。

金額は `elapsedMilliseconds / 3_600_000 × hourlyWageAtStart`。更新回数による加算は禁止。丸め・集計の順序はAndroidの実装とテストから固定した共通fixtureで照合する。旧iOSのnull時給は0円に変換しない。

初版の集計は端末タイムゾーンに追従し、週開始は現行履歴の基準である日曜に統一する。保存するsourceZoneは記録時の診断用であり、集計zoneを固定する設定とは区別する。旧レポートの月曜始まりや日付絞り込み不足はそのまま複製しない。既存の表示精度を保つため、Decimal採用や丸めモードはfixture比較前に確定しない。

同一実行区間では単調時計で経過時間を算出する。Dateは履歴・カレンダー・Shortcuts受信時刻用。プロセスをまたぐ経過推定と再起動・時刻変更は別扱いにし、時計の連続性が確認できないときに正確な使用時間と表示しない。画面ロックやPiP停止だけから対象SNS終了を推測しない。Shortcuts経路は実際のforeground監視ではなく、受信したイベント間の時間として出典を記録する。

履歴確定とイベント消費はトランザクション化し、同じ終了の再実行で二重保存しない。保存失敗は成功として返さない。復旧時はDBとActivityKitの活動を照合し、表示だけ残った孤立状態を解消する。

給与・履歴・診断は端末内保存。新DBと移行バックアップはOSバックアップ除外の対象とし、実機で設定を確認する。ロック時のファイル保護によりIntentが保存できない場合は失敗を返す。プライバシー表示はPiP/Shortcutsの方式に合わせて更新し、任意のクラウド送信やScreen Time収集を追加しない。共有は完成画像を確認してOS共有シートから行い、時間非表示等は画面と出力を一致させる。

## 6. 旧データ・既存利用者

アプリIDと同じ署名Teamで更新できる場合の移行を設計する。Git履歴保持はユーザーデータ保持とは別で、別Teamの再署名やアンインストールで旧sandboxを読めるとは限らない。

旧データはExpo SQLiteとApplication Support内JSONの2系統。新DBへの取り込み前に元データを保存し、スキーマ検証、イベントとsession IDによる重複排除、件数・単価・金額・状態の照合、移行完了マーカーまで一貫して実行する。読取失敗を空DBとして上書きしない。進行中旧セッションを無制限に延長せず要確認へ移す。

既存 `MoshidopaStartMeasurementIntent` / `MoshidopaEndMeasurementIntent` / `MoshidopaOpenLastSessionIntent` の名称・パラメータとURL schemeを互換アダプターの候補とする。ただしExpo Moduleからホストへの移動は識別子互換を保証しない。旧署名済み版に作ったオートメーションを更新後に実行する試験を必須化し、失敗時は再設定案内を出す。

詳細と入力優先順位: [データ調査](planning/data-audit.md)。

## 7. 実装ステージと完了条件

| 段階 | 内容 | 完了の証拠 |
|---|---|---|
| D0 設計 | 対応表、契約、移行、PoC、CI、レビュー | 本書と調査書が作業ブランチに保存されリンク検証済み |
| P1 最小ビルド | SwiftUIホスト・共通ドメイン・CI・テスト画面撮影 | 対象commitのActions成功、xcresult、PNG、ログ。単なるYAML追加では不可 |
| P2 PiP中核PoC | 金額の連続更新・開始終了・保存・SNSとの共存 | 動画と計測ログ、実機機種/OS/署名条件付き試験結果 |
| P3 外部連携 | Live Activity、Shortcuts、設定での方式選択 | 無効化・重複・切替・ロック・終了欠落の試験結果 |
| P4 本実装 | Android機能/見た目対応、保存移行、履歴/明細/もしも便 | fixtureテスト、状態別画面比較、親レビュー指摘解消 |
| P5 仕上げ | Releaseビルド、署名可能な構成、操作検証 | CI成果物、移行試験、残課題・実機手順・配布状態の報告 |

P2でPiPの中核要件が成立しない場合、時間だけの製品に変更しない。失敗条件と公開APIの代替候補を示して製品判断に戻す。実機がない場合もP2合格とはしない。独立したデータ/CI作業は進められるが、全面UI実装に無条件で移らない。

P2必須試験: 本体→SNSで15分以上、連続60分、音声ON/OFF、YouTube/Instagram/TikTok/Xそれぞれ、相手PiP、ロック/復帰、通知/コントロールセンター、PiP閉じる/再開、プロセス終了、低電力、急速なSNS切替。1Hzフレーム更新の時刻ログと画面録画を突合し、ドリフト・中断・音声干渉・CPU/電池傾向を記録。電池値は端末条件を固定して比較し、未測定の省電力を宣伝しない。

## 8. CIと視覚レビュー

予定workflow: PR/作業ブランチpush/manualのmacOS検証。docsのみのコミットではビルドを起動しない。必須チェックがPendingにならないよう、差分判定と常時完了する集約チェックを置き、重いjobだけを条件分岐する。`contents: read`、同一ブランチの古いrunをキャンセル、timeout、必要なキャッシュだけを使用。Xcode・runner・XcodeGenを相互に利用可能な版へ固定し、実行時の実バージョンを記録する。

生成 → scheme検証 → simulator build/test → XCUITestの固定fixture画面撮影 → iphoneos Release未署名build。`xcodebuild -resultBundlePath`、PNG、必要な動画、ビルドログを失敗時も保存。成果物名にcommit・OS・端末を含める。シミュレーター.appと実機用.app/IPAを区別し、未署名IPAをそのままインストールできるとは書かない。署名が必要なjobは別にし、Secrets未設定をビルド障害や検証成功に混ぜない。

親エージェントはAndroidとiOSの実画像を並べて、情報量、金額階層、余白、紙素材、モード色、文字のはみ出し、操作領域をレビュー。空画面だけでなく、履歴有り・長文・大きい金額・日付切替・共有出力を含める。モーションは動画で入口/中間/出口/割り込みを確認する。スクリーンショット取得失敗をレビュー済みにしない。

WindowsではローカルiOSシミュレーター操作は不可。CIでのシミュレーター画像と実機PiP動作は別の証拠であり、互いを代替しない。App Groups、拡張bundle ID、署名Team、profile、Developerアカウント設定を必要に応じて整備。Xcode UI手作業を当然とせず設定をコード化し、アカウント側でのみ可能な作業を切り分ける。

詳細: [プラットフォームとCI調査](planning/platform-ci-audit.md)、[UI対応表](planning/ui-audit.md)。

## 9. 担当と効率

ユーザー指定のモデル構成: 統括はAstra Mid（親の会話設定）、中間はSol Mid (`gpt-5.6-sol`, `medium`)、末端はLuna MAX (`gpt-5.6-luna`, `max`)。親自身の実行設定をツールで変更したとは扱わない。サブエージェントはモデル・推論強度を明示し、限定した指示と必要なファイルだけを渡す。

親: 共通契約・統合・最終レビュー・完了判定。Luna: 契約確定後の限定調査、実装、テスト、資料整理。Sol: PiP/OS連携などの難所、複数領域にまたがる実装、Lunaが解決できない問題。領域はA:ドメイン/永続化/移行、B:UI/素材/モーション、C:PiP/Live Activity/Shortcuts/CIに分けるが、担当領域と常駐エージェント数は同義にしない。

サブエージェントは最大3体、必要なときだけ起動する。単純作業は親→Lunaへ直接渡し、毎回Solの再読を挟まない。独立して進める親の作業がない場合は委譲せずその場で処理。同じファイルを並行編集しない。調査書・fixture・短い進捗ログを共通資料にし、全会話を毎回共有しない。テストは変更リスクに応じて実行し、同一成功チェックを理由なく繰り返さない。既存調査結果は再利用し、新構成のためだけに調査をやり直さない。

## 10. 次の実装Goalへの引き継ぎ

本書と3調査書を読む。Android baselineの差分を確認し、新変更があれば勝手に基準を更新せず差分を報告する。まずP1/P2を実装し、Actionsの実行結果と実機試験の区別を保つ。P2未検証のまま「他アプリ上で金額が動く」を達成扱いしない。P2の成立後、P3→P4→P5へ進める。実機/署名の不足は必要事項を具体化し、独立作業を進める。今回の設計段階ではmain更新・アプリ変更・新CI実行は行わない。

## 11. 根拠

Apple/GitHub公式資料のURL・確認内容はプラットフォーム調査に集約。ストア掲載例は類似用途の存在だけを示し、当アプリの審査承認の証拠にはしない。ユーザー添付の旧PoC指示は計測方式の参考として扱い、旧UIを維持する指示は今回の全面刷新決定で置き換える。
