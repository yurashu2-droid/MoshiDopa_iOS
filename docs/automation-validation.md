# オートメーションガイド検証

## 全体実行（2026-09-15 JST）

- Run [34908344216](https://github.com/yurashu2-droid/MoshiDopa_iOS/actions/runs/34908344216)、commit `7fe54a2`。
- 単体19件成功。通常UI13件中12件成功（ガイド再開・計測画面への遷移、4種類PiP実映像、Live ActivityのOS表示を含む）。小画面UI2件成功。Releaseビルド成功。
- 失敗1件は既存の計測テストの初期設定操作。XCTestがモード選択メニューのButtonのhit pointを取得できず、待機処理でも `Failed to determine hittability ... Activation point invalid` が発生した。実計測の開始前に失敗しており、金額の加算の成否を確認できた実行ではない。
- 親エージェントがガイドの撮影画像を確認。文字の重なり・欠けなし。撮影は同じRelease機能を持つ前の実行34905937001の画像を使用。

## テスト修正と再検証の範囲

DEBUGビルドに限り、明示された `MOSHIDOPA_UI_TEST_TRACKING_MODE` の `background` / `shortcuts` を初期設定として注入する。通常起動・Releaseには適用しない。値はUserDefaultsにも保存する。測定テストは背景方式であることをUIで確認したうえで、実際の待機開始→Home→加算→復帰一時停止→保存→再起動後の実履歴を検証する。ガイドテストには注入せず、実際の設定開始ボタンとShortcuts方式のUIを検証する。

これは計測の前提状態を独立させる修正であり、メニューの操作自体の検証を代替するものではない。計測テストはモードの再起動後の永続化までは主張しない。

再確認は単体19件、ガイドと実計測のUI2件、Releaseビルドに限定する。全体実行で通過済みのほかの画面・小画面テストと合わせて評価し、単一の全体実行が成功したとは記載しない。

CIの `[tracking-check]` マーカー付きpushはこの限定確認を実行する。通常pushとPRは従来どおり全体テスト・画面撮影・小画面確認を実行する。用途はテストの初期設定修正等に限り、Release機能変更時は全体確認を行う。

親が変更を統合レビュー。Sol Mediumが初期状態の注入とCI選択条件を独立レビュー。Bash構文とYAMLのパース確認済み。

## 最終結果（2026-09-15 JST）

- Run [34911018054](https://github.com/yurashu2-droid/MoshiDopa_iOS/actions/runs/34911018054) で単体19件と実計測UIは成功。ガイドUIは手順変更後に前ページのスクロール位置が残り、次ボタンを表示できず失敗。Releaseビルドは成功。
- ガイド画面を `ScrollViewReader` で手順変更ごとに先頭へ戻し、テストから逆方向の補正スワイプを除去した。
- Run [34912286439](https://github.com/yurashu2-droid/MoshiDopa_iOS/actions/runs/34912286439)、commit `0eee909` は成功。単体19件、ガイドUI、実計測UIがすべて成功し、実計測は待機→Homeで加算→復帰時に一時停止→保存→再起動後の履歴まで確認。unsigned Release IPAビルドとLive Activity拡張の構造検査も成功。native-gate成功。
- 全体実行34908344216で通過した通常UI12件・小画面UI2件と、最終の限定実行を合わせて評価する。単一の全体実行成功とは扱わない。
- `MoshiDopa-unsigned.ipa` は0.3.3 / build 6、19,815,520 bytes。SHA-256 `F8E3AB9E818816484170B0109C3EC028F17BF89983D42F1C5E8BCC0DFC2E42E0`。Live Activity有効フラグ、拡張bundle、拡張実行ファイルを親が展開検査した。

Shortcutsアプリでの個人用オートメーション登録、対象SNSの実開閉によるApp Intent配送、PiPとの共存は実機未確認。ガイド完了をOS側の登録成功とは扱わない。
