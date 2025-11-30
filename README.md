# KANJY（幹事）

<div align="center">

🍻 **飲み会の幹事さんのための集金管理アプリ** 🍻

[![iOS](https://img.shields.io/badge/iOS-16.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-4.0-green.svg)](https://developer.apple.com/xcode/swiftui/)

</div>

---

## 📱 アプリ概要

**KANJY**は、飲み会の幹事が直面する「集金の面倒くささ」を解決するiOSアプリです。

### 🎯 解決する課題

- 💰 **役職に応じた金額計算が面倒**
- 👥 **誰が払ったか分からなくなる**
- 📅 **日程調整と集金が別々で管理が大変**
- 💸 **細かい端数の計算がややこしい**

---

## 🎨 アプリのコンセプト

### 🍻 「飲み会」に特化したニッチ戦略

KANJYは**飲み会の幹事業務に特化**することで、汎用的なイベント管理アプリとの差別化を図ります。

#### なぜ「飲み会」特化なのか？

1. **明確なターゲット**
   - 若手社員〜中堅社員（20代〜40代）
   - 会社の飲み会幹事を任されることが多い層
   - 明確な悩みとニーズがある

2. **飲み会ならではの機能**
   - 役職による金額の傾斜（部長は多め、新人は少なめ）
   - 二次会の管理
   - お酒を飲む/飲まない区別
   - 居酒屋予約情報の管理

3. **親しみやすさ**
   - 「飲み会」というカジュアルな言葉
   - 気軽に使ってもらえる入口
   - 競合との明確な差別化

4. **将来性**
   - ニッチで始めて徐々に広げる戦略
   - 「飲み会といえばKANJY」のポジション確立
   - 自然な口コミ拡散（「BBQにも使える」）

---

## ✨ 主要機能

### 💰 集金管理

- **役職に応じた金額計算**
  - 部長×2.0、課長×1.5、一般×1.0、新人×0.5
  - カスタム役職の作成可能
  - 固定金額の設定も可能

- **集金状況の可視化**
  - 誰が払ったか一目で確認
  - プログレスバーで進捗表示
  - 未払い人数の自動集計

- **内訳項目の管理**
  - 会場費、食事代などを分けて管理
  - 合計金額の自動計算
  - 項目ごとの編集・削除

### 📅 スケジュール調整

- **候補日程の共有**
  - 複数の候補日時を設定
  - WebURLで簡単共有
  - 参加者はブラウザから回答

- **出欠管理**
  - 参加/微妙/不参加/未回答
  - リアルタイムで集計
  - 最適な日時を自動提案

- **Supabase連携**
  - クラウドでデータ同期
  - Web フロントエンド（Netlify）
  - アプリとWebのシームレス連携

### 📊 便利機能

- **保存と再利用**
  - 飲み会情報を保存
  - 途中から再開可能
  - 過去の飲み会を参照

- **絵文字アイコン**
  - 飲み会ごとに絵文字設定
  - 32種類の飲み会関連絵文字
  - 視覚的に識別しやすい

- **カレンダー表示**
  - 月間カレンダーで一覧
  - 日付から飲み会を確認
  - 予定の把握が簡単

---

## 🛣️ 開発ロードマップ

### Phase 1: コア機能の完成（現在）

- ✅ 集金計算機能
- ✅ 参加者管理
- ✅ 役職設定
- ✅ スケジュール調整
- 🔄 ホーム画面のUI/UX改善

### Phase 2: 飲み会特化機能の追加

- [ ] 二次会の管理
- [ ] お酒を飲む/飲まない設定
- [ ] 居酒屋予約情報の保存
- [ ] 飲み会テンプレート
- [ ] 割り勘計算の最適化

### Phase 3: UX向上と自動化

- [ ] 領収書スキャン（OCR）
- [ ] 常連メンバー管理
- [ ] 支払い催促機能
- [ ] 飲み会の思い出記録
- [ ] 統計・分析機能

### Phase 4: ソーシャル機能

- [ ] 飲み会の共有
- [ ] グループ機能
- [ ] コミュニティ形成

---

## 🏗️ 技術スタック

### フロントエンド（iOS）

- **言語**: Swift 5.9
- **フレームワーク**: SwiftUI 4.0
- **最小バージョン**: iOS 16.0+
- **開発環境**: Xcode 15+

### バックエンド

- **BaaS**: Supabase
  - PostgreSQL データベース
  - リアルタイム同期
  - Row Level Security

### Web フロントエンド

- **ホスティング**: Netlify
- **技術**: Vanilla HTML/CSS/JavaScript
- **スタイリング**: Tailwind CSS (CDN)
- **URL**: https://kanjy-web.netlify.app/

### アーキテクチャ

```
┌─────────────┐
│  iOS App    │ ← SwiftUI
│  (KANJY)    │
└──────┬──────┘
       │
       ├─── Supabase (PostgreSQL)
       │     ├─ events テーブル
       │     └─ responses テーブル
       │
       └─── Netlify (Web Frontend)
             ├─ index.html (閲覧)
             └─ response-form.html (回答)
```

---

## 🎨 デザインシステム

詳細なデザインシステムについては、[DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md)を参照してください。

### カラーパレット

- **プライマリ**: `#3366CF` (青)
- **グレースケール**: システムグレー（Gray1〜Gray6）を使用
- **成功**: Green
- **警告**: Orange
- **エラー**: Red

### デザイン原則

1. **シンプル**: 必要な情報だけを表示
2. **視覚的**: 進捗を図で表現
3. **親しみやすさ**: 堅苦しくない UI
4. **実用性**: 集金状況を最優先

---

## 📁 プロジェクト構造

```
KANJY/
├── KANJY/
│   ├── TopView.swift                 # ホーム画面
│   ├── PrePlanView.swift            # 飲み会編集画面
│   ├── PrePlanViewModel.swift       # データ管理
│   ├── AttendanceManagement.swift   # スケジュール調整
│   ├── ScheduleManagementView.swift # スケジュール一覧
│   ├── DesignSystem.swift           # デザインシステム
│   ├── SupabaseManager.swift        # Supabase連携
│   ├── SupabaseConfig.swift         # Supabase設定
│   └── web-frontend/                # Webフロントエンド
│       ├── index.html
│       ├── response-form.html
│       └── netlify.toml
├── KANJYTests/
├── KANJYUITests/
└── README.md
```

---

## 🚀 セットアップ

### 必要な環境

- macOS 13.0+
- Xcode 15.0+
- iOS 16.0+ デバイス or シミュレーター

### Supabase設定

1. Supabaseプロジェクトを作成
2. `SupabaseConfig.swift` に認証情報を設定

```swift
struct SupabaseConfig {
    static let url = "YOUR_SUPABASE_URL"
    static let anonKey = "YOUR_ANON_KEY"
}
```

3. テーブルを作成（スキーマは別途ドキュメント参照）

### ビルドと実行

```bash
# リポジトリをクローン
git clone [repository-url]

# Xcodeでプロジェクトを開く
open KANJY.xcodeproj

# ビルドして実行（⌘ + R）
```

---

## 📊 データモデル

### Plan（飲み会）

```swift
struct Plan {
    let id: UUID
    var name: String              // 飲み会名
    var date: Date                // 開催日
    var emoji: String?            // 絵文字
    var description: String?      // 説明
    var location: String?         // 場所
    var participants: [Participant] // 参加者
    var totalAmount: String       // 合計金額
    var roleMultipliers: [String: Double] // 役職倍率
    var amountItems: [AmountItem]? // 内訳
    var scheduleEventId: UUID?    // スケジュール調整ID
}
```

### ScheduleEvent（スケジュール調整）

```swift
struct ScheduleEvent {
    let id: UUID
    var title: String             // タイトル
    var candidateDates: [Date]    // 候補日時
    var responses: [ScheduleResponse] // 回答
    var deadline: Date?           // 回答期限
    var webUrl: String?          // Web URL
}
```

---

## 🎯 開発の指針

### やるべきこと ✅

1. **飲み会特化の機能を優先**
   - 汎用的な機能より飲み会ならではの機能
   - ユーザーの「あるある」に応える

2. **シンプルさを保つ**
   - 機能は多いより使いやすい
   - 複雑さより直感性

3. **集金管理を最優先**
   - アプリの核心価値
   - 常に見やすく、分かりやすく

### やらないこと ❌

1. **汎用イベント管理アプリ化しない**
   - 飲み会以外は「ついで」
   - メインターゲットをぼやけさせない

2. **複雑な会計機能は追加しない**
   - 本格的な会計ソフトは目指さない
   - あくまで「幹事の負担を減らす」ツール

3. **SNS化しない**
   - コミュニティ機能は慎重に
   - プライバシーを最優先

---

## 🤝 貢献

このプロジェクトは現在個人開発ですが、将来的にはコントリビューションを受け付ける予定です。

---

## 📄 ライセンス

[ライセンス情報を記載]

---

## 📞 お問い合わせ

- Email: snaproom.info@gmail.com
- GitHub Issues: [Issues](github-url/issues)

---

<div align="center">

**飲み会の幹事、もう怖くない。KANJY** 🍻

Made with ❤️ by [Your Name]

</div>
