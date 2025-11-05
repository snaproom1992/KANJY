import SwiftUI

struct TopView: View {
    @StateObject private var viewModel = PrePlanViewModel()
    @StateObject private var scheduleViewModel = ScheduleManagementViewModel()
    @Binding var selectedTab: Int
    @State private var showingPrePlan = false
    @State private var showingDeleteAlert = false
    @State private var planToDelete: Plan? = nil
    @State private var showingCalendarSheet = false
    @State private var showingScheduleCreation = false
    @State private var planForSchedule: Plan? = nil
    @State private var showingHelpGuide = false
    
    init(selectedTab: Binding<Int> = .constant(0)) {
        self._selectedTab = selectedTab
    }
    
    // テスト用のサンプルイベント
    private var sampleEvent: ScheduleEvent {
        ScheduleEvent(
            id: UUID(),
            title: "サンプル飲み会",
            description: "テスト用のスケジュール調整です",
            candidateDates: [
                Calendar.current.date(from: DateComponents(year: 2024, month: 12, day: 15, hour: 18, minute: 0))!,
                Calendar.current.date(from: DateComponents(year: 2024, month: 12, day: 16, hour: 18, minute: 0))!,
                Calendar.current.date(from: DateComponents(year: 2024, month: 12, day: 17, hour: 18, minute: 0))!
            ],
            responses: [],
            createdBy: "テストユーザー",
            createdAt: Date()
        )
    }
    
