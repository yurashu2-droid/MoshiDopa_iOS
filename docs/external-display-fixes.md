# 実機報告後の計測・外部表示修正

## 0.3.1 / build 4の追加調整

PiP映像を640×180（約3.56:1）の金額のみの値札に変更し、縦の占有を減らす方向に調整。初期ウインドウのサイズと最小値はiOS管理であり、アプリから最小サイズを強制できない。実機での初期寸法は未検証。映像生成と計測snapshotを0.1秒間隔（10fps）に変更。計測はTimer回数ではなく既存の経過時間から算出し、金額は小数2桁を維持。保存とLive Activityの5秒周期は維持。frame_enqueuedは負荷を抑えて1秒ごとのサンプルログとするため、ログ件数は総フレーム数ではない。背景のTimer実行間隔はOSによって制限され、10fps継続を保証しない。以下のCI/IPAは0.3.0の検証記録であり、0.3.1の合格を表さない。

対象は作業ブランチ `codex/ios-native-ui-pip`。Androidとmainは変更しない。アプリ全体の実データ統合・旧Expo移行はこの修正の完了条件に含めない。

## 実機ログで確認した事実

ユーザー提供の診断JSONはiPhone / iOS 26.5.2。PiP開始成功5回、映像enqueue466回、背景かつPiP動作中のenqueue71回、レイヤーのOperation Interrupted4回。enqueueは映像が実際に見えた証拠ではない。ユーザーは黒画面を報告しており、旧IPAの実機映像表示は不合格。元の計測はボタンから停止までの全経過時間を加算し、対象アプリの使用時間を分離していなかった。

## 今回の変更

- SessionServiceは加算済み時間と現在の加算区間を分離。待機開始は0円で停止状態、重複した開始/一時停止通知で二重加算しない。区間切替の保存が失敗しても、その境界のメモリー状態は維持し、対象外の時間を加算しない。停止保存の失敗は従来どおり金額を固定して再試行する。
- 初期設定の「本体の外にいる時間」は、didEnterBackgroundで加算開始、willEnterForegroundで一時停止。ホーム画面なども含むため「対象SNS使用時間」と同一ではない。画面ロックはprotectedDataWillBecomeUnavailable通知を受けた場合に停止するが、通知時刻・パスコードなし・OS停止中の欠落は実機で確認が必要。
- 「対象アプリの開閉（Shortcuts）」はLiveActivityIntentをホストプロセスで実行し、同じSessionServiceに開閉を通知。オートメーションのアプリ名が一致する終了だけ適用し、他アプリの古い終了通知で最新対象を停止しない。再開の重複は無視する。本体へ戻った場合も停止する。iPhone上のオートメーション設定はユーザー操作が必要。通知の遅延・欠落・順序逆転の完全な検出はできない。
- PiPのCVPixelBufferにIOSurface/Metal互換設定を追加。表示UIViewのbacking layerをAVSampleBufferDisplayLayerにし、明示的な高さでゼロサイズを防ぐ。CoreMediaのホストクロックを映像時刻とtimebaseの共通基準に使用。開始準備はKVOで待ち、5秒で失敗を表示し音声セッションを解放。準備中・表示中の重複開始は抑制する。isReadyForDisplay、status、bounds、windowと加算境界をログに追加。これらは黒画面の修正候補であり、実機で映像が見えるまで解消済みとはしない。
- ActivityKitで実Activityをrequest/update/endし、WidgetKit拡張をIPAに埋め込む。値札設定のPiP/Live Activityボタンは両方とも実計測画面に遷移する。待機中は待機として開始、ロック画面・Dynamic Islandの全表示面に金額を表示。紙/インクを反映する。
- Live Activityは実行時間がある間の5秒間隔および加算境界で最新金額を渡す。更新は直列化して最新境界を保持する。計測中の表示は15秒でstaleになり、前回の金額/更新時刻を示す。背景の毎秒金額更新やAPNsサーバーは実装しない。終了は金額を保存してから外部表示を終了。再起動は従来の最後の保存区間のみ中断記録とし、古いLive Activityを終了する。

## 検証と実機手順

Windows上のソース確認だけでビルド・実機合格とはしない。

