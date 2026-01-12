import SwiftUI

// PRE-PLAN SCHEDULE COMPONENTS
// These components are used in PrePlanView.swift for the Schedule functionality.

// MARK: - Schedule Display View
struct ScheduleDisplayView: View {
    let event: ScheduleEvent
    @ObservedObject var scheduleViewModel: ScheduleManagementViewModel
    let onShowUrl: () -> Void
    let onEdit: () -> Void
    
    // Optional preview callback (some usages might not have it, but consistent with recent changes)
    var onPreview: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // 候補日時を参加希望数付きで表示
            if !event.candidateDates.isEmpty {
                // 各候補日時の参加希望数を計算
                let voteCounts = calculateVoteCounts(for: event)
                let maxVotes = voteCounts.values.max() ?? 0
                
                VStack(spacing: DesignSystem.Spacing.xs) {
                    ForEach(Array(event.candidateDates.sorted().enumerated()), id: \.element) { index, date in
                        let votes = voteCounts[date] ?? 0
                        let isTopChoice = votes > 0 && votes == maxVotes
                        
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            // 番号バッジ
                            Text("\(index + 1)")
                                .font(DesignSystem.Typography.caption)
                                .fontWeight(.bold)
                                .foregroundColor(isTopChoice ? .white : DesignSystem.Colors.primary)
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle().fill(isTopChoice ? DesignSystem.Colors.primary : DesignSystem.Colors.primary.opacity(0.2))
                                )
                            
                            // 日時
                            Text(scheduleViewModel.formatDateTime(date))
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(isTopChoice ? .white : DesignSystem.Colors.black)
                            
                            Spacer()
                            
                            // 参加希望数（常に表示）
                            Text("\(votes)人")
                                .font(DesignSystem.Typography.subheadline)
                                .fontWeight(isTopChoice ? .bold : .regular)
                                .foregroundColor(isTopChoice ? .white : (votes > 0 ? DesignSystem.Colors.primary : DesignSystem.Colors.secondary))
                        }
                        .padding(DesignSystem.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                                .fill(isTopChoice ? DesignSystem.Colors.primary : DesignSystem.Colors.primary.opacity(0.1))
                        )
                    }
                }
            } else {
                Text("候補日時が設定されていません")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .italic()
            }
            
            // URL表示＆コピー
            if let webUrl = event.webUrl {
                Button(action: {
                    UIPasteboard.general.string = webUrl
                    // コピー成功のhaptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }) {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text(webUrl)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Text("タップしてコピー")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.secondary)
                                
                                Image(systemName: "doc.on.doc")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                            .fill(DesignSystem.Colors.primary.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // サブアクション：プレビューと編集
            HStack(spacing: DesignSystem.Spacing.lg) {
                if let onPreview = onPreview {
                    Button(action: onPreview) {
                        Text("プレビュー")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                    
                    Text("|")
                        .foregroundColor(DesignSystem.Colors.gray2)
                }
                
                Button(action: onEdit) {
                    Text("編集")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private func calculateVoteCounts(for event: ScheduleEvent) -> [Date: Int] {
        var counts: [Date: Int] = [:]
        
        // 全候補日時を0で初期化
        for date in event.candidateDates {
            counts[date] = 0
        }
        
        // 各回答の available_dates（参加可能な日）をカウント
        for response in event.responses {
            for availableDate in response.availableDates {
                // 候補日時と一致する日をカウント
                for candidateDate in event.candidateDates {
                    // 日時を比較（秒単位の差を許容）
                    if abs(availableDate.timeIntervalSince(candidateDate)) < 60 {
                        counts[candidateDate, default: 0] += 1
                        break
                    }
                }
            }
        }
        
        return counts
    }
}

// MARK: - PrePlan Schedule Empty State View
struct PrePlanScheduleEmptyStateView: View {
    let candidateDatesCount: Int
    let onEdit: () -> Void
    let onPreview: () -> Void
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // メッセージ
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.secondary)
                
                if candidateDatesCount > 0 {
                    Text("\(candidateDatesCount)個の候補日が設定されています")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.secondary)
                } else {
                    Text("まだ候補日は設定されていません")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // サブアクション：プレビューと編集
            HStack(spacing: DesignSystem.Spacing.lg) {
                Button(action: onPreview) {
                    Text("プレビュー")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.primary)
                }
                
                Text("|")
                    .foregroundColor(DesignSystem.Colors.gray2)
                
                Button(action: onEdit) {
                    Text("編集")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
            .frame(maxWidth: .infinity)
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

// MARK: - Schedule Preview Sheet
struct SchedulePreviewSheet: View {
    let scheduleEvent: ScheduleEvent?
    let scheduleTitle: String
    let scheduleDescription: String
    let scheduleCandidateDates: [Date]
    let scheduleLocation: String
    let scheduleBudget: String
    @ObservedObject var scheduleViewModel: ScheduleManagementViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            if let event = scheduleEvent {
                // WebViewでweb-frontendのページを表示
                ScheduleWebView(event: event, viewModel: scheduleViewModel)
            } else {
                // イベントが作成されていない場合はローディング表示（またはプレビューデータ表示）
                VStack(spacing: DesignSystem.Spacing.md) {
                    ProgressView()
                    Text("プレビューを準備中...")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("プレビュー")
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
}

// Helper Toggles
struct CheckmarkToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                .foregroundColor(configuration.isOn ? .green : .gray)
                .imageScale(.large)
                .font(.system(size: 24))
                .animation(.spring(), value: configuration.isOn)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct CompactSwitchToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            ZStack {
                Capsule()
                    .fill(configuration.isOn ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 40, height: 24)
                
                Circle()
                    .fill(Color.white)
                    .shadow(radius: 1)
                    .frame(width: 20, height: 20)
                    .offset(x: configuration.isOn ? 9 : -9)
                    .animation(.spring(response: 0.2), value: configuration.isOn)
            }
            .onTapGesture {
                withAnimation {
                    configuration.isOn.toggle()
                }
            }
        }
    }
}