    private var filteredPlans: [Plan] {
        viewModel.savedPlans.sorted(by: { $0.date > $1.date })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    quickActionsSection
                    dashboardCard
                }
                .padding(.top, 16)
                .padding(.bottom, 32)
                .padding(.horizontal, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("ホーム")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingHelpGuide = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .onAppear {
                Task {
                    await scheduleViewModel.fetchEventsFromSupabase()
                }
            }
            .sheet(isPresented: $showingHelpGuide) {
                HelpGuideView()
            }
            .sheet(isPresented: $showingPrePlan, onDismiss: {
                if !viewModel.editingPlanName.isEmpty {
                    print("シートが閉じられる際に自動保存を実行: \(viewModel.editingPlanName)")
                    viewModel.savePlan(
                        name: viewModel.editingPlanName.isEmpty ? "無題の飲み会" : viewModel.editingPlanName,
                        date: viewModel.editingPlanDate ?? Date()
                    )
                }
            }) {
                NavigationStack {
                    PrePlanView(
                        viewModel: viewModel,
                        planName: viewModel.editingPlanName.isEmpty ? "" : viewModel.editingPlanName,
                        planDate: viewModel.editingPlanDate,
                        onFinish: {
                            showingPrePlan = false
                        }
                    )
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .alert("飲み会の削除", isPresented: $showingDeleteAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {
                    if let plan = planToDelete {
                        viewModel.deletePlan(id: plan.id)
                    }
                }
            } message: {
                Text("この飲み会を削除してもよろしいですか？")
            }
            .sheet(isPresented: $showingCalendarSheet) {
                CalendarSheetView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingScheduleCreation) {
                if let plan = planForSchedule {
                    NavigationStack {
                        CreateScheduleEventView(viewModel: scheduleViewModel, plan: plan) { event in
                            // 飲み会にスケジュール調整を紐づける
                            if let planIndex = viewModel.savedPlans.firstIndex(where: { $0.id == plan.id }) {
                                viewModel.savedPlans[planIndex].scheduleEventId = event.id
                                viewModel.saveData()
                            }
                            showingScheduleCreation = false
                            planForSchedule = nil
                        }
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }
        }
    }
}

// MARK: - Subviews

private extension TopView {
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("飲み会管理")
                .font(.largeTitle.bold())
                .foregroundColor(.primary)
            
            Text("飲み会の計画を作成し、参加者や集金を管理できます")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("クイックアクション")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                // 新しいイベント作成
                Button {
                    // 新規作成の場合は空の状態でPrePlanViewを開く
                    viewModel.resetForm()
                    viewModel.editingPlanId = nil
                    viewModel.editingPlanName = ""
                    viewModel.editingPlanDate = nil
                    viewModel.selectedEmoji = "🍻"
                    showingPrePlan = true
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(.white)
                        Text("新規作成")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
    }

    var dashboardCard: some View {
        materialCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("保存した飲み会")
                            .font(.headline)
                            .foregroundColor(.primary)
                        if !filteredPlans.isEmpty {
                            Text("\(filteredPlans.count)件 登録済み")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("タップして参加者や金額を設定できます")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        showingCalendarSheet = true
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                LinearGradient(
                                    colors: [Color.accentColor.opacity(0.8), Color.accentColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: Color.accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }

                if filteredPlans.isEmpty {
                    EmptyStateView {
                        // 新規作成の場合は空の状態でPrePlanViewを開く
                        viewModel.resetForm()
                        viewModel.editingPlanId = nil
                        viewModel.editingPlanName = ""
                        viewModel.editingPlanDate = nil
                        viewModel.selectedEmoji = "🍻"
                        showingPrePlan = true
                    }
                } else {
                    VStack(spacing: 10) {
                        ForEach(filteredPlans) { plan in
                            PlanListCell(
                                plan: plan,
                                viewModel: viewModel,
                                scheduleViewModel: scheduleViewModel,
                                onTap: {
                                    viewModel.loadPlan(plan)
                                    showingPrePlan = true
                                },
                                onDelete: {
                                    planToDelete = plan
                                    showingDeleteAlert = true
                                },
                                onCreateSchedule: {
                                    planForSchedule = plan
                                    showingScheduleCreation = true
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    func materialCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
            )
    }
}

// 空状態表示をシンプルに案内
struct EmptyStateView: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.1), Color.accentColor.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("今後のイベントなし")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)

                Text("飲み会の計画を作成して、参加者や集金を管理しましょう。\nタップして詳細を編集できます。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }

            Button(action: onCreate) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("イベントを作成")
                        .font(.body.weight(.semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

extension TopView {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
}

// サブビュー: プランリストのセル
private struct PlanListCell: View {
    let plan: Plan
    let viewModel: PrePlanViewModel
    let scheduleViewModel: ScheduleManagementViewModel
    let onTap: () -> Void
    let onDelete: () -> Void
    let onCreateSchedule: () -> Void

    // 集金ステータスを計算
    private var collectionStatus: (isComplete: Bool, count: Int, total: Int) {
        let collectedCount = plan.participants.filter { $0.hasCollected }.count
        let totalCount = plan.participants.count
        return (collectedCount == totalCount && totalCount > 0, collectedCount, totalCount)
    }
    
    // スケジュール調整の状態を取得
    private var scheduleEvent: ScheduleEvent? {
        guard let scheduleEventId = plan.scheduleEventId else { return nil }
        return scheduleViewModel.events.first { $0.id == scheduleEventId }
    }
    
    private var hasSchedule: Bool {
        return plan.scheduleEventId != nil
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // 絵文字表示
                Text(plan.emoji ?? "🍻")
                    .font(.system(size: 40))
                    .frame(width: 64, height: 64)
                    .background(
                        Circle()
                            .fill(Color(.systemGray6))
                    )
                
                // メイン情報
                VStack(alignment: .leading, spacing: 8) {
                    // タイトルと日付
                    HStack {
                        Text(plan.name)
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.black)
                        
                        Spacer()
                        
                        Text(viewModel.formatDate(plan.date))
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondary)
                    }
                    
                    // サブ情報
                    HStack(spacing: 12) {
                        // 参加者数
                        if !plan.participants.isEmpty {
                            Label("\(plan.participants.count)人", systemImage: "person.2.fill")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.secondary)
                        }
                        
                        // 金額
                        if !plan.totalAmount.isEmpty {
                            Text("¥\(viewModel.formatAmount(plan.totalAmount))")
                                .font(DesignSystem.Typography.emphasizedSubheadline)
                                .foregroundColor(DesignSystem.Colors.primary)
                        }
                        
                        Spacer()
                        
                        // ステータスインジケーター（簡素化）
                        if plan.totalAmount.isEmpty || plan.participants.isEmpty {
                            Circle()
                                .fill(DesignSystem.Colors.warning)
                                .frame(width: 8, height: 8)
                        } else if collectionStatus.isComplete {
                            Circle()
                                .fill(DesignSystem.Colors.success)
                                .frame(width: 8, height: 8)
                        } else if collectionStatus.total > 0 {
                            Circle()
                                .fill(DesignSystem.Colors.primary)
                                .frame(width: 8, height: 8)
                        }
                        
                        // スケジュール調整アイコン（簡素化）
                        if hasSchedule {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.primary)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(DesignSystem.Card.Padding.medium)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusLarge, style: .continuous)
                    .fill(DesignSystem.Colors.secondaryBackground)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            // 削除アクション
            Button(role: .destructive, action: onDelete) {
                Label("削除", systemImage: "trash")
            }
            
            // スケジュール作成アクション（必要な場合のみ）
            if !hasSchedule {
                Button(action: onCreateSchedule) {
                    Label("スケジュール調整を作成", systemImage: "calendar.badge.plus")
                }
            }
        }
    }
}


#Preview {
    TopView(selectedTab: .constant(0))
}
