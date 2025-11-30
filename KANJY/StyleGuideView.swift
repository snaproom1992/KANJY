import SwiftUI

struct StyleGuideView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xxl) {
                    // カラーパレット
                    ColorPaletteSection()
                    
                    // タイポグラフィ
                    TypographySection()
                    
                    // スペーシング
                    SpacingSection()
                    
                    // ボタン
                    ButtonSection()
                    
                    // カード
                    CardSection()
                    
                    // アイコン
                    IconSection()
                    
                    // テキストフィールド
                    TextFieldSection()
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .navigationTitle("スタイルガイド")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - カラーパレットセクション
struct ColorPaletteSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("カラーパレット")
                .font(DesignSystem.Typography.title2)
                .padding(.bottom, DesignSystem.Spacing.sm)
            
            // プライマリカラー
            ColorRow(name: "Primary", color: DesignSystem.Colors.primary, hex: "#3366CF")
            
            // グレースケール
            ColorRow(name: "Gray1 (systemGray6)", color: DesignSystem.Colors.gray1, description: "最も薄い（背景用）")
            ColorRow(name: "Gray2 (systemGray5)", color: DesignSystem.Colors.gray2, description: "薄い（背景用）")
            ColorRow(name: "Gray3 (systemGray4)", color: DesignSystem.Colors.gray3, description: "中程度（ボーダー用）")
            ColorRow(name: "Gray4 (systemGray3)", color: DesignSystem.Colors.gray4, description: "濃いめ（テキスト用）")
            ColorRow(name: "Gray5 (systemGray2)", color: DesignSystem.Colors.gray5, description: "より濃い（テキスト用）")
            ColorRow(name: "Gray6 (systemGray)", color: DesignSystem.Colors.gray6, description: "最も濃い（テキスト用）")
            
            // セマンティックカラー
            ColorRow(name: "Success", color: DesignSystem.Colors.success)
            ColorRow(name: "Warning", color: DesignSystem.Colors.warning)
            ColorRow(name: "Alert", color: DesignSystem.Colors.alert)
            ColorRow(name: "Info", color: DesignSystem.Colors.info)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.Card.cornerRadius)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct ColorRow: View {
    let name: String
    let color: Color
    var hex: String? = nil
    var description: String? = nil
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 60, height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(name)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.black)
                
                if let hex = hex {
                    Text(hex)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondary)
                }
                
                if let description = description {
                    Text(description)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

// MARK: - タイポグラフィセクション
struct TypographySection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("タイポグラフィ")
                .font(DesignSystem.Typography.title2)
                .padding(.bottom, DesignSystem.Spacing.sm)
            
            TypographyRow(name: "Large Title", font: DesignSystem.Typography.largeTitle, size: "34pt")
            TypographyRow(name: "Title 1", font: DesignSystem.Typography.title1, size: "28pt")
            TypographyRow(name: "Title 2", font: DesignSystem.Typography.title2, size: "22pt")
            TypographyRow(name: "Title 3", font: DesignSystem.Typography.title3, size: "20pt")
            TypographyRow(name: "Headline", font: DesignSystem.Typography.headline, size: "17pt (semibold)")
            TypographyRow(name: "Body", font: DesignSystem.Typography.body, size: "17pt")
            TypographyRow(name: "Subheadline", font: DesignSystem.Typography.subheadline, size: "15pt")
            TypographyRow(name: "Footnote", font: DesignSystem.Typography.footnote, size: "13pt")
            TypographyRow(name: "Caption", font: DesignSystem.Typography.caption, size: "12pt")
            TypographyRow(name: "Caption 2", font: DesignSystem.Typography.caption2, size: "10pt")
        }
        .padding(DesignSystem.Spacing.lg)
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.Card.cornerRadius)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct TypographyRow: View {
    let name: String
    let font: Font
    let size: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(name)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.secondary)
            
            Text("The quick brown fox jumps over the lazy dog")
                .font(font)
                .foregroundColor(DesignSystem.Colors.black)
            
            Text(size)
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(DesignSystem.Colors.secondary)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

