# もしドパ iOS 技術検証

「働いていたら」の仮定額を、ユーザーが設定した時給で表示する Expo Development Build 用の最小実装です。既存Web版とは独立しています。

## 開発ビルド

```sh
npm install
npx expo prebuild
npx expo run:ios
```

または EAS の開発ビルドを使う場合：

```sh
npx eas build --profile development --platform ios
```

EAS プロジェクトへの紐付けやクラウドビルドは、Apple Developer の署名・アカウントを確認してから明示的に実行してください。`app.json` にプロジェクトIDだけを書いて連携成功とみなさないでください。

## 最初の確認

1. Development Build を iPhone にインストールする。
2. アプリで時給を保存する（初期表示は 1,800 円）。
3. 連携ガイドを見ながら、ショートカットの個人用オートメーションを二つ作る。
4. YouTube を開くと開始、YouTube から離れると終了を選ぶ。
5. 自動表示を確認する場合だけ、終了オートメーションの後ろに「最新の明細を開く」を追加する。
6. イベント診断で重複や終了対象なしが記録されていないか確認する。

開始・終了イベント間の経過時間であり、Screen Time の利用時間そのものではありません。

## コード検証

```sh
npm run typecheck
npm run export
```

Windows では Xcode を実行できないため、Swift のコンパイル、署名、iPhone 実機挙動は Mac で別途確認してください。
