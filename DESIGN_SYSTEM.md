# KANJY デザインシステム

> 最終更新: 2025年1月

---

## 🎨 カラーパレット

### プライマリカラー

- **Primary**: `#3366CF` (RGB: 51, 102, 207)
  - アプリのメインカラー
  - ボタン、リンク、アクセントに使用

### グレースケール

KANJYでは、システムのグレースケールを活用しています。用途に応じて適切なグレーを選択してください。

| 色名 | システムカラー | 用途 | 使用例 |
|------|--------------|------|--------|
| **Gray1** | `systemGray6` | 最も薄い（背景用） | カードの背景、セクション区切り |
| **Gray2** | `systemGray5` | 薄い（背景用） | セカンダリ背景、非アクティブ状態 |
| **Gray3** | `systemGray4` | 中程度（ボーダー用） | ボーダー、区切り線 |
| **Gray4** | `systemGray3` | 濃いめ（テキスト用） | セカンダリテキスト、アイコン |
| **Gray5** | `systemGray2` | より濃い（テキスト用） | 強調が必要なセカンダリテキスト |
| **Gray6** | `systemGray` | 最も濃い（テキスト用） | メインのセカンダリテキスト |

#### グレーの使用ガイドライン

**背景として使用する場合:**
- カードやセクションの背景: `Gray1` または `Gray2`
- 非アクティブな要素の背景: `Gray2`

**ボーダー・区切り線として使用する場合:**
- カードのボーダー: `Gray3`
- セクション区切り: `Gray3`

**テキストとして使用する場合:**
- セカンダリテキスト（説明文など）: `Gray4` または `secondary`
- 非アクティブなテキスト: `Gray4`
- プレースホルダー: `Gray4`

**アイコンとして使用する場合:**
- 非アクティブなアイコン: `Gray4`
- セカンダリアイコン: `Gray4`

### セマンティックカラー

- **Success**: `Color.green` - 成功状態、完了状態
- **Warning**: `Color.orange` - 警告、注意が必要な状態
- **Alert**: `Color.red` - エラー、削除、重要な警告
- **Info**: `Color.blue` - 情報表示

### システムカラー

- **Background**: `systemBackground` - メイン背景
- **Secondary Background**: `secondarySystemGroupedBackground` - カード背景
- **Grouped Background**: `systemGroupedBackground` - グループ化された背景

---

## 📝 タイポグラフィ

### フォントサイズ

| スタイル | サイズ | 用途 |
|---------|--------|------|
| `largeTitle` | 34pt | 画面タイトル |
| `title1` | 28pt | 大きな見出し |
| `title2` | 22pt | 中見出し |
| `title3` | 20pt | 小見出し |
| `headline` | 17pt (semibold) | セクションヘッダー |
| `body` | 17pt | 本文 |
| `subheadline` | 15pt | サブテキスト |
| `footnote` | 13pt | 注釈 |
| `caption` | 12pt | キャプション |
| `caption2` | 10pt | 小さなキャプション |

### フォントウェイト

- `regular` - 通常のテキスト
- `medium` - やや強調
- `semibold` - 見出し、強調
- `bold` - 強い強調

### 使用例

```swift
// 見出し
Text("飲み会名")
    .font(DesignSystem.Typography.headline)

// 本文
Text("説明文")
    .font(DesignSystem.Typography.body)

// セカンダリテキスト
Text("補足情報")
    .font(DesignSystem.Typography.caption)
    .foregroundColor(DesignSystem.Colors.secondary)
```

---

## 📏 スペーシング

基本単位: **4px**

| 名前 | サイズ | 用途 |
|------|--------|------|
| `xs` | 4px | 最小の間隔 |
| `sm` | 8px | 小さな間隔 |
| `md` | 12px | 中程度の間隔 |
| `lg` | 16px | 大きな間隔 |
| `xl` | 20px | より大きな間隔 |
| `xxl` | 24px | セクション間隔 |
| `xxxl` | 32px | 大きなセクション間隔 |

### 使用例

```swift
VStack(spacing: DesignSystem.Spacing.lg) {
    // コンテンツ
}
.padding(DesignSystem.Spacing.md)
```

---

## 🔘 ボタン

### サイズ

