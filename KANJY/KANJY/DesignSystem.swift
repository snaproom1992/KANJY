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
        static let primary = Color(red: 0.067, green: 0.094, blue: 0.157)  // #111827 (web版kanjy-800と統一)
        
        // サブカラー（アクセント用）
        static let accent = primary  // プライマリカラーと統一
        
        // 🎨 Webフロントエンドに合わせたカラーパレット
        // オレンジのアクセントカラー（maybeカラー）
        static let orangeAccent = Color(red: 0.976, green: 0.451, blue: 0.086)  // #f97316
        static let orangeAccentLight = Color(red: 1.0, green: 0.933, blue: 0.831)  // #ffedd5
        static let orangeAccentDark = Color(red: 0.918, green: 0.345, blue: 0.047)  // #ea580c
        
        // 参加ステータスカラー（Webフロントエンドと統一）
        struct Attendance {
            // 参加（緑）
            static let attending = Color(red: 0.063, green: 0.725, blue: 0.506)  // #10b981
            static let attendingLight = Color(red: 0.925, green: 0.992, blue: 0.961)  // #ecfdf5
            static let attendingDark = Color(red: 0.020, green: 0.588, blue: 0.412)  // #059669
            
            // 微妙（オレンジ）
            static let maybe = orangeAccent
            static let maybeLight = orangeAccentLight
            static let maybeDark = orangeAccentDark
            
            // 不参加（赤）
            static let notAttending = Color(red: 0.937, green: 0.267, blue: 0.267)  // #ef4444
            static let notAttendingLight = Color(red: 0.996, green: 0.949, blue: 0.949)  // #fef2f2
            static let notAttendingDark = Color(red: 0.863, green: 0.149, blue: 0.149)  // #dc2626
            
            // 未回答（グレー）
            static let undecided = Color(red: 0.420, green: 0.451, blue: 0.502)  // #6b7280
            static let undecidedLight = Color(red: 0.976, green: 0.980, blue: 0.984)  // #f9fafb
            static let undecidedDark = Color(red: 0.294, green: 0.333, blue: 0.388)  // #4b5563
        }
        
        // アラート色・セマンティックカラー
        static let alert = Color(red: 0.937, green: 0.267, blue: 0.267)  // #ef4444（赤）
        static let success = Attendance.attending  // 緑
        static let warning = orangeAccent  // オレンジ
        static let info = primary  // 青（プライマリカラーと同じ）
        
        // 基本カラーパレット（直接指定を避けるため）
        static let blue = primary  // 青はプライマリカラーを使用
        static let red = alert  // 赤はアラートカラーを使用
        static let green = success  // 緑は成功カラーを使用
        static let orange = warning  // オレンジは警告カラーを使用
        static let yellow = Color(red: 1.0, green: 0.843, blue: 0.0)  // #FFD700（ゴールド）
        static let purple = Color(red: 0.502, green: 0.0, blue: 0.502)  // #800080（紫）
        static let cyan = Color(red: 0.0, green: 0.737, blue: 0.831)  // #00BCD4（シアン）
        static let pink = Color(red: 1.0, green: 0.412, blue: 0.706)  // #FF69B4（ピンク）
        static let indigo = Color(red: 0.294, green: 0.0, blue: 0.510)  // #4B0082（インディゴ）
        static let teal = Color(red: 0.0, green: 0.502, blue: 0.502)  // #008080（ティール）
        static let mint = Color(red: 0.596, green: 0.984, blue: 0.596)  // #98FB98（ミント）
        static let brown = Color(red: 0.647, green: 0.165, blue: 0.165)  // #A52A2A（ブラウン）
        
        // 透明色
        static let clear = Color.clear
        
        // セマンティックカラー（ライトモード）
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemGroupedBackground)
        static let groupedBackground = Color(.systemGroupedBackground)
        
        // 🌙 ダークモード対応カラー
        struct Dark {
            // 背景色
            static let background = Color(red: 0.102, green: 0.102, blue: 0.102)  // #1a1a1a
            static let secondaryBackground = Color(red: 0.176, green: 0.176, blue: 0.176)  // #2d2d2d
            static let groupedBackground = Color(red: 0.125, green: 0.125, blue: 0.125)  // #202020
            
            // テキスト色
            static let primaryText = Color.white
            static let secondaryText = Color(red: 0.690, green: 0.690, blue: 0.690)  // #b0b0b0
            static let tertiaryText = Color(red: 0.502, green: 0.502, blue: 0.502)  // #808080
            
            // ボーダー色
            static let border = Color(red: 0.251, green: 0.251, blue: 0.251)  // #404040
            static let borderSecondary = Color(red: 0.314, green: 0.314, blue: 0.314)  // #505050
            
            // カード背景
            static let cardBackground = secondaryBackground
            static let cardBackgroundElevated = Color(red: 0.220, green: 0.220, blue: 0.220)  // #383838
        }
        
        // MARK: - 背景色バリエーション（PaymentInfoGenerator用）
        struct BackgroundTints {
            // プライマリカラーの薄い背景
            static let primaryLight = Color(red: 0.95, green: 0.98, blue: 1.0)  // 薄い水色
            static let primaryLightAlt = Color(red: 0.95, green: 0.95, blue: 1.0)  // 薄い青色
            
            // オレンジの薄い背景
            static let orangeLight = Color(red: 1.0, green: 0.98, blue: 0.95)  // 薄いオレンジ
            
            // 赤の薄い背景
            static let redLight = Color(red: 1.0, green: 0.95, blue: 0.95)  // 薄い赤
            
            // 緑の薄い背景
            static let greenLight = Color(red: 0.95, green: 0.98, blue: 0.95)  // 薄い緑
            static let greenLightAlt = Color(red: 0.95, green: 1.0, blue: 0.95)  // 薄い緑（別バリエーション）
            
            // 白の半透明背景
            static let whiteSemiTransparent = Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.7)
        }
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
            .tint(DesignSystem.Colors.primary)
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

