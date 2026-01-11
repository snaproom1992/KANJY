# 🔐 GitHub認証ガイド

## 方法1: Personal Access Tokenを使う（最も簡単・推奨）

### ステップ1: Personal Access Tokenを作成

1. **GitHubにログイン**
   - https://github.com にアクセス
   - ログインしてください

2. **Personal Access Tokenを作成**
   - 右上のプロフィール画像をクリック
   - **Settings** をクリック
   - 左メニューの一番下 **Developer settings** をクリック
   - **Personal access tokens** → **Tokens (classic)** をクリック
   - **Generate new token** → **Generate new token (classic)** をクリック

3. **トークンの設定**
   - **Note**: `KANJY App Development` など、分かりやすい名前を入力
   - **Expiration**: お好みで設定（90日、1年など）
   - **Select scopes**: 以下の権限にチェック
     - ✅ `repo` (全てのリポジトリへのアクセス)
   - **Generate token** をクリック

4. **トークンをコピー**
   - ⚠️ **重要**: この画面を閉じると二度と見れません！
   - 表示されたトークン（`ghp_` で始まる文字列）をコピーして安全な場所に保存

### ステップ2: トークンを使ってプッシュ

ターミナルで以下を実行：

```bash
cd /Users/tsujitakehiro/Desktop/ios_KanjyApp/KANJY
git push origin main
```

**ユーザー名を聞かれたら：**
- `snaproom1992` を入力（Enter）

**パスワードを聞かれたら：**
- ⚠️ **GitHubのパスワードではなく、先ほどコピーしたPersonal Access Tokenを貼り付け**
- Enterを押す

これでプッシュが成功します！

---

## 方法2: GitHub CLIを使う（将来的に便利）

### ステップ1: GitHub CLIをインストール

```bash
brew install gh
```

### ステップ2: 認証

```bash
gh auth login
```

以下の質問に答えてください：
- **What account do you want to log into?** → `GitHub.com`
- **What is your preferred protocol for Git operations?** → `HTTPS`
- **Authenticate Git with your GitHub credentials?** → `Yes`
- **How would you like to authenticate GitHub CLI?** → `Login with a web browser`
- 表示されたコードをコピーして、ブラウザで開く
- GitHubで認証を完了

### ステップ3: プッシュ

```bash
cd /Users/tsujitakehiro/Desktop/ios_KanjyApp/KANJY
git push origin main
```

---

## 方法3: Xcodeからプッシュ（GUIが好きな方）

1. **Xcodeでプロジェクトを開く**
   - `/Users/tsujitakehiro/Desktop/ios_KanjyApp/KANJY/KANJY.xcodeproj` を開く

2. **Source Controlメニュー**
   - メニューバーから **Source Control** → **Push...** をクリック
   - または、左サイドバーの **Source Control** タブから **Push** をクリック

3. **認証**
   - 初回はGitHubの認証情報を求められる場合があります
   - Personal Access Tokenを使う場合は、パスワード欄にトークンを入力

---

## 🔍 トラブルシューティング

### エラー: "could not read Username"

**解決策1: リモートURLを確認**
```bash
cd /Users/tsujitakehiro/Desktop/ios_KanjyApp/KANJY
git remote -v
```

HTTPSのURL（`https://github.com/...`）になっていることを確認

**解決策2: キーチェーンから古い認証情報を削除**
1. **キーチェーンアクセス** アプリを開く
2. 検索欄に `github.com` と入力
3. 見つかった認証情報を削除
4. 再度 `git push` を試す

### エラー: "Authentication failed"

- Personal Access Tokenが正しくコピーされているか確認
- トークンの有効期限が切れていないか確認
- `repo` スコープが選択されているか確認

---

## ✅ 推奨方法

**初めての方**: **方法1（Personal Access Token）** が最も簡単です！

1. GitHubでトークンを作成（5分）
2. ターミナルで `git push origin main`
3. ユーザー名: `snaproom1992`
4. パスワード: **トークンを貼り付け**

これで完了です！🚀