- `small`: 32pt
- `medium`: 44pt（推奨）
- `large`: 56pt

### パディング

- 水平: 16pt
- 垂直: 12pt
- 大きなボタン: 24pt × 16pt

### スタイル

- **Primary**: `.borderedProminent` - 主要なアクション
- **Secondary**: `.bordered` - セカンダリアクション
- **Plain**: `.plain` - テキストリンク風

---

## 🃏 カード

### 角丸

- `cornerRadius`: 14pt（標準）
- `cornerRadiusLarge`: 16pt
- `cornerRadiusSmall`: 10pt

### パディング

- `small`: 12pt
- `medium`: 16pt（標準）
- `large`: 20pt

### シャドウ

**標準:**
- 半径: 4pt
- 不透明度: 0.03
- オフセット: (0, 1)

**大きい:**
- 半径: 8pt
- 不透明度: 0.05
- オフセット: (0, 2)

### 使用例

```swift
VStack {
    // コンテンツ
}
.padding(DesignSystem.Card.Padding.medium)
.background(Color(.systemBackground))
.cornerRadius(DesignSystem.Card.cornerRadius)
.shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
```

---

## 🎯 アイコン

### サイズ

- `small`: 12pt
- `medium`: 16pt
- `large`: 20pt
- `xlarge`: 24pt
- `xxlarge`: 32pt

### 使用例

```swift
Image(systemName: "calendar")
    .font(.system(size: DesignSystem.Icon.Size.medium))
    .foregroundColor(DesignSystem.Colors.primary)
```

---

## 📊 進捗バー

- 高さ: 3pt
- 角丸: 2pt
- インジケーターサイズ: 20pt
- パディング: (8, 12, 8, 12)

---

## 📝 テキストフィールド

### 高さ

- `small`: 44pt
- `medium`: 52pt（標準）
- `large`: 64pt

### スタイル

- 角丸: 12pt
- ボーダー幅: 1pt
- ボーダー色: `Gray3`
- フォーカス時のボーダー色: `Primary`

### 使用例

```swift
TextField("プレースホルダー", text: $text)
    .font(DesignSystem.Typography.body)
    .padding(DesignSystem.TextField.Padding.horizontal)
    .frame(height: DesignSystem.TextField.Height.medium)
    .background(
        RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius)
            .fill(DesignSystem.TextField.backgroundColor)
    )
    .overlay(
        RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius)
            .stroke(DesignSystem.TextField.borderColor, lineWidth: 1)
    )
```

---

## 🎨 デザイン原則

### 1. シンプルさ

- 必要な情報だけを表示
- 装飾を最小限に
- 視覚的な階層を明確に

### 2. 一貫性

- 同じ要素は同じスタイルを使用
- スペーシングは基本単位（4px）の倍数で統一
- カラーは定義されたパレットから選択

### 3. 視覚的階層

- 重要な情報は大きく、太く
- セカンダリ情報は小さく、薄く
- スペーシングでグループ化

### 4. アクセシビリティ

- コントラスト比を確保
- タップ領域は最小44pt × 44pt
- テキストサイズは読みやすく

---

## 📚 実装例

### カードコンポーネント

```swift
VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
    // ヘッダー
    HStack {
        Image(systemName: "calendar")
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(DesignSystem.Colors.primary)
        Text("候補日時")
            .font(DesignSystem.Typography.headline)
    }
    
    // コンテンツ
    // ...
}
.padding(DesignSystem.Spacing.lg)
.background(Color(.systemBackground))
.cornerRadius(DesignSystem.Card.cornerRadius)
.shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
```

### ボタンコンポーネント

```swift
Button(action: {}) {
    Text("保存")
        .font(DesignSystem.Typography.headline)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Button.Padding.vertical)
        .background(DesignSystem.Colors.primary)
        .cornerRadius(DesignSystem.Card.cornerRadiusSmall)
}
```

---

## 🔗 関連ドキュメント

- [README.md](./README.md) - プロジェクト概要
- [CONCEPT.md](./CONCEPT.md) - プロダクトコンセプト
- [DesignSystem.swift](./KANJY/DesignSystem.swift) - コード実装

---

**Keep it simple. Keep it consistent. Keep it focused. 🎨**