// MARK: - UIColor拡張（UIKit用）

import UIKit

extension DesignSystem.Colors {
    // UIColor版のカラー（UIKitで使用）
    static var uiPrimary: UIColor {
        UIColor(red: 0.067, green: 0.094, blue: 0.157, alpha: 1.0)  // #111827 (web版kanjy-800と統一)
    }
    
    static var uiBackground: UIColor {
        UIColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1.0)  // #FAFAFC
    }
    
    static var uiText: UIColor {
        UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)  // #333333
    }
    
    static var uiSecondaryText: UIColor {
        UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)  // #808080
    }
    
    static var uiLightGray: UIColor {
        UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)  // #F2F2F2
    }
    
    static var uiWhite: UIColor {
        UIColor.white
    }
    
    static var uiBlack: UIColor {
        UIColor.black
    }
    
    static var uiGray: UIColor {
        UIColor.gray
    }
    
    static var uiRed: UIColor {
        UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0)  // #E63333
    }
    
    static var uiGreen: UIColor {
        UIColor(red: 0.0, green: 0.5, blue: 0.2, alpha: 1.0)  // #008033
    }
    
    static var uiBlue: UIColor {
        UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)  // #0066CC
    }
    
    static var uiOrange: UIColor {
        UIColor(red: 0.976, green: 0.451, blue: 0.086, alpha: 1.0)  // #f97316
    }
    
    static var uiYellow: UIColor {
        UIColor(red: 0.95, green: 0.7, blue: 0.1, alpha: 1.0)  // #F2B319
    }
    
    // MARK: - 背景色バリエーション（UIKit用）
    static var uiPrimaryLight: UIColor {
        UIColor(red: 0.95, green: 0.98, blue: 1.0, alpha: 0.5)
    }
    
    static var uiPrimaryLightAlt: UIColor {
        UIColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 0.5)
    }
    
    static var uiOrangeLight: UIColor {
        UIColor(red: 1.0, green: 0.98, blue: 0.95, alpha: 0.5)
    }
    
    static var uiRedLight: UIColor {
        UIColor(red: 1.0, green: 0.95, blue: 0.95, alpha: 0.5)
    }
    
    static var uiGreenLight: UIColor {
        UIColor(red: 0.95, green: 0.98, blue: 0.95, alpha: 0.5)
    }
    
    static var uiGreenLightAlt: UIColor {
        UIColor(red: 0.95, green: 1.0, blue: 0.95, alpha: 0.5)
    }
    
    static var uiWhiteSemiTransparent: UIColor {
        UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.7)
    }
}
