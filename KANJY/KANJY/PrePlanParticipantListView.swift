import SwiftUI

struct PrePlanParticipantListView: View {
    @ObservedObject var viewModel: PrePlanViewModel
    let confirmedDate: Date?
    @Binding var editingParticipant: Participant?
    @Binding var showingAddParticipant: Bool
    @Binding var showPaymentGenerator: Bool
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // 開催日未定の警告バナー
            if confirmedDate == nil {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(DesignSystem.Colors.alert)
                    Text("開催日が選択されていません。選択すると参加者が反映されます。")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.alert)
                    Spacer()
                }
                .padding(DesignSystem.Spacing.sm)
                .background(DesignSystem.Colors.alert.opacity(0.1))
                .cornerRadius(DesignSystem.Card.cornerRadiusSmall)
            }

            // 集金状況サマリー
            let collectedCount = viewModel.participants.filter { $0.hasCollected }.count
            let totalCount = viewModel.participants.count
            
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("集金状況")
                        .font(DesignSystem.Typography.emphasizedSubheadline)
                        .foregroundColor(DesignSystem.Colors.black)
                    Text("\(collectedCount)/\(totalCount)人 集金済み")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondary)
                }
                
                Spacer()
                
                if collectedCount == totalCount && totalCount > 0 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: DesignSystem.Icon.Size.xlarge))
                        .foregroundColor(DesignSystem.Colors.success)
                }
            }
            
            // 参加者リスト（集金チェック用）
            VStack(spacing: DesignSystem.Spacing.sm) {
                // インデックスベースでループして表示を確実にする
                ForEach(Array(viewModel.participants.enumerated()), id: \.offset) { index, participant in
                    Button(action: {
                        viewModel.toggleCollectionStatus(for: participant)
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }) {
                        ParticipantRowView(participant: participant, viewModel: viewModel)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(action: {
                            editingParticipant = participant
                        }) {
                            Label("詳細を編集", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive, action: {
                            viewModel.deleteParticipant(participant)
                        }) {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
            }
            
            // 集金案内作成ボタン
            Button(action: {
                showPaymentGenerator = true
            }) {
                HStack {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: DesignSystem.Icon.Size.large, weight: DesignSystem.Typography.FontWeight.medium))
                        .foregroundColor(DesignSystem.Colors.white)
                    Text("集金案内を作成")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.white.opacity(0.8))
                }
                .padding(.vertical, DesignSystem.Button.Padding.vertical)
                .padding(.horizontal, DesignSystem.Button.Padding.horizontal)
                .background(
                    LinearGradient(
                        colors: [DesignSystem.Colors.primary, DesignSystem.Colors.primary.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous))
            }
            .plainButtonStyle()

            // ➕ 手動で参加者を追加ボタン
            Button(action: {
                showingAddParticipant = true
            }) {
                HStack {
                    Image(systemName: "person.fill.badge.plus")
                        .font(.system(size: DesignSystem.Icon.Size.medium))
                    Text("参加者を追加")
                        .font(DesignSystem.Typography.body)
                }
                .foregroundColor(DesignSystem.Colors.primary)
                .padding(DesignSystem.Button.Padding.vertical)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                        .stroke(DesignSystem.Colors.primary, lineWidth: 1)
                )
            }
        }
    }
}

struct ParticipantRowView: View {
    let participant: Participant
    @ObservedObject var viewModel: PrePlanViewModel
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // 参加者名
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(participant.name)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.black)
                
                Text(participant.roleType.name)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondary)
            }
            
            Spacer()
            
            // 金額（固定金額または計算金額）
            VStack(alignment: .trailing, spacing: 0) {
                if participant.hasFixedAmount {
                    Text("¥\(viewModel.formatAmount(String(participant.fixedAmount)))")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.primary)
                } else {
                    Text("¥\(viewModel.formatAmount(String(viewModel.paymentAmount(for: participant))))")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.black)
                }
                
                if participant.source == .webResponse {
                    Text("Web")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.secondary)
                }
            }
            
            // 集金状態（チェックボックス）
            Image(systemName: participant.hasCollected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(participant.hasCollected ? DesignSystem.Colors.success : DesignSystem.Colors.gray4)
                .font(.system(size: 24))
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                .fill(DesignSystem.Colors.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                .stroke(DesignSystem.Colors.gray1, lineWidth: 1)
        )
    }
}
