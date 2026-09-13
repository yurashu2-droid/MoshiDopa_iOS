# 設定トップ視覚レビュー

2026-09-14。Android の `docs/screenshots/app-2026-09-14/05-settings.png`、`MainActivity.kt` の `settingsMenu()`、`PaperUi.menu()` と、iOS の設定添付画像・`ui-audit.md` を照合した。

変更:

- Android と同じ `Hero → 7枚の設定カード` の階層に揃え、トップの重複した戻る行を除いた。サンプル表示は記録と混同しないよう、Home と同じ控えめな11pt注記で残した。
- `このアプリについて` をサポート内のボタンから設定カード列へ移し、既存の `open-about` を維持した。ガイドと PiP の導線は下部サポートに残した。
- カードを最小64pt、カード間12pt、左右18/14pt、タイトル16pt、補足12ptへ寄せ、Android の紙繊維・影・アイコン・文言に合わせた。値札カードは `値札の設定` の名称と、選択中の PiP/Live Activity 方式を補足へ残した。fixture の値と操作IDは維持した。
- 下部タブの「計測」は設定トップからホーム (`.home`) へ戻す Android の遷移先に合わせた。

未検証:

- Windows では iOS の Xcode/Simulator を実行できないため、最終レイアウト・Dynamic Type・VoiceOver は未確認。親の次回CI画像で確認する。
- Android 側は読み取り専用。実データ接続、対象アプリ名の動的取得、PiP 実機動作はこの変更の対象外。
