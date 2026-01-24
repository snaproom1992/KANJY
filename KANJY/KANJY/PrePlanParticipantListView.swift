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

            // 集金状況サマリー（プログレスバー付き）
            let collectedCount = viewModel.participants.filter { $0.hasCollected }.count
            let totalCount = viewModel.participants.count
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("集金状況")
                            .font(DesignSystem.Typography.emphasizedSubheadline)
                            .foregroundColor(DesignSystem.Colors.black)
                        
                        HStack(spacing: 4) {
                            Text("\(collectedCount)")
                                .font(DesignSystem.Typography.title3)
                                .fontWeight(.bold)
                                .foregroundColor(collectedCount == totalCount && totalCount > 0 ? DesignSystem.Colors.success : DesignSystem.Colors.primary)
                            Text("/ \(totalCount)人")
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.secondary)
                            Text("集金済み")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.secondary)
                                .padding(.leading, 2)
                        }
                    }
                    
                    Spacer()
                    
                    if collectedCount == totalCount && totalCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("完了")
                        }
                        .font(.system(size: DesignSystem.Icon.Size.medium, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.success)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(DesignSystem.Colors.success.opacity(0.1))
                        .cornerRadius(DesignSystem.Card.cornerRadiusSmall)
                    }
                }
                
            
                // プログレスバー
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(DesignSystem.Colors.gray2)
                            .frame(height: 12)
                        
                        // 進捗
                        if totalCount > 0 {
                            let progress = Double(collectedCount) / Double(totalCount)
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: collectedCount == totalCount
                                            ? [DesignSystem.Colors.success, DesignSystem.Colors.success.opacity(0.8)]
                                            : [DesignSystem.Colors.primary, DesignSystem.Colors.primary.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * CGFloat(progress), height: 12)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                        }
                    }
                }
                .frame(height: 12)
                
                Divider()
                    .padding(.vertical, 4)
                
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
            
            // 参加者リスト（集金チェック用）
            VStack(spacing: DesignSystem.Spacing.sm) {
                if viewModel.participants.isEmpty {
                    Text("参加者がまだいません")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.secondary)
                        .padding(.vertical, DesignSystem.Spacing.xl)
                } else {
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
                
                // ➕ 手動で参加者を追加ボタン（リストの直下に配置）
                Button(action: {
                    showingAddParticipant = true
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
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
                            .background(DesignSystem.Colors.primary.opacity(0.05))
                    )
                }
                
                // テキストコピー機能（参加者追加ボタンの下に配置）
                Button(action: {
                    copyPaymentText()
                }) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: DesignSystem.Icon.Size.medium))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("名前と金額の一覧をコピー")
                                .font(DesignSystem.Typography.body)
                                .fontWeight(.medium)
                            
                            // 実際の参加者名を表示
                            let exampleText: String = {
                                if viewModel.participants.isEmpty {
                                    return "佐藤 ¥5,000 / 田中 ¥3,000..."
                                } else {
                                    let names = viewModel.participants.prefix(2).map { p in
                                        let amount = p.hasFixedAmount ? p.fixedAmount : viewModel.paymentAmount(for: p)
                                        return "\(p.name) ¥\(viewModel.formatAmount(String(amount)))"
                                    }
                                    return names.joined(separator: " / ") + (viewModel.participants.count > 2 ? "..." : "")
                                }
                            }()
                            
                            Text(exampleText)
                                .font(DesignSystem.Typography.caption2)
                                .lineLimit(1)
                                .opacity(0.8)
                        }
                        
                        Spacer()
                    }
                    .foregroundColor(DesignSystem.Colors.primary)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(DesignSystem.Colors.primary.opacity(0.3), lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(DesignSystem.Colors.white)
                            )
                    )
                }
            }
            
            Divider()
                .padding(.vertical, DesignSystem.Spacing.sm)

            // アクションボタンエリア
            VStack(spacing: DesignSystem.Spacing.md) {
                // 集金案内作成ボタン（リッチなデザインで最下部に）
                Button(action: {
                    showPaymentGenerator = true
                }) {
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "list.bullet.rectangle.portrait")
                                .font(.system(size: 24))
                            Text("集金案内を作成")
                                .font(DesignSystem.Typography.headline)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .opacity(0.6)
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    .background(
                        LinearGradient(
                            colors: [DesignSystem.Colors.primary, DesignSystem.Colors.primary.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(
                        color: DesignSystem.Colors.primary.opacity(0.4),
                        radius: 10,
                        x: 0,
                        y: 4
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }
    
    // 支払額一覧をテキストでコピー
    private func copyPaymentText() {
        let title = "【\(viewModel.editingPlanName.isEmpty ? "飲み会" : viewModel.editingPlanName)】お支払い内訳\n"
        let details = viewModel.participants.map { p in
            let amount = p.hasFixedAmount 
                ? p.fixedAmount 
                : viewModel.paymentAmount(for: p)
            return "- \(p.name): ¥\(viewModel.formatAmount(String(amount)))"
        }.joined(separator: "\n")
        
        let total = "\n合計: ¥\(viewModel.formatAmount(viewModel.totalAmount))"
        
        let textToCopy = title + details + total
        UIPasteboard.general.string = textToCopy
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
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