親レビュー: Sol MediumはLive Activity実装と統合コードの独立レビュー、Luna MAXは計測/映像/画面テストに限定。親は全変更を統合し、ロック解除の再開漏れ、更新/終了taskの競合、保存再試行テストの前提を修正した。CI第1回 [34836521534](https://github.com/yurashu2-droid/MoshiDopa_iOS/actions/runs/34836521534) / `5c88dac` は親が追加したisReadyForDisplayのiOS 17.4 availability未考慮でコンパイル失敗し、修正pushによりcancelled。対応下限はiOS 17を維持し、17.4未満ではlayer.statusの互換判定を使う。この判定は最初の映像が見えた証拠と同一ではない。

再実行 [34836982479](https://github.com/yurashu2-droid/MoshiDopa_iOS/actions/runs/34836982479) / `cf1b90dc171f4f1facf59bed4f13bee95498e2ed` は全ジョブ成功。Xcode 26.3、iOS 26.2 Simulatorで単体19件、通常画面11件、小画面2件が成功し、iphoneos Releaseビルドも成功。Live Activityの実request/endテストはスキップされず成功した。

IPA: `artifacts/run-34836982479/builds/MoshiDopa-unsigned.ipa`（18,405,850 bytes、0.3.0 / build 3）。親がIPA内のplistと実行ファイルを読み、NSSupportsLiveActivities、WidgetKit拡張とその実行ファイルの埋め込みを確認。取得元builds ZIPのSHA-256は `b4ef1d8dcf64d206f64f353d33120a87e05cdd6a209ef80c68eb1b9a63ebb187` でGitHubのdigestと一致。

親の画像レビュー: `artifacts/run-34836982479/visual/test-attachments/0240DF61-28B2-466A-AB1B-BA28BC03F531.png` では背景移動後に停止した¥1.28のインライン映像が見える。これは実機PiP映像の証明ではない。Live Activity開始画面は表示中だが、`3A7BA1C1-53E5-440A-8F17-2F9FE8F00DE5.png` のホーム画面には金額が見えない。OS上のWidget描画は未確認であり、開始成功だけで表示合格とはしない。CIにはstatus_bar overrideがあり、撮影条件による影響も未検証。WidgetBundleのmainからActivityConfigurationが登録されていることはソース確認済み。OS描画不成立の原因は断定できない。

1. 新IPAを拡張機能を保持して署名・導入する。バージョン0.3.0 / build 3。Sideloadlyなどの「拡張機能を削除」設定は使わない。署名が変わる場合は旧アプリの記録が更新先に引き継がれるか別途確認する。
2. 値札の設定でPiP、見た目を選んで「PiPを表示して試す」。時給1800、計測方法「本体の外にいる時間」で待機開始。3秒待っても0円のままであることを確認。
3. インライン映像に金額が見え、映像表示準備が完了してからPiP開始。SNSへ移動し金額の増加と音声を確認。本体に戻ったら金額が止まること、停止・保存後の履歴を確認。真っ黒なら新しい診断JSONと画面録画を保存。
4. 対象SNSのみを測る場合は「対象アプリの開閉（Shortcuts）」で、SNSを開く→もしドパの「対象アプリの計測を再開」、閉じる→「対象アプリの計測を一時停止」を「すぐに実行」で登録。開閉の両方に同じアプリ名を指定。待機開始とPiP/Live Activity開始後にSNSへ移動する。
5. 停止・保存後、Live Activityと紙/インクを選んで実表示を開始。ロック画面、対応端末のDynamic Islandのコンパクト/最小/展開、更新時刻とstale、戻った時の停止、停止・保存による消去を確認。背景で更新が途切れても計算をタイマー表示で代用しない。
6. SNS音声、別PiP、画面ロック、複数SNS切替、低電力、強制終了と再待機、Live Activity権限拒否・ユーザー消去、15分/60分は実機確認事項。

## 公式仕様と設計判断の区別

Apple公式: [IOSurfaceバッファ設定](https://developer.apple.com/documentation/CoreVideo/kCVPixelBufferIOSurfacePropertiesKey)、[表示準備状態](https://developer.apple.com/documentation/avfoundation/avsamplebufferdisplaylayer/isreadyfordisplay)、[Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)、[LiveActivityIntent](https://developer.apple.com/documentation/appintents/liveactivityintent)、[Shortcutsオートメーション](https://support.apple.com/guide/shortcuts/intro-to-personal-automation-apd690170742/ios)。

待機方式、5秒更新、15秒stale、再起動で区間を推定せず中断扱いにする方針は本アプリの設計判断。PiP黒画面の解消、背景での継続更新、Shortcutsの実配送、署名/導入は実機未検証。技術的な動作とApp Store審査承認は別であり、承認済みとは扱わない。