// MARK: - スペーシングセクション
struct SpacingSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("スペーシング")
                .font(DesignSystem.Typography.title2)
                .padding(.bottom, DesignSystem.Spacing.sm)
            
            SpacingRow(name: "XS", size: DesignSystem.Spacing.xs, description: "4px")
            SpacingRow(name: "SM", size: DesignSystem.Spacing.sm, description: "8px")
            SpacingRow(name: "MD", size: DesignSystem.Spacing.md, description: "12px")
            SpacingRow(name: "LG", size: DesignSystem.Spacing.lg, description: "16px")
            SpacingRow(name: "XL", size: DesignSystem.Spacing.xl, description: "20px")
            SpacingRow(name: "XXL", size: DesignSystem.Spacing.xxl, description: "24px")
            SpacingRow(name: "XXXL", size: DesignSystem.Spacing.xxxl, description: "32px")
        }
        .padding(DesignSystem.Spacing.lg)
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.Card.cornerRadius)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct SpacingRow: View {
    let name: String
    let size: CGFloat
    let description: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Text(name)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.black)
                .frame(width: 60, alignment: .leading)
            
            HStack(spacing: 0) {
                Rectangle()
                    .fill(DesignSystem.Colors.primary)
                    .frame(width: size, height: 20)
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(4)
            
            Text(description)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.secondary)
            
            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

// MARK: - ボタンセクション
struct ButtonSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("ボタン")
                .font(DesignSystem.Typography.title2)
                .padding(.bottom, DesignSystem.Spacing.sm)
            
            // Primary Button
            Button(action: {}) {
                Text("Primary Button")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(DesignSystem.Button.Padding.vertical)
                    .background(DesignSystem.Colors.primary)
                    .cornerRadius(DesignSystem.Card.cornerRadiusSmall)
            }
            
            // Secondary Button
            Button(action: {}) {
                Text("Secondary Button")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(DesignSystem.Button.Padding.vertical)
                    .background(DesignSystem.Colors.primary.opacity(0.1))
                    .cornerRadius(DesignSystem.Card.cornerRadiusSmall)
            }
            
            // Plain Button
            Button(action: {}) {
                Text("Plain Button")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.primary)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.Card.cornerRadius)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - カードセクション
struct CardSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("カード")
                .font(DesignSystem.Typography.title2)
                .padding(.bottom, DesignSystem.Spacing.sm)
            
            // 標準カード
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("標準カード")
                    .font(DesignSystem.Typography.headline)
                Text("これは標準のカードスタイルです。角丸14pt、パディング16pt。")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.secondary)
            }
            .padding(DesignSystem.Card.Padding.medium)
            .background(Color(.systemBackground))
            .cornerRadius(DesignSystem.Card.cornerRadius)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            
            // 小さいカード
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("小さいカード")
                    .font(DesignSystem.Typography.subheadline)
                Text("角丸10pt")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondary)
            }
            .padding(DesignSystem.Card.Padding.small)
            .background(Color(.systemBackground))
            .cornerRadius(DesignSystem.Card.cornerRadiusSmall)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.Card.cornerRadius)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - アイコンセクション
struct IconSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("アイコン")
                .font(DesignSystem.Typography.title2)
                .padding(.bottom, DesignSystem.Spacing.sm)
            
            HStack(spacing: DesignSystem.Spacing.lg) {
                IconRow(size: DesignSystem.Icon.Size.small, name: "Small (12pt)")
                IconRow(size: DesignSystem.Icon.Size.medium, name: "Medium (16pt)")
                IconRow(size: DesignSystem.Icon.Size.large, name: "Large (20pt)")
                IconRow(size: DesignSystem.Icon.Size.xlarge, name: "XLarge (24pt)")
                IconRow(size: DesignSystem.Icon.Size.xxlarge, name: "XXLarge (32pt)")
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.Card.cornerRadius)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct IconRow: View {
    let size: CGFloat
    let name: String
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "star.fill")
                .font(.system(size: size))
                .foregroundColor(DesignSystem.Colors.primary)
            
            Text(name)
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(DesignSystem.Colors.secondary)
        }
    }
}

// MARK: - テキストフィールドセクション
struct TextFieldSection: View {
    @State private var text1 = ""
    @State private var text2 = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("テキストフィールド")
                .font(DesignSystem.Typography.title2)
                .padding(.bottom, DesignSystem.Spacing.sm)
            
            // 標準テキストフィールド
            TextField("標準テキストフィールド", text: $text1)
                .font(DesignSystem.Typography.body)
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
            
            // 大きなテキストフィールド
            TextField("大きなテキストフィールド", text: $text2)
                .font(DesignSystem.Typography.title1)
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
        .padding(DesignSystem.Spacing.lg)
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.Card.cornerRadius)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    StyleGuideView()
}

