# WKWebView タッチイベント重複実行問題の修正

## 📋 問題の詳細

### 発生していた現象
- ボタンをタップすると、一瞬だけ遷移しようとする
- すぐにエラー -999（NSURLErrorCancelled）が発生
- 元のページに戻ってしまう

### 根本原因

iOS/WKWebViewでは、**タッチイベントとクリックイベントの両方が発火する**：

```
1. touchend イベント発火 → goToResponseForm() 呼び出し → ナビゲーション開始
2. click イベント発火（約300ms後）→ goToResponseForm() 呼び出し → 2つ目のナビゲーション開始
3. 2つのナビゲーションが競合 → 最初のナビゲーションがキャンセル（エラー -999）
4. 元のページに戻る
```

### ログからの証拠

```
📱 ボタンがタップされました（touchend）
🔄 回答フォームへの遷移を開始
✅ window.location.href を設定しました
🔄 [Navigation]: https://kanjy-web.netlify.app/response-form.html?id=...
✅ [Navigation]: 許可されました
📡 [Navigation]: 読み込み開始
❌ [Navigation]: 暫定的な読み込みに失敗 - error -999
🔄 [Navigation]: https://kanjy-web.netlify.app/?id=... （元のページに戻る）
```

## ✅ 解決策

### 1. グローバルフラグの追加

```javascript
let isNavigating = false; // ナビゲーション中フラグ（重複防止）
```

### 2. 関数の重複実行防止

```javascript
function goToResponseForm() {
    console.log('🔄 回答フォームへの遷移を開始');
    
    // 重複実行を防止（touchendとclickの両方が発火するため）
    if (isNavigating) {
        console.log('⚠️ すでにナビゲーション中です。重複実行を防止します。');
        return;
    }
    isNavigating = true;
    console.log('✅ ナビゲーションフラグをONにしました');
    
    // ... 遷移処理
}
```

### 3. イベントリスナーの設定

```javascript
// タッチイベント（モバイル用）
goToResponseFormBtn.addEventListener('touchend', function(e) {
    console.log('📱 ボタンがタップされました（touchend）');
    e.preventDefault();
    e.stopPropagation();
    goToResponseForm(); // フラグで保護されている
}, { passive: false });

// クリックイベント（デスクトップ用）
goToResponseFormBtn.addEventListener('click', function(e) {
    console.log('🖱️ ボタンがクリックされました（click）');
    e.preventDefault();
    e.stopPropagation();
    goToResponseForm(); // フラグで保護されている
});
```

## 🎯 動作フロー

### iOS/モバイル
1. ユーザーがタップ
2. `touchend` イベント発火 → `goToResponseForm()` 実行 → `isNavigating = true`
3. `click` イベント発火 → `goToResponseForm()` 実行 → フラグがONなのでreturn
4. ナビゲーションが1回だけ実行される ✅

### デスクトップ
1. ユーザーがクリック
2. `click` イベント発火 → `goToResponseForm()` 実行 → `isNavigating = true`
3. ナビゲーションが1回だけ実行される ✅

## 📝 重要なポイント

1. **`e.preventDefault()`**: デフォルトの動作をキャンセル
2. **`e.stopPropagation()`**: イベントの伝播を停止
3. **`{ passive: false }`**: `preventDefault()`を有効にするために必須
4. **`isNavigating`フラグ**: 最も重要な防御策

## 🔧 その他の試みた方法

### ❌ `setTimeout(100)` を追加
- 遅延を入れてもエラー -999 は発生した
- 根本的な解決にはならなかった

### ❌ `window.location.replace()` に変更
- `href`と同じ問題が発生した
- 重複実行が原因だったため

### ✅ フラグによる重複防止
- 最もシンプルで確実な方法
- 追加の副作用なし

## 🚀 デプロイ手順

```bash
cd /Users/tsujitakehiro/Desktop/ios_KanjyApp/KANJY
git push origin main
```

Netlifyが自動デプロイ（約1-2分）

```bash
# Xcodeで再ビルド
Cmd + Shift + K (クリーンビルド)
Cmd + B (ビルド)
```

## ✅ 期待されるログ

```
✅ 回答フォームボタンが見つかりました
✅ イベントリスナー設定完了（touchend + click with flag protection）
📱 ボタンがタップされました（touchend）
🔄 回答フォームへの遷移を開始
✅ ナビゲーションフラグをONにしました
- currentEventId: f2697d56-...
- 遷移先URL: response-form.html?id=...
🔄 [Navigation]: https://kanjy-web.netlify.app/response-form.html?id=...
✅ [Navigation]: 許可されました
📡 [Navigation]: 読み込み開始
✅ [Navigation]: 読み込み完了 ← エラーなし！
```

もし`click`イベントも発火した場合：

```
🖱️ ボタンがクリックされました（click）
🔄 回答フォームへの遷移を開始
⚠️ すでにナビゲーション中です。重複実行を防止します。 ← フラグで保護！
```

## 🎉 まとめ

- **原因**: タッチイベントとクリックイベントの重複発火
- **解決**: グローバルフラグによる重複実行防止
- **結果**: ナビゲーションが1回だけ実行され、エラー -999 が解消される

---

**作成日**: 2025-12-20  
**対応ファイル**: `KANJY/web-frontend/index.html`


