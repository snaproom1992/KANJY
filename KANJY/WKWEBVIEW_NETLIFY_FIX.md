# WKWebView Netlifyドメイン対応の修正

## 🐛 問題

Xcodeシミュレーター（WKWebView）で、回答一覧の参加者名をクリックしても編集ページに遷移しない問題が発生していました。

**状況**:
- ✅ Chrome/Safariブラウザでは正常に遷移する
- ❌ Xcodeシミュレーター（WKWebView）では遷移しない
- ❌ 実機（WKWebView）でも遷移しない可能性が高い

**報告日**: 2026年1月2日  
**対象ファイル**: `KANJY/ScheduleWebView.swift`

---

## 🔍 原因

ScheduleWebView.swiftの`decidePolicyFor navigationAction`デリゲートメソッドで、**許可するドメインのリストに`kanjy-web.netlify.app`が含まれていなかった**ため、WKWebViewがナビゲーションをブロックしていました。

### 修正前のコード

```swift
// kanjy.vercel.app ドメイン内のナビゲーションを許可
if url.host == "kanjy.vercel.app" || url.host == "kanjy-dzxo9jpk7-snaprooms-projects.vercel.app" || url.host == "localhost" {
    print("✅ [Navigation]: 同一ドメイン内の遷移を許可")
    decisionHandler(.allow)
} else {
    // 外部リンクは許可しない（セキュリティのため）
    print("⚠️ [Navigation]: 外部リンクのため拒否: \(url.host ?? "不明")")
    decisionHandler(.cancel)
}
```

**問題点**:
- `kanjy-web.netlify.app`が許可リストに含まれていない
- ハードコードされたドメインチェック（保守性が低い）
- 新しいドメインが追加されても気づきにくい

---

## ✅ 実装した修正

### 修正後のコード

```swift
// 許可するドメインのリスト
let allowedHosts = [
    "kanjy-web.netlify.app",      // 本番環境（Netlify）
    "kanjy.vercel.app",            // 旧本番環境（Vercel）
    "kanjy-dzxo9jpk7-snaprooms-projects.vercel.app", // Vercel Preview
    "localhost",                   // ローカル開発
    "127.0.0.1"                    // ローカル開発（IP）
]

// ドメインチェック
if let host = url.host, allowedHosts.contains(host) {
    print("✅ [Navigation]: 許可されたドメイン内の遷移を許可")
    print("   - Host: \(host)")
    print("   - Path: \(url.path)")
    print("   - Query: \(url.query ?? "なし")")
    decisionHandler(.allow)
} else {
    // 外部リンクは許可しない（セキュリティのため）
    print("⚠️ [Navigation]: 外部リンクのため拒否")
    print("   - Host: \(url.host ?? "不明")")
    print("   - URL: \(url.absoluteString)")
    decisionHandler(.cancel)
}
```

---

## 📊 改善点

### 1. Netlifyドメインの追加

```swift
"kanjy-web.netlify.app"  // 追加！
```

これで、本番環境（Netlify）でのページ遷移が許可されます。

---

### 2. 配列ベースの管理

**Before**:
```swift
if url.host == "domain1" || url.host == "domain2" || url.host == "domain3" {
```

**After**:
```swift
let allowedHosts = ["domain1", "domain2", "domain3"]
if let host = url.host, allowedHosts.contains(host) {
```

**メリット**:
- ✅ 可読性の向上
- ✅ 保守性の向上
- ✅ ドメイン追加が容易
- ✅ 一目で許可リストを把握できる

---

### 3. 詳細なログ出力

```swift
print("✅ [Navigation]: 許可されたドメイン内の遷移を許可")
print("   - Host: \(host)")
print("   - Path: \(url.path)")
print("   - Query: \(url.query ?? "なし")")
```

**効果**:
- デバッグが容易
- どのURLに遷移しているか明確
- パラメータの確認が可能

---

## 🧪 テスト方法

### 1. Xcodeシミュレーターでテスト

```bash
# Xcodeでアプリをビルド＆実行
1. スケジュール調整画面を開く
2. 回答一覧セクションまでスクロール
3. 任意の参加者名をクリック
4. → response-form.htmlに遷移することを確認
```

---

### 2. Xcodeコンソールログの確認

```
# 遷移時のログ
🔄 [Navigation]: https://kanjy-web.netlify.app/response-form.html?id=...&edit=...
🔍 [Navigation Type]: 4
🔀 [Navigation]: その他（JavaScriptなど）
✅ [Navigation]: 許可されたドメイン内の遷移を許可
   - Host: kanjy-web.netlify.app
   - Path: /response-form.html
   - Query: id=...&edit=...
📡 [Navigation]: 読み込み開始
✅ [Navigation]: 読み込み完了 - https://...
```

