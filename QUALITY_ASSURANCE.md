# 品質保証ガイドライン

サービス開始前に実装すべき品質保証の仕組みをまとめています。

## 🎯 今回の問題の振り返り

### 発生した問題
1. **JavaScriptの構文エラー**
   - 重複する関数定義（`showError`, `displayEventUrl`）
   - 余分な`catch`節
   - スコープ問題（`let` vs `var`）

2. **デプロイ・キャッシュ問題**
   - ブラウザキャッシュによる古いコードの実行
   - Netlifyのファイルキャッシュ
   - デプロイ反映の遅延

3. **デバッグの困難さ**
   - エラーメッセージが不明確
   - JavaScriptコンソールログが不足
   - Supabase接続状態の可視性不足

---

## 📋 優先度別の改善策

### 🔴 必須（サービス開始前に実装）

#### 1. ESLint・Prettierの導入
**目的:** コードの構文エラーを自動検出

```bash
# プロジェクトルートで実行
npm init -y
npm install --save-dev eslint prettier eslint-config-prettier
npx eslint --init
```

**設定ファイル:** `.eslintrc.json`
```json
{
  "env": {
    "browser": true,
    "es2021": true
  },
  "extends": ["eslint:recommended", "prettier"],
  "parserOptions": {
    "ecmaVersion": "latest",
    "sourceType": "module"
  },
  "rules": {
    "no-unused-vars": "warn",
    "no-console": "off",
    "no-redeclare": "error"
  }
}
```

#### 2. GitHub Actionsでの自動チェック
**目的:** プッシュ前に構文エラーを検出

**ファイル:** `.github/workflows/quality-check.yml`
```yaml
name: Quality Check

on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      - name: Install dependencies
        run: npm ci
      - name: Run ESLint
        run: npx eslint KANJY/web-frontend/*.html --ext .html
      - name: Check HTML syntax
        run: npx html-validate KANJY/web-frontend/*.html
```

#### 3. Sentryエラートラッキング
**目的:** 本番環境のエラーをリアルタイム監視

**実装:**
```html
<!-- index.htmlの<head>内に追加 -->
<script
  src="https://browser.sentry-cdn.com/7.x/bundle.tracing.min.js"
  crossorigin="anonymous"
></script>
<script>
  Sentry.init({
    dsn: "YOUR_SENTRY_DSN",
    integrations: [new Sentry.BrowserTracing()],
    tracesSampleRate: 1.0,
    environment: "production"
  });
</script>
```

#### 4. エラーバウンダリとフォールバックUI
**目的:** ユーザーにわかりやすいエラー表示

```javascript
// グローバルエラーハンドラー
window.addEventListener('error', function(event) {
  console.error('グローバルエラー:', event.error);
  
  // ユーザーへの表示
  const errorElement = document.getElementById('error-display');
  if (errorElement) {
    errorElement.innerHTML = `
      <div class="error-container">
        <h2>エラーが発生しました</h2>
        <p>申し訳ございません。一時的な問題が発生しています。</p>
        <button onclick="location.reload()">ページを再読み込み</button>
        <a href="mailto:snaproom.info@gmail.com">サポートに連絡</a>
      </div>
    `;
    errorElement.style.display = 'block';
  }
  
  // Sentryに送信
  if (typeof Sentry !== 'undefined') {
    Sentry.captureException(event.error);
  }
});
```

---

### 🟡 推奨（サービス開始後3ヶ月以内）

#### 5. TypeScriptへの移行
**目的:** 型安全性の確保、開発効率向上

**段階的移行:**
1. `index.html` → `index.ts` + ビルドツール（Vite/Webpack）
2. 主要関数に型定義を追加
3. Supabaseクライアントの型安全化

**例:**
```typescript
interface ScheduleEvent {
  id: string;
  title: string;
  description: string | null;
  candidate_dates: string[];
  location: string;
  budget: number | null;
  deadline: string | null;
  web_url: string;
}

async function loadEvent(eventId: string): Promise<ScheduleEvent> {
  const { data, error } = await supabase
    .from('events')
    .select('*')
    .eq('id', eventId)
    .single();
  
  if (error) throw new Error(`イベント取得エラー: ${error.message}`);
  return data;
}
```

#### 6. E2Eテストの導入
**目的:** ユーザーフローの自動テスト

