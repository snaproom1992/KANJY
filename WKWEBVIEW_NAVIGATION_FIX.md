# WKWebView内でのページ遷移問題の修正

## 🐛 問題

Xcodeシミュレーター（または実機）でiOSアプリ内のWKWebViewを使用している際、「回答フォームに入力」ボタンをクリックしても、`response-form.html`に遷移できない問題が発生していました。

## 🔍 原因

### WKWebViewのセキュリティ制限

WKWebViewは、セキュリティのために以下の制限があります：

1. **デフォルトではJavaScriptによるナビゲーションが制限される**
   - `window.location.href = "response-form.html?id=..."`が機能しない
   - 同一ドメイン内でも遷移が自動的には許可されない

2. **`decidePolicyFor navigationAction`デリゲートメソッドが必要**
   - このメソッドを実装しないと、ナビゲーションが暗黙的に拒否される
   - 明示的に`.allow`を返す必要がある

### 実際のブラウザとの違い

| 環境 | JavaScriptナビゲーション | 制限 |
|------|-------------------------|------|
| **Safari/Chrome** | ✅ デフォルトで許可 | なし |
| **WKWebView（未設定）** | ❌ デフォルトで拒否 | 要デリゲート実装 |
| **WKWebView（設定済み）** | ✅ 許可 | 同一ドメインのみ |

---

## ✅ 修正内容

### ScheduleWebView.swift - Coordinatorクラス

`decidePolicyFor navigationAction`デリゲートメソッドを追加しました：

```swift
// ナビゲーションポリシーを決定（ページ遷移を許可）
func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    // 同一ドメイン内のナビゲーションを許可
    if let url = navigationAction.request.url {
        print("🔄 [Navigation]: \(url.absoluteString)")
        
        // kanjy-web.netlify.app ドメイン内のナビゲーションを許可
        if url.host == "kanjy-web.netlify.app" || url.host == "localhost" {
            print("✅ [Navigation]: 許可されました")
            decisionHandler(.allow)
        } else {
            // 外部リンクは許可しない（セキュリティのため）
            print("⚠️ [Navigation]: 外部リンクのため拒否: \(url.host ?? "不明")")
            decisionHandler(.cancel)
        }
    } else {
        decisionHandler(.allow)
    }
}
```

### 追加されたセキュリティ機能

1. **同一ドメインのみ許可**
   - `kanjy-web.netlify.app`と`localhost`のみ許可
   - 外部サイトへの遷移は拒否（フィッシング対策）

2. **デバッグログの追加**
   - ナビゲーションの開始・完了・失敗をXcodeコンソールに出力
   - 問題のトラブルシューティングが容易に

3. **エラーハンドリングの強化**
   - `didFailProvisionalNavigation`デリゲートメソッドを追加
   - より詳細なエラー情報を取得

---

## 🎯 修正後の動作フロー

### 1. ユーザーがボタンをクリック

```javascript
// index.html - goToResponseForm関数
function goToResponseForm() {
    console.log('🔄 回答フォームへの遷移を開始');
    const urlParams = new URLSearchParams();
    urlParams.set('id', currentEventId);
    window.location.href = `response-form.html?${urlParams.toString()}`;
}
```

### 2. WKWebViewがナビゲーションリクエストを受信

```
Xcodeコンソール:
🔄 [Navigation]: https://kanjy-web.netlify.app/response-form.html?id=f2697d56-dce9-42c8-8417-1c827fa4bf02
```

### 3. decidePolicyForがナビゲーションを評価

```swift
// ScheduleWebView.swift
if url.host == "kanjy-web.netlify.app" {
    print("✅ [Navigation]: 許可されました")
    decisionHandler(.allow)  // ← ナビゲーションを許可！
}
```

```
Xcodeコンソール:
✅ [Navigation]: 許可されました
📡 [Navigation]: 読み込み開始
```

### 4. response-form.htmlが読み込まれる

```
Xcodeコンソール:
✅ [Navigation]: 読み込み完了 - https://kanjy-web.netlify.app/response-form.html?id=f2697d56-dce9-42c8-8417-1c827fa4bf02
```

### 5. 候補日程が表示される

```javascript
// response-form.html
document.addEventListener('DOMContentLoaded', async function() {
    // イベント情報を読み込み
    await loadEvent(currentEventId);
    // 候補日程を表示
    generateScheduleOptions(event.candidate_dates);
});
```

---

## 📊 Before / After

### Before（修正前）

```
1. ユーザーがボタンをクリック
   ↓
2. JavaScript: window.location.href = "response-form.html?..."
   ↓
3. WKWebView: ナビゲーションリクエスト受信
   ↓
4. decidePolicyFor: 実装なし
   ↓
5. ❌ デフォルトで拒否（何も起こらない）
```

