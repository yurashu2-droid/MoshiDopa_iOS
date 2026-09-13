# 共有画像の視覚レビュー証拠

`ShareImageTests` はレシート4枚、期間明細3枚、もしも便3枚、合計10枚のPNGをXCTest結果へ `keepAlways` 添付する。各形式でpopulated/large、SPEND/INVEST、時間表示/非表示を含む。レシートのlargeは最大額の記録を選び、大きい金額と長いINVEST活動名を確認対象にする。期間明細・もしも便は日/月の代表を含む。

UIのShareLinkとテストは同じ内部 `shareUIImage` を呼び、既存の紙/会話Viewを幅430pt・3倍で描画する。期間明細のグループ化も共通化した。画面のデザイン変更、画像の本番保存、共有先への送信は行わない。テストはUIImage/CGImage、非ゼロ画素寸法、PNGデータ、PNG再読込を確認する。

Windows作業環境ではXcode/iOS SimulatorがないためコンパイルとImageRenderer実行、PNGの親視覚レビューは未実施。次のmacOS CIで `ShareImageTests` を実行し、xcresultの `share-*` PNGを抽出して設計§8の共有出力レビューを行う必要がある。寸法/PNG成功だけでは文字切れ・余白・紙素材の合格にはしない。
