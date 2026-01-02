# WKWebView ナビゲーション再発問題の修正

## 問題の概要

Xcodeシミュレーターで、スケジュール調整画面（index.html）で参加者名をタップしても、編集画面（response-form.html）に遷移しない問題が再発しました。

## 根本原因

### 問題のメカニズム

1. **ユーザーが参加者名をタップ**
   - JavaScript: `editResponse()` が呼ばれる
   - JavaScript: `window.webkit.messageHandlers.navigateToUrl.postMessage()`でSwiftにメッセージ送信

2. **Swiftでナビゲーション開始**
   - Swift: `navigateToUrl` メッセージハンドラーで `window.location.href` を設定
   - WKWebView: `decidePolicyFor navigationAction` が呼ばれる
   - Swift: ナビゲーションを `.allow` で許可

3. **SwiftUIのビュー更新が発生**
   - SwiftUI: `updateUIView` が自動的に呼ばれる
   - 問題: `uiView.url != url && currentUrl == nil` の条件が true になる
     - `uiView.url`: response-form.html（遷移先）
     - `url`: index.html（初期URL）
     - `currentUrl`: nil（更新されていない）
   - 結果: 強制的に `index.html` に戻される

4. **ナビゲーションがキャンセル**
   - `response-form.html` へのナビゲーションが中断される
   - エラー: `NSURLErrorDomain error -999`（キャンセル）

### 問題の本質

**`updateUIView` メソッドが、JavaScriptによる動的なナビゲーションを認識せず、常に初期URLに強制的に戻してしまう**

## 修正内容

### 1. `decidePolicyFor navigationAction` の改善

JavaScript経由のナビゲーション（`.other`タイプ）を検出し、`currentUrl` を更新することで、`updateUIView` での強制再読み込みを防ぐ：

```swift
// JavaScript経由のナビゲーション（.other）の場合、currentUrlを更新して
// updateUIViewでの強制再読み込みを防ぐ
if navigationAction.navigationType == .other && url != parent.url {
    print("🔄 [Navigation]: JavaScript経由の遷移を検出、currentUrlを更新")
    DispatchQueue.main.async {
        self.parent.currentUrl = url
    }
}
```

### 2. `didFinish navigation` でのcurrentUrl更新

ナビゲーション完了後、`currentUrl` を実際のWebViewのURLに同期させる：

```swift
func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    DispatchQueue.main.async {
        self.parent.isLoading = false
        
        // ナビゲーション完了後、currentUrlを実際のWebViewのURLに更新
        // これにより、updateUIViewでの不要な再読み込みを防ぐ
        if let webViewUrl = webView.url {
            print("✅ [Navigation]: 読み込み完了 - \(webViewUrl.absoluteString)")
            self.parent.currentUrl = webViewUrl
            print("🔄 [Navigation]: currentUrlを更新: \(webViewUrl.absoluteString)")
        }
    }
}
```

### 3. `updateUIView` のロジック改善

初回読み込みのみ実行し、その後のナビゲーションは全て `decidePolicyFor` に委譲：

```swift
func updateUIView(_ uiView: WKWebView, context: Context) {
    // 初回読み込みのみ実行（WebViewがまだ何も読み込んでいない場合）
    // その後のナビゲーションは全てdecidePolicyForで処理される
    // updateUIViewでの強制再読み込みはJavaScript経由のナビゲーションを妨げるため行わない
    if uiView.url == nil {
        var request = URLRequest(url: url)
        // キャッシュポリシーを設定（ローカルキャッシュのみ無視）
        request.cachePolicy = .reloadIgnoringLocalCacheData
        print("🔄 [WebView]: 初回読み込みを実行します")
        print("   - URL: \(url.absoluteString)")
        print("   - キャッシュポリシー: reloadIgnoringLocalCacheData")
        uiView.load(request)
    }
    
    // 戻るボタンが押された場合
    if shouldGoBack {
        context.coordinator.goBack()
    }
}
```

**変更点**:
- ❌ 旧: `if uiView.url != url && currentUrl == nil { ... }`
- ✅ 新: `if uiView.url == nil { ... }`

**理由**:
- 初回読み込み（`uiView.url == nil`）以外では、再読み込みを実行しない
- ナビゲーションは全て `decidePolicyFor` で制御される
- JavaScript経由の動的なナビゲーションが妨げられなくなる

### 4. エラーハンドリングの改善

エラーコード -999（キャンセル）を明示的に処理：

```swift
func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    DispatchQueue.main.async {
        self.parent.isLoading = false
    }
    
    // エラーコード -999 は「キャンセル」を意味し、通常は別のナビゲーションが開始された時に発生
    // これは正常な動作なので、特別な処理は不要
    let nsError = error as NSError
    if nsError.code == NSURLErrorCancelled {
        print("ℹ️ [Navigation]: ナビゲーションがキャンセルされました（別のページに遷移中）")
    } else {
        print("❌ [Navigation]: 暫定的な読み込みに失敗 - \(error.localizedDescription)")
    }
}
```

