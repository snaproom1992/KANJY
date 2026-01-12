import SwiftUI

struct PrePlanBasicInfoView: View {
    @ObservedObject var viewModel: PrePlanViewModel
    var onAutoSave: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("飲み会名と絵文字は上部で設定できます")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.secondary)
                .padding(.vertical, DesignSystem.Spacing.sm)
            
            // 説明
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("説明（任意）")
                    .font(DesignSystem.Typography.emphasizedSubheadline)
                    .foregroundColor(DesignSystem.Colors.black)
                TextField("説明を入力", text: $viewModel.editingPlanDescription, axis: .vertical)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.black)
                    .padding(DesignSystem.TextField.Padding.horizontal)
                    .frame(minHeight: DesignSystem.TextField.Height.medium)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                            .fill(DesignSystem.TextField.backgroundColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                            .stroke(DesignSystem.TextField.borderColor, lineWidth: DesignSystem.TextField.borderWidth)
                    )
                    .lineLimit(3...6)
                    .onChange(of: viewModel.editingPlanDescription) {
                        onAutoSave()
                    }
            }
            
            // 場所
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("場所（任意）")
                    .font(DesignSystem.Typography.emphasizedSubheadline)
                    .foregroundColor(DesignSystem.Colors.black)
                TextField("場所を入力", text: $viewModel.editingPlanLocation)
                    .standardTextFieldStyle()
                    .onChange(of: viewModel.editingPlanLocation) {
                        onAutoSave()
                    }
            }
        }
        .padding(DesignSystem.Card.Padding.medium)
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
    }
}


