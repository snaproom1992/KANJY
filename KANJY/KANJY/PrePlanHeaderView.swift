import SwiftUI

struct PrePlanHeaderView: View {
    @ObservedObject var viewModel: PrePlanViewModel
    @Binding var localPlanName: String
    @Binding var showIconPicker: Bool
    
    // Internal state for editing title
    @State private var isEditingTitle: Bool = false
    @FocusState private var isTitleFocused: Bool
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            EmojiButton()
            PlanNameView()
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
    }
    
    // アイコンボタン
    @ViewBuilder
    private func EmojiButton() -> some View {
        Button(action: {
            showIconPicker = true
        }) {
            Group {
                if let iconName = viewModel.selectedIcon {
                    Image(systemName: iconName)
                        .font(.system(size: 40))
                        .foregroundColor(colorFromString(viewModel.selectedIconColor) ?? DesignSystem.Colors.primary)
                } else if viewModel.selectedEmoji.isEmpty || viewModel.selectedEmoji == "KANJY_HIPPO" {
                    // 空またはレガシーデータ → AppLogo表示
                    if let appLogo = UIImage(named: "AppLogo") {
                        Image(uiImage: appLogo)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                    } else {
                        // フォールバック
                        Image(systemName: "wineglass.fill")
                            .font(.system(size: 32))
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                } else {
                    Text(viewModel.selectedEmoji)
                        .font(.system(size: 40))
                }
            }
            .frame(width: 70, height: 70)
            .background(
                Circle()
                    .fill(Color.gray.opacity(0.1))
            )
        }
    }
    
    // 飲み会名ビュー
    @ViewBuilder
    private func PlanNameView() -> some View {
        if isEditingTitle {
            TextField("飲み会名を入力", text: $localPlanName)
                .font(DesignSystem.Typography.title1)
                .foregroundColor(DesignSystem.Colors.black)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(DesignSystem.TextField.Padding.horizontal)
                .frame(height: DesignSystem.TextField.Height.large)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                        .fill(DesignSystem.TextField.backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                        .stroke(isTitleFocused ? DesignSystem.TextField.focusedBorderColor : DesignSystem.TextField.borderColor, lineWidth: DesignSystem.TextField.borderWidth)
                )
                .focused($isTitleFocused)
                .onSubmit { isEditingTitle = false }
                .onChange(of: isTitleFocused) { _, focused in
                    if !focused { isEditingTitle = false }
                }
        } else {
            PlanNameDisplayView()
        }
    }
    
    // 飲み会名表示ビュー（編集モードでない場合）
    @ViewBuilder
    private func PlanNameDisplayView() -> some View {
        Group {
            if localPlanName.isEmpty {
                Text("飲み会名")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(Color(UIColor.placeholderText))
                .italic()
            } else {
                Text(localPlanName)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .onTapGesture {
            isEditingTitle = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTitleFocused = true
            }
        }
    }
    
    // Helper functionality
    private func colorFromString(_ colorString: String?) -> Color? {
        guard let colorString = colorString, !colorString.isEmpty else { return nil }
        let components = colorString.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard components.count == 3 else { return nil }
        return Color(red: components[0], green: components[1], blue: components[2])
    }
}