### 5. JavaScript側の改善（index.html）

タッチイベントのサポートを追加し、モバイルデバイスでのタップ検出を改善：

```javascript
// イベントハンドラー関数（タッチとクリックで共通）
const handleInteraction = function(event) {
    console.log('🎯 参加者名がタップ/クリックされました！');
    console.log('📱 イベントタイプ:', event.type);
    
    const responseId = this.getAttribute('data-response-id');
    
    // イベント伝播を停止（重複実行を防ぐ）
    event.preventDefault();
    event.stopPropagation();
    event.stopImmediatePropagation();
    
    // 編集画面に遷移
    editResponse(responseId);
};

// タッチイベント（モバイル優先）
nameContainer.addEventListener('touchend', handleInteraction, { capture: true, passive: false });

// クリックイベント（デスクトップ用）
nameContainer.addEventListener('click', handleInteraction, { capture: true });
```

## 修正ファイル

1. **ScheduleWebView.swift**
   - `decidePolicyFor navigationAction`: JavaScript経由のナビゲーション検出とcurrentUrl更新
   - `didFinish navigation`: ナビゲーション完了時のcurrentUrl同期
   - `updateUIView`: 初回読み込みのみ実行するように変更
   - `didFailProvisionalNavigation`: エラーコード -999 の明示的な処理

2. **index.html**
   - タッチイベント（`touchend`）のサポート追加
   - イベントハンドラーの統合
   - デバッグログの強化

## テスト方法

### 1. Xcodeでビルド＆実行

```bash
Cmd + R
```

### 2. 参加者名をタップ

スケジュール調整画面で任意の参加者名をタップ

### 3. 期待される動作

**Xcodeコンソールログ**:
```
🎯 参加者名がタップ/クリックされました！
📱 イベントタイプ: touchend
✏️ editResponse関数が呼び出されました！
🚀 [Swift]: JavaScriptからのページ遷移リクエスト: response-form.html
🔄 [Navigation]: https://kanjy.vercel.app/response-form.html?...
🔀 [Navigation]: その他（JavaScriptなど）
✅ [Navigation]: 許可されたドメイン内の遷移を許可
🔄 [Navigation]: JavaScript経由の遷移を検出、currentUrlを更新
📡 [Navigation]: 読み込み開始
✅ [Navigation]: 読み込み完了 - https://kanjy.vercel.app/response-form.html
🔄 [Navigation]: currentUrlを更新: https://kanjy.vercel.app/response-form.html
```

**結果**: 編集画面（response-form.html）に正常に遷移

## 技術的な学び

### SwiftUIとUIKitの統合における注意点

1. **`updateUIView` は頻繁に呼ばれる**
   - SwiftUIのビュー更新のたびに実行される
   - 不必要な再読み込みを避けるため、条件を慎重に設定する必要がある

2. **状態管理の重要性**
   - `@State var currentUrl` を使って、JavaScript経由のナビゲーションを追跡
   - `decidePolicyFor` → `didFinish` で状態を同期させる

3. **ナビゲーションデリゲートパターン**
   - 初回読み込み: `updateUIView` で実行
   - その後のナビゲーション: `decidePolicyFor` で制御
   - 明確に役割を分離することで、競合を防ぐ

### WKWebViewのナビゲーション管理

1. **ナビゲーションタイプ**
   - `.other`: JavaScript経由のナビゲーション（`window.location.href` など）
   - `.linkActivated`: ユーザーがリンクをクリック
   - `.backForward`: 戻る/進むボタン

2. **エラーコード**
   - `-999 (NSURLErrorCancelled)`: ナビゲーションがキャンセルされた
     - 原因: 別のナビゲーションが開始された、強制的な再読み込みなど
     - 対処: 正常な動作の一部として扱う

## まとめ

- **根本原因**: `updateUIView` の過度な再読み込みによるナビゲーションのキャンセル
- **解決策**: 初回読み込みのみ `updateUIView` で実行し、その後は `decidePolicyFor` に委譲
- **副次的改善**: タッチイベントのサポート、エラーハンドリングの改善、デバッグログの強化
- **結果**: JavaScript経由のナビゲーションが正常に動作するようになった

## 関連ドキュメント

- [WKWEBVIEW_NAVIGATION_FIX.md](./WKWEBVIEW_NAVIGATION_FIX.md) - 初回の修正
- [WKWEBVIEW_NETLIFY_FIX.md](./WKWEBVIEW_NETLIFY_FIX.md) - Netlifyドメインの許可
- [EDIT_RESPONSE_FIX.md](./EDIT_RESPONSE_FIX.md) - 編集機能の改善
- [CACHE_REFRESH_FIX.md](./CACHE_REFRESH_FIX.md) - キャッシュ更新の改善

