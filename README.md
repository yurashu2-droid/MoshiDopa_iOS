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

## GitHub Actionsで未署名IPAを作る

公開リポジトリのGitHub Actionsから、macOS runner上でExpo CNGのiOSプロジェクトを生成し、ローカルSwift Expo Moduleを含むRelease `.app`を未署名でコンパイルできます。workflowは [ios-unsigned-ipa.yml](.github/workflows/ios-unsigned-ipa.yml) です。

Actionsの実行後、`MoshiDopa-unsigned-ipa` artifactをダウンロードし、WindowsのSideloadlyへ渡してください。これは`CODE_SIGNING_ALLOWED=NO`で作る未署名IPAなので、Sideloadly側でApple ID・署名・端末登録が必要です。

このworkflowはRelease構成を使い、JavaScriptをアプリへ内包します。Metro接続を前提にするDevelopment Buildは、Actions runner終了後に接続先がなく、Sideloadlyでの最初の起動確認に向かないため生成しません。Development Buildを使う場合は、Mac上でMetroを起動し、別途署名済みの開発ビルドを作成してください。
