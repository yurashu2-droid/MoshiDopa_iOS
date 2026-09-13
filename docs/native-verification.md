# ネイティブ版の検証記録

2026-09-14。親エージェントがコード・CIログ・実際のSimulator画像・動画を確認した記録。**今回のGoalの引き渡し条件を満たす**。P1と固定サンプルのP2Aは完了、P2Bは実装レビュー・未署名ビルド・署名/実機試験手順まで完了し、実機動作は未検証。作業ブランチは `codex/ios-native-ui-pip`。

## CIの根拠

| commit / run | 実際の結果 |
|---|---|
| `03c69967c89890814e224fc9ce87a73eedb67b3d` / [34783195768](https://github.com/yurashu2-droid/MoshiDopa_iOS/actions/runs/34783195768) | 全体成功。単体13/13、UI 8/8、Simulator・未署名iphoneos Release成功 |
| `1380b505c04de91b51ae3e7fb8f987cd7a99e238` / [34784373373](https://github.com/yurashu2-droid/MoshiDopa_iOS/actions/runs/34784373373) | 全体失敗。単体14/14、UI 8/9、SEのUI 2/2、未署名Release成功。値札の読み上げラベル不足を検出 |
| `3d8d4b9d99e0a5517458d40ebfca68c0a7dfe840` / [34785720445](https://github.com/yurashu2-droid/MoshiDopa_iOS/actions/runs/34785720445) | 全体成功。単体14/14、UI 9/9、SEのUI 2/2、Simulator・未署名iphoneos Release成功。親が修正後画像を確認 |

上記3実行は全artifactをダウンロード・展開済み。保存先はリポジトリ内 `artifacts/run-<run ID>/{visual,tests,builds}/`。Gitにはビルド生成物を追加しない。Actionsの保存期間は14日。

最終run 34785720445のartifact ID: visual `10326228522`、tests `10326767097`、builds `10326687374`。IPA 18,274,310 bytes、Simulator ZIP 22,647,829 bytes。`Tests.xcresult`、`Compact.xcresult`、ログ、34枚の単独スクリーンショット、テスト添付画像、実行動画と環境記録を保存した。最終ドキュメントcommitはこの検証済みネイティブコードを変更しない。

run 34784373373: Xcode 26.3 (17C529)、XcodeGen 2.46.0、macos15 20260907.0337.1。iPhone 17 Pro MaxとiPhone SE (3rd generation / iOS 26.2)。`environment.txt` にcommitを記録。IPA 18,273,981 bytes、Simulator ZIP 22,647,219 bytes。未署名IPAはそのまま実機へインストールできない。

## 親の画面レビュー

Androidの9/14撮影資料と現行コードを基準に、紙素材・黒とライムの階層・ロゴ・3タブ・各画面の構成を比較した。Androidの空記録スクリーンショットに存在しない会話・単票・通帳はコードを根拠とし、Android実画像との比較済みとは扱わない。

| 対象 | 確認した内容と修正 |
|---|---|
| ホーム・履歴・設定 | 金額階層、ロゴとキャラクター、設定7項目、選択明細への遷移。画像未収録・文字を覆う紙素材・下部ナビとの重なりを修正し、run 34784373373で下部の改善を確認 |
| 単票・通帳 | run 34783195768の共有PNG 7枚でSPEND/INVEST、時間・単価非表示、大きな金額を確認。選択したInstagramの¥705.00明細、空期間の説明も確認 |
| 初回案内・計測入力 | 6段階案内を画像確認。INVEST入力へのモード維持、完了後ホームへの遷移はUIテストで確認。案内と通常画面は保存しないサンプル |
| 値札 | PiP/Live Activityの選択、対応スタイル、少額/通常/大きな金額、モード切替。run 34784373373でロック画面・Islandコンパクト/最小/展開の大きな金額と省略表示を確認。実ActivityKit画面ではない |
| もしも便 | run 34784373373の10段階PNG・3共有PNGと実録画を確認。人物の首・腕の分離と描画範囲外へのはみ出しを修正。Chromeで通常速度の会話→金額→全文への進行を観察。INVEST終了時の髪の切れは最終runの段階画像と共有PNGで解消を確認 |
| 小画面 | SEの7画面と2件の操作テスト。金額と主要操作の横幅を確認。長い明細・会話・設定は縦スクロールを使う。全文が一画面に収まるという合格条件ではない |

run 34784373373のスクロール画像でステータスバー裏の文字を検出したため、次commitでScrollViewの描画をviewport内へ制限した。最終runの `settings-populated-scroll-3` と `counter-live-activity-surfaces-3` で上端の解消、SEホームで下端・大きな金額を確認した。`counter-invest-small` はINVEST/少額の選択と自己投資ラベルを示し、¥0.82の読み上げ値はUIテストで検証する（この画像では金額は画面下）。INVEST全景は `interview-phase-INVEST-18.7` と `share-whatif-populated-INVEST-month-hidden` で頭・足と結果欄の分離を確認。画像の実ファイル名は各manifest.jsonに対応付けられている。ネイティブの文字組み・絵文字・全文配置には意図した差がある（[詳細](interview-fidelity-review.md)）。完全な画素一致は主張しない。

## 計測の検証範囲

親はSessionServiceの単価固定・単調時計・stop再試行・SQLite復旧・PiP保持期間・delegate隔離と音声終了処理をレビュー済み。CIは本体内の実金額増加、停止保存、再起動後の保存履歴を検証する。run 34783195768では実sample-buffer画像に¥0.76、保存済み記録に¥1.06が見える。表示サンプルはこのDBへ書き込まない。

**未実施:** 署名・実機インストール、他アプリ上でのPiP継続更新、SNS音声/別PiPとの共存、長時間負荷、Shortcuts、実Live Activity、旧データ移行、実機でのVoiceOver/Dynamic Type。技術的な動作確認とApp Store審査承認は別。P2Bの製品合格には実機試験が必要。

再現手順は [native-development.md](native-development.md)、実機の試験項目は [pip-device-test.md](pip-device-test.md)。次工程はこの実機結果を記録し、P3連携・P4実データ統合へ進む。今回はmainへのマージ・配布・審査提出を行わない。

## 保全

Androidのbaseline 480ファイルのSHA-256とHEADは変更なし。旧iOS main `1fba7b7b0688112eeef24c65c1976bc1ed130870` は保持され、作業ブランチの祖先。旧Expo DBへアクセスする移行・削除処理は未接続。
