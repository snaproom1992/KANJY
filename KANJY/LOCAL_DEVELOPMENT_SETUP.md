# ローカル開発環境のセットアップ

## 問題の背景

Xcodeシミュレーターは**Vercelにデプロイされているファイル**（`https://kanjy.vercel.app`）を読み込んでいますが、私たちが修正したのはローカルファイルです。そのため、最新の修正が反映されていませんでした。

## 解決策: ローカルHTTPサーバーを使用

ローカルHTTPサーバーを起動し、Xcodeアプリからローカルファイルを参照することで、即座に修正を反映してテストできます。

## セットアップ手順

### 1. ローカルHTTPサーバーを起動（✅ 完了）

すでにローカルサーバーが起動されています：

```bash
cd /Users/tsujitakehiro/Desktop/ios_KanjyApp/KANJY/KANJY/web-frontend
python3 -m http.server 8080
```

**サーバーURL**: `http://localhost:8080`

**確認方法**:
- ブラウザで `http://localhost:8080` を開く
- `index.html` が表示されれば成功

### 2. Swiftコードを変更（✅ 完了）

`AttendanceManagement.swift` の `generateWebUrl` 関数を変更：

```swift
private func generateWebUrl(eventId: UUID? = nil) -> String {
    // ローカル開発用URL（デバッグ用）
    let baseUrl = "http://localhost:8080/?id="
    let uniqueId = eventId?.uuidString.lowercased() ?? UUID().uuidString.lowercased()
    return baseUrl + uniqueId
}
```

**変更内容**:
- ❌ 本番: `https://kanjy.vercel.app/?id=`
- ✅ ローカル: `http://localhost:8080/?id=`

### 3. Xcodeでビルド＆実行

```bash
Cmd + R
```

Xcodeアプリは、ローカルHTTPサーバー（`localhost:8080`）から最新のHTML/JSファイルを読み込みます。

### 4. テストフロー

#### A. ナビゲーションのテスト

1. スケジュール調整画面を開く
2. 参加者名をタップ → 編集画面に遷移
   - ✅ 正常に遷移する

#### B. キャッシュ更新のテスト

1. 編集画面で回答内容を変更
2. 「回答を更新」ボタンをクリック
3. 2秒後にトップページに戻る
4. **期待される動作**: 更新内容が即座に反映される

#### C. 期待されるXcodeコンソールログ

**編集画面への遷移**:
```
🎯 参加者名がタップ/クリックされました！
✏️ editResponse関数が呼び出されました！
🔄 [Navigation]: http://localhost:8080/response-form.html?id=xxx&edit=yyy
✅ [Navigation]: 許可されたドメイン内の遷移を許可
✅ [Navigation]: 読み込み完了
```

**編集後にトップに戻る**:
```
📢 通知表示: { title: "回答を更新しました！", message: "...", type: "success" }
🔙 goBack関数が呼び出されました
🚀 遷移先URL: http://localhost:8080/index.html?id=xxx&t=1735862400000&reload=true
   - 強制再読み込み: 有効
🚀 [JS]: WKWebViewにnavigateToUrlメッセージを送信します

🔄 [Navigation]: http://localhost:8080/index.html?id=xxx&t=1735862400000&reload=true
✅ [Navigation]: 許可されたドメイン内の遷移を許可
🔄 [Navigation]: キャッシュバスティングを検出
   - タイムスタンプ: あり
   - 再読み込みフラグ: あり
   - アクション: キャッシュを無視して再読み込み
🔄 [Navigation]: キャッシュを無視して再読み込み開始
✅ [Navigation]: 読み込み完了
```

**結果**: 更新した内容がリロードなしで即座に反映される ✅

---

## サーバーの管理

### サーバーを停止する

ターミナルで `Ctrl + C` を押すか、プロセスを終了：

```bash
# プロセスIDを確認
lsof -i :8080

# プロセスを終了
kill <PID>
```

