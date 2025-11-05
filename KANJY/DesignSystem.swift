import SwiftUI

// MARK: - スタイルガイドライン

struct DesignSystem {
    // MARK: - カラーパレット
    
    struct Colors {
        // 基本色
        static let white = Color.white
        static let black = Color.black
        
        // グレースケール
        static let gray1 = Color(.systemGray6)      // 最も薄い（背景用）
        static let gray2 = Color(.systemGray5)      // 薄い（背景用）
        static let gray3 = Color(.systemGray4)      // 中程度（ボーダー用）
        static let gray4 = Color(.systemGray3)      // 濃いめ（テキスト用）
        static let gray5 = Color(.systemGray2)      // より濃い（テキスト用）
        static let gray6 = Color(.systemGray)        // 最も濃い（テキスト用）
        static let secondary = Color.secondary      // セカンダリテキスト
        
        // メインカラー（アプリのプライマリカラー）
        static let primary = Color(red: 0.2, green: 0.37, blue: 0.81)  // #3366CF
        
        // サブカラー（アクセント用）
        static let accent = Color.accentColor
        
        // アラート色
        static let alert = Color.red
        static let success = Color.green
        static let warning = Color.orange
        static let info = Color.blue
        
        // セマンティックカラー
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemGroupedBackground)
        static let groupedBackground = Color(.systemGroupedBackground)
    }
    
    // MARK: - タイポグラフィ
    
    struct Typography {
        // フォントサイズ
        struct FontSize {
            static let caption2: CGFloat = 10
            static let caption: CGFloat = 12
            static let footnote: CGFloat = 13
            static let subheadline: CGFloat = 15
            static let body: CGFloat = 17
            static let headline: CGFloat = 17
            static let title3: CGFloat = 20
            static let title2: CGFloat = 22
            static let title1: CGFloat = 28
            static let largeTitle: CGFloat = 34
        }
        
        // フォントウェイト
        struct FontWeight {
            static let regular = Font.Weight.regular
            static let medium = Font.Weight.medium
            static let semibold = Font.Weight.semibold
            static let bold = Font.Weight.bold
        }
        
        // 定義済みスタイル
        static let largeTitle = Font.system(size: FontSize.largeTitle, weight: .bold)
        static let title1 = Font.system(size: FontSize.title1, weight: .bold)
        static let title2 = Font.system(size: FontSize.title2, weight: .semibold)
        static let title3 = Font.system(size: FontSize.title3, weight: .semibold)
        static let headline = Font.system(size: FontSize.headline, weight: .semibold)
        static let body = Font.system(size: FontSize.body, weight: .regular)
        static let subheadline = Font.system(size: FontSize.subheadline, weight: .regular)
        static let footnote = Font.system(size: FontSize.footnote, weight: .regular)
        static let caption = Font.system(size: FontSize.caption, weight: .regular)
        static let caption2 = Font.system(size: FontSize.caption2, weight: .regular)
        
        // 強調用
        static let emphasizedTitle = Font.system(size: FontSize.title3, weight: .bold)
        static let emphasizedBody = Font.system(size: FontSize.body, weight: .semibold)
        static let emphasizedSubheadline = Font.system(size: FontSize.subheadline, weight: .semibold)
    }
    
    // MARK: - スペーシング
    
    struct Spacing {
        // 基本単位: 4px
        static let xs: CGFloat = 4      // 4px
        static let sm: CGFloat = 8      // 8px
        static let md: CGFloat = 12     // 12px
        static let lg: CGFloat = 16     // 16px
        static let xl: CGFloat = 20     // 20px
        static let xxl: CGFloat = 24    // 24px
        static let xxxl: CGFloat = 32  // 32px
        
        // セクション間隔
        static let section: CGFloat = 20
        static let card: CGFloat = 16
    }
    
    // MARK: - ボタン
    
    struct Button {
        // ボタンサイズ（CGFloat）
        struct Size {
            static let small: CGFloat = 32
            static let medium: CGFloat = 44
            static let large: CGFloat = 56
        }
        
        // コントロールサイズ
        struct Control {
            static let compact: ControlSize = .small
            static let regular: ControlSize = .regular
            static let large: ControlSize = .large
        }
        
        // ボタンパディング
        struct Padding {
            static let horizontal: CGFloat = 16
            static let vertical: CGFloat = 12
            static let largeHorizontal: CGFloat = 24
            static let largeVertical: CGFloat = 16
        }
    }
    
    // MARK: - カード
    
    struct Card {
        // 角丸
        static let cornerRadius: CGFloat = 14
        static let cornerRadiusLarge: CGFloat = 16
        static let cornerRadiusSmall: CGFloat = 10
        
        // パディング
        struct Padding {
            static let small: CGFloat = 12
            static let medium: CGFloat = 16
            static let large: CGFloat = 20
        }
        
        // シャドウ
        struct Shadow {
            static let radius: CGFloat = 4
            static let opacity: Double = 0.03
            static let offset = CGSize(width: 0, height: 1)
            
            static let largeRadius: CGFloat = 8
            static let largeOpacity: Double = 0.05
            static let largeOffset = CGSize(width: 0, height: 2)
        }
        
        // ボーダー
        static let borderWidth: CGFloat = 1
        static let borderOpacity: Double = 0.3
    }
    
    // MARK: - アイコン
    
    struct Icon {
        // サイズ
        struct Size {
            static let small: CGFloat = 12
            static let medium: CGFloat = 16
            static let large: CGFloat = 20
            static let xlarge: CGFloat = 24
            static let xxlarge: CGFloat = 32
        }
    }
    
    // MARK: - 進捗バー
    
    struct ProgressBar {
        static let height: CGFloat = 3
        static let cornerRadius: CGFloat = 2
        static let indicatorSize: CGFloat = 20
        static let indicatorIconSize: CGFloat = 9
        static let padding: EdgeInsets = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        static let spacing: CGFloat = 6
    }
    
    // MARK: - テキストフィールド
    
    struct TextField {
        // 高さ
        struct Height {
            static let small: CGFloat = 44
            static let medium: CGFloat = 52
            static let large: CGFloat = 64
        }
        
        // パディング
        struct Padding {
            static let horizontal: CGFloat = 16
            static let vertical: CGFloat = 12
        }
        
        // 角丸
        static let cornerRadius: CGFloat = 12
        
        // 背景色
        static let backgroundColor = Colors.background
        static let focusedBackgroundColor = Colors.gray1
        
        // ボーダー
        static let borderWidth: CGFloat = 1
        static let borderColor = Colors.gray3
        static let focusedBorderColor = Colors.primary
        
        // フォントサイズ
        struct FontSize {
            static let small: CGFloat = 15
            static let medium: CGFloat = 17
            static let large: CGFloat = 20
            static let title: CGFloat = 28
        }
    }
    
    // MARK: - ヘルパー関数
    
    static func cardBackground() -> some View {
        RoundedRectangle(cornerRadius: Card.cornerRadius, style: .continuous)
            .fill(Colors.secondaryBackground)
            .shadow(
                color: Color.black.opacity(Card.Shadow.opacity),
                radius: Card.Shadow.radius,
                x: Card.Shadow.offset.width,
                y: Card.Shadow.offset.height
            )
    }
    
    static func cardBackgroundLarge() -> some View {
        RoundedRectangle(cornerRadius: Card.cornerRadiusLarge, style: .continuous)
            .fill(Colors.secondaryBackground)
            .shadow(
                color: Color.black.opacity(Card.Shadow.largeOpacity),
                radius: Card.Shadow.largeRadius,
                x: Card.Shadow.largeOffset.width,
                y: Card.Shadow.largeOffset.height
            )
    }
}

