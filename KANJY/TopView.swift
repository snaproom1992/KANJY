import SwiftUI

struct TopView: View {
    @StateObject private var viewModel = PrePlanViewModel()
    @StateObject private var scheduleViewModel = ScheduleManagementViewModel()
    @Binding var selectedTab: Int
    @State private var showingPrePlan = false
    @State private var showingDeleteAlert = false
    @State private var planToDelete: Plan? = nil
    @State private var showingCalendarSheet = false
    @State private var showingHelpGuide = false
    @State private var shouldOpenScheduleTab = false // スケジュールタブを開くかどうか
    
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
                .padding(.top, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.xxxl)
                .padding(.horizontal, DesignSystem.Spacing.xl)
            }
            .background(DesignSystem.Colors.groupedBackground)
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
                shouldOpenScheduleTab = false // リセット
            }) {
                NavigationStack {
                    PrePlanView(
                        viewModel: viewModel,
                        planName: viewModel.editingPlanName.isEmpty ? "" : viewModel.editingPlanName,
                        planDate: viewModel.editingPlanDate,
                        initialTask: shouldOpenScheduleTab ? .schedule : nil,
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
        }
    }
}

// MARK: - Subviews

private extension TopView {
    var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("飲み会管理")
                .font(DesignSystem.Typography.largeTitle)
                .foregroundColor(DesignSystem.Colors.black)
            
            Text("飲み会の計画を作成し、参加者や集金を管理できます")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("クイックアクション")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.black)
            
            HStack(spacing: DesignSystem.Spacing.md) {
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
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: DesignSystem.Icon.Size.xxlarge, weight: DesignSystem.Typography.FontWeight.medium))
                            .foregroundColor(DesignSystem.Colors.white)
                        Text("新規作成")
                            .font(DesignSystem.Typography.emphasizedSubheadline)
                            .foregroundColor(DesignSystem.Colors.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.xl)
                    .background(
                        LinearGradient(
                            colors: [DesignSystem.Colors.primary, DesignSystem.Colors.primary.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusLarge, style: .continuous))
                    .shadow(color: DesignSystem.Colors.primary.opacity(0.3), radius: DesignSystem.Card.Shadow.largeRadius, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                
            }
        }
        .padding(DesignSystem.Card.Padding.large)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusLarge, style: .continuous)
                .fill(DesignSystem.Colors.secondaryBackground)
                .shadow(
                    color: Color.black.opacity(DesignSystem.Card.Shadow.opacity),
                    radius: DesignSystem.Card.Shadow.radius,
                    x: DesignSystem.Card.Shadow.offset.width,
                    y: DesignSystem.Card.Shadow.offset.height
                )
        )
    }

    var dashboardCard: some View {
        materialCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("保存した飲み会")
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.black)
                        if !filteredPlans.isEmpty {
                            Text("\(filteredPlans.count)件 登録済み")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.secondary)
                        } else {
                            Text("タップして参加者や金額を設定できます")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        showingCalendarSheet = true
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: DesignSystem.Icon.Size.medium, weight: DesignSystem.Typography.FontWeight.medium))
                            .foregroundColor(DesignSystem.Colors.white)
                            .frame(width: DesignSystem.Button.Size.medium, height: DesignSystem.Button.Size.medium)
                            .background(
                                LinearGradient(
                                    colors: [DesignSystem.Colors.primary.opacity(0.8), DesignSystem.Colors.primary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: DesignSystem.Colors.primary.opacity(0.3), radius: DesignSystem.Card.Shadow.radius, x: 0, y: 2)
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
                    VStack(spacing: DesignSystem.Spacing.sm) {
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
                                    // PrePlanViewを開いてスケジュールタブに移動
                                    viewModel.loadPlan(plan)
                                    shouldOpenScheduleTab = true
                                    showingPrePlan = true
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
            .padding(DesignSystem.Card.Padding.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusLarge, style: .continuous)
                    .fill(DesignSystem.Colors.secondaryBackground)
                    .shadow(
                        color: Color.black.opacity(DesignSystem.Card.Shadow.largeOpacity),
                        radius: DesignSystem.Card.Shadow.largeRadius,
                        x: DesignSystem.Card.Shadow.largeOffset.width,
                        y: DesignSystem.Card.Shadow.largeOffset.height
                    )
            )
    }
}

// 空状態表示をシンプルに案内
struct EmptyStateView: View {
    let onCreate: () -> Void

    var body: some View {
            VStack(spacing: DesignSystem.Spacing.xxl) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [DesignSystem.Colors.primary.opacity(0.1), DesignSystem.Colors.primary.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: DesignSystem.Icon.Size.xxlarge * 1.5, weight: DesignSystem.Typography.FontWeight.medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DesignSystem.Colors.primary, DesignSystem.Colors.primary.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("今後のイベントなし")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.black)

                Text("飲み会の計画を作成して、参加者や集金を管理しましょう。\nタップして詳細を編集できます。")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.md)
            }

            Button(action: onCreate) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: DesignSystem.Icon.Size.large, weight: DesignSystem.Typography.FontWeight.semibold))
                    Text("イベントを作成")
                        .font(DesignSystem.Typography.emphasizedBody)
                }
                .foregroundColor(DesignSystem.Colors.white)
                .padding(.horizontal, DesignSystem.Button.Padding.largeHorizontal)
                .padding(.vertical, DesignSystem.Button.Padding.largeVertical)
                .background(
                    LinearGradient(
                        colors: [DesignSystem.Colors.primary, DesignSystem.Colors.primary.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous))
                .shadow(color: DesignSystem.Colors.primary.opacity(0.3), radius: DesignSystem.Card.Shadow.largeRadius, x: 0, y: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.xxxl)
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