### サーバーを再起動する

```bash
cd /Users/tsujitakehiro/Desktop/ios_KanjyApp/KANJY/KANJY/web-frontend
python3 -m http.server 8080
```

---

## 本番環境に戻す方法

テストが完了したら、Swiftコードを本番URLに戻してください：

### AttendanceManagement.swift

```swift
private func generateWebUrl(eventId: UUID? = nil) -> String {
    // Vercelにデプロイされた本番環境のURL
    let baseUrl = "https://kanjy.vercel.app/?id="
    let uniqueId = eventId?.uuidString.lowercased() ?? UUID().uuidString.lowercased()
    return baseUrl + uniqueId
}

public func getWebUrl(for event: ScheduleEvent) -> String {
    // 古いNetlifyのURLが保存されている場合は無視して、常に最新のVercel URLを生成
    if let webUrl = event.webUrl, webUrl.contains("kanjy-web.netlify.app") {
        return generateWebUrl(eventId: event.id)
    }
    // webUrlがVercelのURLの場合はそれを使用、それ以外は新しく生成
    if let webUrl = event.webUrl, webUrl.contains("kanjy.vercel.app") {
        return webUrl
    }
    return generateWebUrl(eventId: event.id)
}
```

---

## トラブルシューティング

### 問題: `localhost` に接続できない

**エラー**:
```
⚠️ [Navigation]: 外部リンクのため拒否
   - Host: localhost
```

**解決策**: `ScheduleWebView.swift` の `allowedHosts` に `localhost` が含まれているか確認

```swift
let allowedHosts = [
    "kanjy-web.netlify.app",
    "kanjy.vercel.app",
    "kanjy-dzxo9jpk7-snaprooms-projects.vercel.app",
    "localhost",          // ✅ 必要
    "127.0.0.1"           // ✅ 必要
]
```

### 問題: ポート 8080 が既に使用中

**エラー**:
```
OSError: [Errno 48] Address already in use
```

**解決策**: 別のポートを使用

```bash
python3 -m http.server 8888
```

そして、Swiftコードも変更：
```swift
let baseUrl = "http://localhost:8888/?id="
```

### 問題: ファイルが更新されない

**原因**: ブラウザやWKWebViewのキャッシュ

**解決策**:
1. アプリを完全に終了（Xcodeで停止）
2. Xcodeで再ビルド（`Cmd + R`）
3. キャッシュバスティングパラメータが正しく機能しているか確認

---

## まとめ

### 現在の設定

- ✅ ローカルHTTPサーバー: `http://localhost:8080`
- ✅ Swiftコード: ローカルホストを参照
- ✅ 最新のHTML/JSファイルが即座に反映される

### 次のステップ

1. **Xcodeで再ビルド**（`Cmd + R`）
2. **編集フローをテスト**（参加者名タップ → 編集 → 更新 → トップに戻る）
3. **更新内容が即座に反映されるか確認**

### テスト完了後

- ✅ Swiftコードを本番URL（`https://kanjy.vercel.app`）に戻す
- ✅ web-frontendファイルをVercelにデプロイ
- ✅ ローカルサーバーを停止

---

## 追加情報

### web-frontendファイルの場所

```
/Users/tsujitakehiro/Desktop/ios_KanjyApp/KANJY/KANJY/web-frontend/
├── index.html
├── response-form.html
├── README.md
├── netlify.toml
└── vercel.json
```

### 主な修正箇所

1. **response-form.html**: `goBack()` 関数
   - WKWebViewメッセージハンドラーを使用
   - `t=タイムスタンプ` + `reload=true` パラメータ

2. **ScheduleWebView.swift**: `decidePolicyFor navigationAction`
   - キャッシュバスティングパラメータを検出
   - `.reloadIgnoringLocalAndRemoteCacheData` で強制再読み込み

3. **index.html**: タッチイベントのサポート
   - `touchend` イベントを追加
   - モバイルタップの検出を改善

