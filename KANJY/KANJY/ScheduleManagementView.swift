import SwiftUI

struct ScheduleManagementView: View {
    @StateObject private var viewModel = ScheduleManagementViewModel()
    @State private var showingCreateEvent = false
    @State private var selectedEvent: ScheduleEvent?
    @State private var showingEventDetail = false
    @State private var showingDeleteAlert = false
    @State private var eventToDelete: ScheduleEvent?
    
    var body: some View {
        NavigationStack {
            List {
                // 統計サマリーセクション
                if !viewModel.events.isEmpty {
                    Section {
                        StatisticsSummaryView(viewModel: viewModel)
                    } header: {
                        Text("全体統計")
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.black)
                    }
                }
                
                // スケジュール調整一覧セクション
                Section {
                    if viewModel.events.isEmpty {
                        ScheduleEmptyStateView {
                            showingCreateEvent = true
                        }
                    } else {
                        ForEach(viewModel.events.sorted(by: { $0.createdAt > $1.createdAt })) { event in
                            EventListRow(event: event, viewModel: viewModel) {
                                selectedEvent = event
                                showingEventDetail = true
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    eventToDelete = event
                                    showingDeleteAlert = true
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("スケジュール調整")
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.black)
                        Spacer()
                        Text("\(viewModel.events.count)件")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondary)
                    }
                }
                
                // アクションセクション
                Section {
                    Button(action: {
                        showingCreateEvent = true
                    }) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: DesignSystem.Icon.Size.xlarge, weight: DesignSystem.Typography.FontWeight.medium))
                                .foregroundColor(DesignSystem.Colors.primary)
                            Text("新しいスケジュール調整を作成")
                                .font(DesignSystem.Typography.headline)
                                .foregroundColor(DesignSystem.Colors.primary)
                        }
                        .padding(.vertical, DesignSystem.Spacing.sm)
                    }
                } header: {
                    Text("管理")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.black)
                }
            }
            .navigationTitle("スケジュール調整")
            .sheet(isPresented: $showingCreateEvent) {
                CreateScheduleEventView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingEventDetail) {
                if let event = selectedEvent {
                    ScheduleEventDetailView(event: event, viewModel: viewModel)
                }
            }
            .alert("スケジュール調整の削除", isPresented: $showingDeleteAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {
                    if let event = eventToDelete {
                        viewModel.deleteEvent(id: event.id)
                    }
                }
            } message: {
                Text("このスケジュール調整を削除してもよろしいですか？")
            }
            .onAppear {
                Task {
                    await viewModel.fetchEventsFromSupabase()
                }
            }
        }
    }
}

struct ScheduleEmptyStateView: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Text("スケジュール調整はまだありません")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.black)

            Text("スケジュール調整を作成して候補日程を参加者と共有しましょう。")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.secondary)
                .multilineTextAlignment(.center)

            Button(action: onCreate) {
                Label("スケジュールを作成", systemImage: "plus.circle")
                    .font(DesignSystem.Typography.emphasizedSubheadline)
                    .foregroundColor(DesignSystem.Colors.primary)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.xxxl)
    }
}

// MARK: - 統計サマリー表示

struct StatisticsSummaryView: View {
    @ObservedObject var viewModel: ScheduleManagementViewModel
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                StatCard(
                    title: "総スケジュール調整",
                    value: "\(viewModel.events.count)",
                    icon: "calendar",
                    color: DesignSystem.Colors.primary
                )
                
                StatCard(
                    title: "アクティブ",
                    value: "\(viewModel.events.filter { $0.isActive }.count)",
                    icon: "checkmark.circle",
                    color: DesignSystem.Colors.success
                )
                
                StatCard(
                    title: "回答者",
                    value: "\(viewModel.events.reduce(0) { $0 + $1.responses.count })",
                    icon: "person.2",
                    color: DesignSystem.Colors.warning
                )
            }
            
            if !viewModel.events.isEmpty {
                let totalResponses = viewModel.events.reduce(0) { sum, event in
                    sum + event.responses.count
                }
                let totalAttending = viewModel.events.reduce(0) { sum, event in
                    sum + event.attendingCount
                }
                
                HStack(spacing: DesignSystem.Spacing.sm) {
                    StatCard(
                        title: "総回答",
                        value: "\(totalResponses)",
                        icon: "message",
                        color: DesignSystem.Colors.info
                    )
                    
                    StatCard(
                        title: "参加者",
                        value: "\(totalAttending)",
                        icon: "checkmark.circle.fill",
                        color: DesignSystem.Colors.success
                    )
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: DesignSystem.Icon.Size.xlarge, weight: DesignSystem.Typography.FontWeight.medium))
                .foregroundColor(color)
            
            Text(value)
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.black)
            
            Text(title)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                .fill(DesignSystem.Colors.gray1)
        )
    }
}

// MARK: - イベント一覧行

struct EventListRow: View {
    let event: ScheduleEvent
    @ObservedObject var viewModel: ScheduleManagementViewModel
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(event.title)
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.black)
                        
                        if let optimalDate = event.optimalDate {
                            Text("最適日時: \(viewModel.formatDateTime(optimalDate))")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(DesignSystem.Colors.primary)
                        } else {
                            Text("候補日時: \(event.candidateDates.count)件")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(DesignSystem.Colors.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // ステータスバッジ
                    StatusBadge(event: event, viewModel: viewModel)
                }
                
                // 参加者情報
                HStack(spacing: DesignSystem.Spacing.lg) {
                    Label("\(event.attendingCount)人", systemImage: "checkmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.success)
                        .font(DesignSystem.Typography.caption)
                    
                    Label("\(event.notAttendingCount)人", systemImage: "xmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.alert)
                        .font(DesignSystem.Typography.caption)
                    
                    Label("\(event.undecidedCount)人", systemImage: "questionmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.warning)
                        .font(DesignSystem.Typography.caption)
                    
                    Spacer()
                    
                    Text("\(event.responses.count)人回答")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.primary)
                }
                
                // 場所・予算情報
                if let location = event.location {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "location")
                            .foregroundColor(DesignSystem.Colors.secondary)
                            .font(.system(size: DesignSystem.Icon.Size.small))
                        Text(location)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondary)
                        Spacer()
                    }
                }
                
                if let budget = event.budget {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "yensign.circle")
                            .foregroundColor(DesignSystem.Colors.secondary)
                            .font(.system(size: DesignSystem.Icon.Size.small))
                        Text("予算: ¥\(viewModel.formatAmount(String(budget)))")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondary)
                        Spacer()
                    }
                }
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
        }
        .buttonStyle(.plain)
    }
}

struct StatusBadge: View {
    let event: ScheduleEvent
    @ObservedObject var viewModel: ScheduleManagementViewModel
    
    var body: some View {
        let isPassed = viewModel.isEventPassed(for: event)
        let isDeadlinePassed = viewModel.isDeadlinePassed(for: event)
        
        Group {
            if isPassed {
                Text("終了")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.gray6)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(DesignSystem.Colors.gray3.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous))
            } else if isDeadlinePassed {
                Text("期限切れ")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.alert)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(DesignSystem.Colors.alert.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous))
            } else {
                Text("募集中")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.success)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(DesignSystem.Colors.success.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous))
            }
        }
    }
}


// MARK: - プレビュー

#Preview {
    ScheduleManagementView()
} 
