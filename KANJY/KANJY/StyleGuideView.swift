import SwiftUI

struct StyleGuideView: View {
    var body: some View {
        NavigationStack {
            List {
                // カラーパレット
                Section("カラーパレット") {
                    ColorRow(title: "Primary", color: DesignSystem.Colors.primary)
                    ColorRow(title: "Success", color: DesignSystem.Colors.success)
                    ColorRow(title: "Warning", color: DesignSystem.Colors.warning)
                    ColorRow(title: "Alert", color: DesignSystem.Colors.alert)
                    ColorRow(title: "Secondary", color: DesignSystem.Colors.secondary)
                }
                
                // タイポグラフィ
                Section("タイポグラフィ") {
                    VStack(alignment: .leading, spacing: 12) {
                        TypographyRow(title: "Large Title", font: DesignSystem.Typography.largeTitle, size: "34pt")
                        TypographyRow(title: "Title 1", font: DesignSystem.Typography.title1, size: "28pt")
                        TypographyRow(title: "Title 2", font: DesignSystem.Typography.title2, size: "22pt")
                        TypographyRow(title: "Title 3", font: DesignSystem.Typography.title3, size: "20pt")
                        TypographyRow(title: "Headline", font: DesignSystem.Typography.headline, size: "17pt")
                        TypographyRow(title: "Body", font: DesignSystem.Typography.body, size: "17pt")
                        TypographyRow(title: "Subheadline", font: DesignSystem.Typography.subheadline, size: "15pt")
                        TypographyRow(title: "Footnote", font: DesignSystem.Typography.footnote, size: "13pt")
                        TypographyRow(title: "Caption", font: DesignSystem.Typography.caption, size: "12pt")
                        TypographyRow(title: "Caption 2", font: DesignSystem.Typography.caption2, size: "10pt")
                    }
                    .padding(.vertical, 8)
                }
                
                // スペーシング
                Section("スペーシング") {
                    SpacingRow(title: "XS", spacing: DesignSystem.Spacing.xs, value: "4px")
                    SpacingRow(title: "SM", spacing: DesignSystem.Spacing.sm, value: "8px")
                    SpacingRow(title: "MD", spacing: DesignSystem.Spacing.md, value: "12px")
                    SpacingRow(title: "LG", spacing: DesignSystem.Spacing.lg, value: "16px")
                    SpacingRow(title: "XL", spacing: DesignSystem.Spacing.xl, value: "20px")
                    SpacingRow(title: "XXL", spacing: DesignSystem.Spacing.xxl, value: "24px")
                    SpacingRow(title: "XXXL", spacing: DesignSystem.Spacing.xxxl, value: "32px")
                }
                
                // アイコンサイズ
                Section("アイコンサイズ") {
                    IconRow(title: "Small", size: DesignSystem.Icon.Size.small, value: "12pt")
                    IconRow(title: "Medium", size: DesignSystem.Icon.Size.medium, value: "16pt")
                    IconRow(title: "Large", size: DesignSystem.Icon.Size.large, value: "20pt")
                    IconRow(title: "XLarge", size: DesignSystem.Icon.Size.xlarge, value: "24pt")
                    IconRow(title: "XXLarge", size: DesignSystem.Icon.Size.xxlarge, value: "32pt")
                }
                
                // カード
                Section("カード") {
                    VStack(spacing: 16) {
                        VStack {
                            Text("サンプルカード")
                                .font(DesignSystem.Typography.headline)
                            Text("これはカードのサンプルです")
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.secondary)
                        }
                        .padding(DesignSystem.Card.Padding.medium)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadius, style: .continuous)
                                .fill(DesignSystem.Colors.secondaryBackground)
                                .shadow(
                                    color: Color.black.opacity(DesignSystem.Card.Shadow.opacity),
                                    radius: DesignSystem.Card.Shadow.radius,
                                    x: DesignSystem.Card.Shadow.offset.width,
                                    y: DesignSystem.Card.Shadow.offset.height
                                )
                        )
                        
                        HStack {
                            Text("角丸:")
                            Spacer()
                            Text("\(Int(DesignSystem.Card.cornerRadius))pt")
                                .foregroundColor(DesignSystem.Colors.secondary)
                        }
                        .font(DesignSystem.Typography.caption)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("スタイルガイド")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// カラー表示用
struct ColorRow: View {
    let title: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(DesignSystem.Typography.body)
            Spacer()
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 60, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

// タイポグラフィ表示用
struct TypographyRow: View {
    let title: String
    let font: Font
    let size: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondary)
                Spacer()
                Text(size)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(DesignSystem.Colors.secondary)
            }
            Text("サンプルテキスト Aa")
                .font(font)
        }
    }
}

// スペーシング表示用
struct SpacingRow: View {
    let title: String
    let spacing: CGFloat
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(DesignSystem.Typography.body)
            Rectangle()
                .fill(DesignSystem.Colors.primary)
                .frame(width: spacing, height: 20)
            Text(value)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.secondary)
            Spacer()
        }
    }
}

// アイコンサイズ表示用
struct IconRow: View {
    let title: String
    let size: CGFloat
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(DesignSystem.Typography.body)
            Spacer()
            Image(systemName: "star.fill")
                .font(.system(size: size))
                .foregroundColor(DesignSystem.Colors.primary)
            Text(value)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.secondary)
        }
    }
}

#Preview {
    StyleGuideView()
}