// MARK: - ボタンスタイルのヘルパー（ファイルスコープ）

extension View {
    func primaryButtonStyle() -> some View {
        self.buttonStyle(.borderedProminent)
    }
    
    func secondaryButtonStyle() -> some View {
        self.buttonStyle(.bordered)
    }
    
    func plainButtonStyle() -> some View {
        self.buttonStyle(.plain)
    }
    
    func borderlessButtonStyle() -> some View {
        self.buttonStyle(.borderless)
    }
}

// MARK: - テキストフィールドスタイルのヘルパー

extension View {
    // スタンダードテキストフィールド（見やすく、大きなフォント）
    func standardTextFieldStyle() -> some View {
        self
            .font(DesignSystem.Typography.body)
            .foregroundColor(DesignSystem.Colors.black)
            .padding(DesignSystem.TextField.Padding.horizontal)
            .frame(height: DesignSystem.TextField.Height.medium)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                    .fill(DesignSystem.TextField.backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                    .stroke(DesignSystem.TextField.borderColor, lineWidth: DesignSystem.TextField.borderWidth)
            )
    }
    
    // 大きなテキストフィールド（タイトル用）
    func largeTextFieldStyle() -> some View {
        self
            .font(DesignSystem.Typography.title1)
            .foregroundColor(DesignSystem.Colors.black)
            .padding(DesignSystem.TextField.Padding.horizontal)
            .frame(height: DesignSystem.TextField.Height.large)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                    .fill(DesignSystem.TextField.backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                    .stroke(DesignSystem.TextField.borderColor, lineWidth: DesignSystem.TextField.borderWidth)
            )
    }
}

