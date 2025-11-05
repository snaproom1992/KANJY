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
                    }
                }
                
                // イベント一覧セクション
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
                        Text("スケジュール調整イベント")
                        Spacer()
                        Text("\(viewModel.events.count)件")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // アクションセクション
                Section {
                    Button(action: {
                        showingCreateEvent = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                            Text("新しいスケジュール調整を作成")
                                .font(.headline)
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("管理")
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
            .alert("イベントの削除", isPresented: $showingDeleteAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {
                    if let event = eventToDelete {
                        viewModel.deleteEvent(id: event.id)
                    }
                }
            } message: {
                Text("このスケジュール調整イベントを削除してもよろしいですか？")
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
        VStack(spacing: 16) {
            Text("スケジュール調整はまだありません")
                .font(.headline)

            Text("イベントを作成して候補日程を参加者と共有しましょう。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onCreate) {
                Label("スケジュールを作成", systemImage: "plus.circle")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - 統計サマリー表示

struct StatisticsSummaryView: View {
    @ObservedObject var viewModel: ScheduleManagementViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                StatCard(
                    title: "総イベント",
                    value: "\(viewModel.events.count)",
                    icon: "calendar",
                    color: .blue
                )
                
                StatCard(
                    title: "アクティブ",
                    value: "\(viewModel.events.filter { $0.isActive }.count)",
                    icon: "checkmark.circle",
                    color: .green
                )
                
                StatCard(
                    title: "回答者",
                    value: "\(viewModel.events.reduce(0) { $0 + $1.responses.count })",
                    icon: "person.2",
                    color: .orange
                )
            }
            
            if !viewModel.events.isEmpty {
                let totalResponses = viewModel.events.reduce(0) { sum, event in
                    sum + event.responses.count
                }
                let totalAttending = viewModel.events.reduce(0) { sum, event in
                    sum + event.attendingCount
                }
                
                HStack {
                    StatCard(
                        title: "総回答",
                        value: "\(totalResponses)",
                        icon: "message",
                        color: .purple
                    )
                    
                    StatCard(
                        title: "参加者",
                        value: "\(totalAttending)",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
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
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let optimalDate = event.optimalDate {
                            Text("最適日時: \(viewModel.formatDateTime(optimalDate))")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        } else {
                            Text("候補日時: \(event.candidateDates.count)件")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // ステータスバッジ
                    StatusBadge(event: event, viewModel: viewModel)
                }
                
                // 参加者情報
                HStack(spacing: 16) {
                    Label("\(event.attendingCount)人", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Label("\(event.notAttendingCount)人", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    
                    Label("\(event.undecidedCount)人", systemImage: "questionmark.circle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Spacer()
                    
                    Text("\(event.responses.count)人回答")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                // 場所・予算情報
                if let location = event.location {
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text(location)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                
                if let budget = event.budget {
                    HStack {
                        Image(systemName: "yensign.circle")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text("予算: ¥\(viewModel.formatAmount(String(budget)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .padding(.vertical, 4)
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
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.gray)
                    .cornerRadius(8)
            } else if isDeadlinePassed {
                Text("期限切れ")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.2))
                    .foregroundColor(.red)
                    .cornerRadius(8)
            } else {
                Text("募集中")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(8)
            }
        }
    }
}


// MARK: - プレビュー

#Preview {
    ScheduleManagementView()
} 