**Xcodeコンソール:**
```
（何も表示されない）
```

**ユーザー体験:**
- ボタンをタップしても反応なし
- ページ遷移が発生しない
- エラーメッセージもなし

---

### After（修正後）

```
1. ユーザーがボタンをクリック
   ↓
2. JavaScript: window.location.href = "response-form.html?..."
   ↓
3. WKWebView: ナビゲーションリクエスト受信
   ↓
4. decidePolicyFor: ドメインをチェック
   ↓
5. ✅ 同一ドメインなので許可
   ↓
6. response-form.htmlが読み込まれる
   ↓
7. 候補日程が表示される
```

**Xcodeコンソール:**
```
🔄 [Navigation]: https://kanjy-web.netlify.app/response-form.html?id=...
✅ [Navigation]: 許可されました
📡 [Navigation]: 読み込み開始
✅ [Navigation]: 読み込み完了 - https://...
```

**ユーザー体験:**
- ボタンをタップすると即座に反応
- スムーズにページ遷移
- 候補日程が表示される
- フォームが正常に機能

---

## 🧪 テスト方法

### 1. Xcodeシミュレーターでテスト

```bash
# Xcodeでアプリをビルド＆実行
# シミュレーターでアプリを起動
```

1. **スケジュール調整画面を開く**
   - TopViewからイベントをタップ
   - 「スケジュール調整を作成」をタップ

2. **Webページを確認**
   - WKWebViewでindex.htmlが表示される
   - 「回答フォームに入力」ボタンが表示される

3. **ボタンをタップ**
   - ボタンをタップ
   - response-form.htmlに遷移することを確認

4. **Xcodeコンソールを確認**
   ```
   🔄 [Navigation]: https://kanjy-web.netlify.app/response-form.html?id=...
   ✅ [Navigation]: 許可されました
   📡 [Navigation]: 読み込み開始
   ✅ [Navigation]: 読み込み完了
   ```

5. **候補日程が表示されることを確認**
   - 「日程ごとの回答」セクションに候補日程が表示される
   - ○/？/×ボタンが機能する

---

## 🔒 セキュリティ考慮事項

### 1. ドメイン制限
- `kanjy-web.netlify.app`のみ許可
- `localhost`は開発用に許可（本番では削除推奨）
- 外部ドメインへの遷移は拒否

### 2. フィッシング対策
```swift
if url.host == "kanjy-web.netlify.app" || url.host == "localhost" {
    decisionHandler(.allow)
} else {
    // 悪意のあるサイトへの遷移を防ぐ
    decisionHandler(.cancel)
}
```

### 3. 将来的な改善案
- ホワイトリストを設定ファイルに外出し
- サブドメインも許可する場合は正規表現でマッチング
- 本番ビルドでは`localhost`を除外

---

## 📝 関連する他の修正

### 1. response-form.htmlのSupabase変数修正
- **問題:** 重複宣言エラー
- **修正:** 条件付き宣言に変更
- **ファイル:** `response-form.html`

### 2. index.htmlのデバッグログ追加
- **目的:** 遷移プロセスの可視化
- **追加:** `goToResponseForm()`にログ出力
- **ファイル:** `index.html`

### 3. モバイルレイアウト最適化
- **改善:** ヘッダー、ボタン、テーブルのモバイル対応
- **効果:** Xcodeシミュレーターでも見やすい
- **ファイル:** `index.html`, `response-form.html`

---

## 🎓 学んだ教訓

### 1. WKWebViewの特殊性
- 通常のブラウザとは異なる動作
- デリゲートメソッドの実装が必須
- デフォルトは「拒否」という安全な設計

### 2. デバッグの重要性
- ログ出力で問題の原因を特定
- Xcodeコンソールとブラウザコンソールの両方を確認
- ネイティブとWebの境界で問題が起きやすい

### 3. セキュリティとUXのバランス
- 便利さのためにすべてのナビゲーションを許可するのは危険
- ドメイン制限でセキュリティを保ちつつUXを向上
- ホワイトリスト方式が推奨

---

## 🚀 次のステップ

### 1. 実機でテスト
- Xcodeシミュレーターだけでなく、実際のiPhoneでもテスト
- 実機特有の問題がないか確認

### 2. エラーケースのテスト
- ネットワーク切断時の動作
- 無効なイベントIDでの動作
- 外部リンクをクリックした場合の動作

### 3. パフォーマンス確認
- ページ遷移の速度
- メモリ使用量
- バッテリー消費

---

**作成日:** 2025-12-20  
**最終更新:** 2025-12-20  
**作成者:** AI Assistant