---

### 3. 実機でのテスト

```bash
1. Xcodeから実機にアプリをインストール
2. スケジュール調整画面を開く
3. 回答一覧の参加者名をクリック
4. → 編集ページに遷移することを確認
```

---

## 🔒 セキュリティ考慮事項

### 許可するドメインのポリシー

1. **本番環境のみを許可**
   - `kanjy-web.netlify.app` ✅
   - 信頼できるドメインのみ

2. **開発環境の許可**
   - `localhost` ✅
   - `127.0.0.1` ✅
   - ローカル開発のため

3. **外部ドメインは拒否**
   - フィッシング対策
   - XSS攻撃の防止
   - ユーザーの安全を確保

---

## 📝 今後の対応

### ドメインが変更される場合

`allowedHosts`配列に追加するだけ：

```swift
let allowedHosts = [
    "kanjy-web.netlify.app",
    "new-domain.com",  // 新しいドメインを追加
    // ...
]
```

---

### プレビュー環境の追加

Netlifyのブランチデプロイやプレビューデプロイを使用する場合：

```swift
let allowedHosts = [
    "kanjy-web.netlify.app",
    "deploy-preview-123--kanjy-web.netlify.app",  // プレビュー環境
    // ...
]
```

または、ワイルドカード的なチェック：

```swift
if let host = url.host, 
   (allowedHosts.contains(host) || host.hasSuffix(".netlify.app")) {
    // 許可
}
```

---

## 🔗 関連ファイル

- `KANJY/ScheduleWebView.swift` - 今回修正したファイル
- `WKWEBVIEW_NAVIGATION_FIX.md` - 過去のWKWebView修正レポート
- `EDIT_RESPONSE_FIX.md` - 編集機能の修正レポート

---

## 📊 Before / After

### Before（問題）

```
ブラウザ:
✅ index.html → response-form.html（遷移成功）

WKWebView:
❌ index.html → response-form.html（遷移失敗）
⚠️ [Navigation]: 外部リンクのため拒否: kanjy-web.netlify.app
```

---

### After（修正後）

```
ブラウザ:
✅ index.html → response-form.html（遷移成功）

WKWebView:
✅ index.html → response-form.html（遷移成功）
✅ [Navigation]: 許可されたドメイン内の遷移を許可
   - Host: kanjy-web.netlify.app
```

---

## 🎓 学んだ教訓

### 1. WKWebViewは厳格なセキュリティ

ブラウザでは動作しても、WKWebViewでは動作しないことがある。
- decidePolicyFor navigationActionの実装が必須
- 許可するドメインを明示的に指定する必要がある

---

### 2. ドメイン変更時の注意

本番環境のドメインが変更された場合：
- SwiftコードのallowedHostsも更新する
- 忘れるとWKWebViewで遷移できなくなる
- テストを徹底する

---

### 3. デバッグログの重要性

詳細なログがあると、問題の切り分けが容易：
- どのURLに遷移しようとしているか
- なぜ拒否されたのか
- どのドメインが許可されているか

---

## 🚀 デプロイ手順

```bash
cd /Users/tsujitakehiro/Desktop/ios_KanjyApp/KANJY

# Swiftファイルの変更をコミット
git add KANJY/ScheduleWebView.swift
git add WKWEBVIEW_NETLIFY_FIX.md
git commit -m "fix: WKWebViewでNetlifyドメインへの遷移を許可

- allowedHosts配列にkanjy-web.netlify.appを追加
- ドメインチェックを配列ベースに変更（保守性向上）
- 詳細なログ出力を追加（デバッグ容易性向上）"

# GitHubにプッシュ
git push origin main
```

---

## ✅ チェックリスト

- [x] ScheduleWebView.swiftの修正
- [x] allowedHostsにNetlifyドメイン追加
- [x] 詳細なログ出力の追加
- [x] lintエラーチェック
- [ ] Xcodeシミュレーターでの動作確認
- [ ] 実機での動作確認
- [ ] 本番環境での動作確認

---

## 🎯 期待される動作

### Xcodeシミュレーター

1. スケジュール調整画面を開く
2. 回答一覧の参加者名をクリック
3. → **編集ページに遷移する** ✅
4. フォームに既存の回答が読み込まれる
5. 「回答を更新」ボタンが表示される

---

**作成日**: 2026年1月2日  
**作成者**: AI Assistant  
**関連Issue**: WKWebViewでの編集機能が動作しない問題

---

<div align="center">

**すべての環境で編集機能が動作するように** 📱

</div>

