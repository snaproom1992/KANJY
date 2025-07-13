# KANJY デザインシステム

## 🎨 カラーパレット

```css
:root {
  /* Primary Colors */
  --primary: #007AFF;      /* iOS Blue */
  --success: #28a745;      /* Green */
  --warning: #ffc107;      /* Yellow */
  --danger: #dc3545;       /* Red */
  
  /* Neutral Colors */
  --background: #f5f5f5;   /* Light Gray */
  --surface: #ffffff;      /* White */
  --card-bg: #f8f9fa;      /* Card Background */
  --text-primary: #333333; /* Dark Gray */
  --text-secondary: #6c757d; /* Medium Gray */
  --border: #e9ecef;       /* Light Border */
}
```

## 📐 スペーシング

```css
/* 8pt Grid System */
--spacing-xs: 4px;   /* 0.25rem */
--spacing-sm: 8px;   /* 0.5rem */
--spacing-md: 16px;  /* 1rem */
--spacing-lg: 24px;  /* 1.5rem */
--spacing-xl: 32px;  /* 2rem */
```

## 🔤 タイポグラフィ

```css
/* Font Stack */
font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;

/* Font Sizes */
--font-xs: 0.75rem;    /* 12px */
--font-sm: 0.875rem;   /* 14px */
--font-base: 1rem;     /* 16px */
--font-lg: 1.125rem;   /* 18px */
--font-xl: 1.25rem;    /* 20px */
--font-2xl: 1.5rem;    /* 24px */

/* Font Weights */
--font-light: 300;
--font-normal: 400;
--font-medium: 500;
--font-semibold: 600;
--font-bold: 700;
```

## 🎭 エフェクト

```css
/* Border Radius */
--radius-sm: 4px;
--radius-md: 8px;
--radius-lg: 12px;
--radius-xl: 16px;

/* Shadows */
--shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.05);
--shadow-md: 0 4px 6px rgba(0, 0, 0, 0.1);
--shadow-lg: 0 8px 16px rgba(0, 0, 0, 0.15);

/* Transitions */
--transition-fast: all 0.15s ease;
--transition-normal: all 0.2s ease;
--transition-slow: all 0.3s ease;
```

## 🧩 コンポーネントパターン

### ボタン

```css
.btn-primary {
  background: var(--primary);
  color: white;
  padding: var(--spacing-sm) var(--spacing-md);
  border-radius: var(--radius-md);
  font-weight: var(--font-semibold);
  border: none;
  cursor: pointer;
  transition: var(--transition-normal);
}

.btn-primary:hover {
  background: #0056d6;
  box-shadow: var(--shadow-md);
}
```

### カード

```css
.card {
  background: var(--surface);
  border-radius: var(--radius-lg);
  padding: var(--spacing-lg);
  box-shadow: var(--shadow-md);
  border: 1px solid var(--border);
}
```

### フォーム

```css
.form-input {
  width: 100%;
  padding: var(--spacing-sm) var(--spacing-md);
  border: 2px solid var(--border);
  border-radius: var(--radius-md);
  font-size: var(--font-base);
  transition: var(--transition-normal);
}

.form-input:focus {
  border-color: var(--primary);
  outline: none;
  box-shadow: 0 0 0 3px rgba(0, 122, 255, 0.1);
}
```

## 📱 レスポンシブ

```css
/* Breakpoints */
--breakpoint-sm: 640px;
--breakpoint-md: 768px;
--breakpoint-lg: 1024px;
--breakpoint-xl: 1280px;
```

## 🎯 AIプロンプト用テンプレート

### 新しいコンポーネント作成時：

```
KANJYデザインシステムに従って[コンポーネント名]を作成してください：

必須スタイル:
- カラー: CSS変数を使用 (var(--primary), var(--success)等)
- フォント: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto
- スペーシング: var(--spacing-*)を使用
- 角丸: var(--radius-md) = 8px
- シャドウ: var(--shadow-md)
- アニメーション: var(--transition-normal)

要件:
- iOS風クリーンデザイン
- レスポンシブ対応
- アクセシビリティ配慮
``` 