**Playwrightの例:**
```javascript
// tests/event-display.spec.js
const { test, expect } = require('@playwright/test');

test('イベント情報が正しく表示される', async ({ page }) => {
  await page.goto('https://kanjy-web.netlify.app/?id=test-event-id');
  
  // タイトルが表示されるまで待機
  await page.waitForSelector('h1');
  
  // タイトルを確認
  const title = await page.textContent('h1');
  expect(title).not.toBe('読み込み中...');
  
  // 場所が表示されることを確認
  await expect(page.locator('text=場所')).toBeVisible();
  
  // 候補日時が表示されることを確認
  await expect(page.locator('text=日程別回答状況')).toBeVisible();
});

test('Supabaseエラー時のフォールバック', async ({ page }) => {
  // ネットワークをオフラインにする
  await page.context().setOffline(true);
  await page.goto('https://kanjy-web.netlify.app/?id=test-event-id');
  
  // エラーメッセージが表示されることを確認
  await expect(page.locator('text=データの読み込みに失敗')).toBeVisible();
});
```

#### 7. ステージング環境の構築
**目的:** 本番前の動作確認

**Netlifyでの実装:**
```bash
# netlify.tomlに追加
[context.staging]
  command = "echo 'Staging build'"
  publish = "KANJY/web-frontend"
  
[context.staging.environment]
  SUPABASE_URL = "https://your-staging-supabase.co"
  NODE_ENV = "staging"
```

---

### 🟢 最適化（時間があれば）

#### 8. キャッシュバスティング戦略
**目的:** ブラウザキャッシュ問題の解決

**ファイル名にハッシュを追加:**
```html
<!-- 自動生成 -->
<script src="main.a3f2b9c.js"></script>
<link rel="stylesheet" href="styles.d4e8f1a.css">
```

**または、メタタグで制御:**
```html
<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="0">
```

#### 9. パフォーマンスモニタリング
**目的:** ページ読み込み速度の監視

```javascript
// Web Vitals
import {getCLS, getFID, getFCP, getLCP, getTTFB} from 'web-vitals';

function sendToAnalytics(metric) {
  console.log(metric);
  // Google Analyticsなどに送信
}

getCLS(sendToAnalytics);
getFID(sendToAnalytics);
getFCP(sendToAnalytics);
getLCP(sendToAnalytics);
getTTFB(sendToAnalytics);
```

#### 10. 自動デプロイワークフロー
**目的:** デプロイの効率化と安全性向上

```yaml
# .github/workflows/deploy.yml
name: Deploy to Netlify

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Lint check
        run: npx eslint KANJY/web-frontend/*.html
      - name: Deploy to Netlify
        uses: netlify/actions/cli@master
        with:
          args: deploy --prod --dir=KANJY/web-frontend
        env:
          NETLIFY_AUTH_TOKEN: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          NETLIFY_SITE_ID: ${{ secrets.NETLIFY_SITE_ID }}
```

---

## 📝 チェックリスト

### サービス開始前
- [ ] ESLint・Prettierの導入と設定
- [ ] GitHub ActionsでCI/CDパイプライン構築
- [ ] Sentryエラートラッキング導入
- [ ] エラーハンドリングの改善
- [ ] ユーザー向けエラーページの作成
- [ ] ステージング環境での動作確認
- [ ] 主要フローのE2Eテスト作成
- [ ] キャッシュ戦略の実装

### サービス開始後
- [ ] ユーザーからのエラーレポート監視
- [ ] パフォーマンスメトリクスの収集
- [ ] TypeScriptへの段階的移行
- [ ] テストカバレッジの向上
- [ ] ドキュメントの充実

---

## 🔧 すぐに始められる改善

1. **今すぐできること（5分）**
   ```bash
   # package.jsonを作成
   npm init -y
   
   # ESLintをインストール
   npm install --save-dev eslint
   npx eslint --init
   ```

2. **今日中にできること（1時間）**
   - エラーハンドリングの改善
   - ユーザー向けエラーメッセージの作成
   - ローカルテストの実施

3. **今週中にできること（1日）**
   - GitHub Actionsの設定
   - Sentryアカウント作成と導入
   - E2Eテストの基本的な実装

---

## 📚 参考リンク

- [ESLint公式ドキュメント](https://eslint.org/)
- [Sentry公式ドキュメント](https://docs.sentry.io/)
- [Playwright公式ドキュメント](https://playwright.dev/)
- [Netlify Deploy Previews](https://docs.netlify.com/site-deploys/deploy-previews/)
- [Web Vitals](https://web.dev/vitals/)

---

## 💡 今回の教訓

1. **構文エラーは事前に防げる**
   - リンターを導入すれば、重複関数や構文エラーはコミット前に検出できる

2. **デバッグ情報は十分に**
   - コンソールログは本番環境でも重要
   - エラーメッセージは具体的に

3. **キャッシュ戦略は重要**
   - ブラウザキャッシュ、CDNキャッシュ、ビルドキャッシュを考慮
   - バージョニングやハッシュを活用

4. **ステージング環境は必須**
   - 本番デプロイ前に必ず動作確認
   - プレビューデプロイを活用

---

作成日: 2025-12-20
最終更新: 2025-12-20


