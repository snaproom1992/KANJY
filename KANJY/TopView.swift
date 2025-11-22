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
    @State private var shouldOpenScheduleTab = false
    @State private var isRefreshing = false
    @State private var appearedItems: Set<UUID> = []
    
    init(selectedTab: Binding<Int> = .constant(0)) {
        self._selectedTab = selectedTab
    }
    
    private var filteredPlans: [Plan] {
        // 集金未完了 → 開催日が近い順にソート
        viewModel.savedPlans.sorted { plan1, plan2 in
            let status1 = collectionStatus(for: plan1)
            let status2 = collectionStatus(for: plan2)
            
            // 集金未完了を優先
            if !status1.isComplete && status2.isComplete {
                return true
            } else if status1.isComplete && !status2.isComplete {
                return false
            } else {
                // 同じステータスなら日付順
                return plan1.date > plan2.date
            }
        }
    }
    
    // 集金ステータスを計算するヘルパー
    private func collectionStatus(for plan: Plan) -> (isComplete: Bool, count: Int, total: Int) {
        let collectedCount = plan.participants.filter { $0.hasCollected }.count
        let totalCount = plan.participants.count
        return (collectedCount == totalCount && totalCount > 0, collectedCount, totalCount)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 新規作成ボタン（最優先）
                    createButton
                        .padding(.top, DesignSystem.Spacing.md)
                    
                    // 飲み会リスト
                    plansListSection
                }
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.bottom, DesignSystem.Spacing.xxxl)
            }
            .background(DesignSystem.Colors.groupedBackground)
            .refreshable {
                await refreshData()
            }
            .navigationTitle("飲み会")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        hapticImpact(.light)
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
                shouldOpenScheduleTab = false
                viewModel.editingPlanId = nil
            }) {
                // 新規作成の場合はQuickCreatePlanView、編集の場合はPrePlanView
                if viewModel.editingPlanId == nil {
                    QuickCreatePlanView(viewModel: viewModel)
                } else {
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
            }
            .alert("飲み会の削除", isPresented: $showingDeleteAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {
                    if let plan = planToDelete {
                        hapticNotification(.success)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.deletePlan(id: plan.id)
                        }
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
    
    // プルトゥリフレッシュ処理
    private func refreshData() async {
        hapticImpact(.light)
        isRefreshing = true
        await scheduleViewModel.fetchEventsFromSupabase()
        try? await Task.sleep(nanoseconds: 500_000_000)
        isRefreshing = false
        hapticNotification(.success)
    }
    
    // ハプティックフィードバック（インパクト）
    private func hapticImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    // ハプティックフィードバック（通知）
    private func hapticNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}

// MARK: - Subviews

private extension TopView {
    // 新規作成ボタン（大きく目立つように）
    var createButton: some View {
        AnimatedButton(action: {
            hapticImpact(.medium)
            viewModel.resetForm()
            viewModel.editingPlanId = nil
            viewModel.editingPlanName = ""
            viewModel.editingPlanDate = nil
            viewModel.selectedEmoji = "🍻"
            showingPrePlan = true
        }) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                Text("新しい飲み会を作成")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.primary,
                        DesignSystem.Colors.primary.opacity(0.85)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(
                color: DesignSystem.Colors.primary.opacity(0.4),
                radius: 12,
                x: 0,
                y: 6
            )
        }
    }
    
    // 飲み会リストセクション
    var plansListSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // セクションヘッダー
            HStack {
                Text(filteredPlans.isEmpty ? "予定なし" : "直近の予定")
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.black)
                
                Spacer()
                
                if !filteredPlans.isEmpty {
                    Button {
                        hapticImpact(.light)
                        showingCalendarSheet = true
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.primary)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(DesignSystem.Colors.primary.opacity(0.1))
                            )
                    }
                }
            }
            .padding(.top, DesignSystem.Spacing.sm)
            
            // 飲み会リスト or 空状態
            if filteredPlans.isEmpty {
                EmptyStateView {
                    hapticImpact(.medium)
                    viewModel.resetForm()
                    viewModel.editingPlanId = nil
                    viewModel.editingPlanName = ""
                    viewModel.editingPlanDate = nil
                    viewModel.selectedEmoji = "🍻"
                    showingPrePlan = true
                }
            } else {
                VStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(Array(filteredPlans.enumerated()), id: \.element.id) { index, plan in
                        PlanCard(
                            plan: plan,
                            viewModel: viewModel,
                            scheduleViewModel: scheduleViewModel,
                            onTap: {
                                hapticImpact(.light)
                                viewModel.loadPlan(plan)
                                showingPrePlan = true
                            },
                            onDelete: {
                                hapticNotification(.warning)
                                planToDelete = plan
                                showingDeleteAlert = true
                            },
                            onCreateSchedule: {
                                hapticImpact(.light)
                                viewModel.loadPlan(plan)
                                shouldOpenScheduleTab = true
                                showingPrePlan = true
                            }
                        )
                        .opacity(appearedItems.contains(plan.id) ? 1 : 0)
                        .offset(y: appearedItems.contains(plan.id) ? 0 : 20)
                        .onAppear {
                            let animation = Animation.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.05)
                            withAnimation(animation) {
                                appearedItems.insert(plan.id)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - アニメーション付きボタン

struct AnimatedButton<Content: View>: View {
    let action: () -> Void
    let content: Content
    
    init(action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        Button(action: action) {
            content
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - 空状態表示

struct EmptyStateView: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxl) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 80, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [DesignSystem.Colors.primary.opacity(0.6), DesignSystem.Colors.primary.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top, DesignSystem.Spacing.xxxl)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("まだ予定がありません")
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(DesignSystem.Colors.black)
                    .fontWeight(.semibold)

                Text("最初の飲み会を作成しましょう")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondary)
            }

            AnimatedButton(action: onCreate) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                    Text("飲み会を作成")
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [DesignSystem.Colors.primary, DesignSystem.Colors.primary.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: DesignSystem.Colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.xxxl * 2)
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

// MARK: - プランカード（改良版）

private struct PlanCard: View {
    let plan: Plan
    let viewModel: PrePlanViewModel
    let scheduleViewModel: ScheduleManagementViewModel
    let onTap: () -> Void
    let onDelete: () -> Void
    let onCreateSchedule: () -> Void
    @State private var isPressed = false

    private var collectionStatus: (isComplete: Bool, count: Int, total: Int) {
        let collectedCount = plan.participants.filter { $0.hasCollected }.count
        let totalCount = plan.participants.count
        return (collectedCount == totalCount && totalCount > 0, collectedCount, totalCount)
    }
    
    private var hasSchedule: Bool {
        return plan.scheduleEventId != nil
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                // ヘッダー：絵文字 + タイトル + 日付
                HStack(alignment: .top, spacing: 12) {
                    Text(plan.emoji ?? "🍻")
                        .font(.system(size: 44))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.name)
                            .font(DesignSystem.Typography.title3)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.black)
                        
                        Text(formatDateShort(plan.date))
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondary)
                    }
                    
                    Spacer()
                    
                    // スケジュールバッジ
                    if hasSchedule {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: 20))
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                }
                
                // 参加者と金額
                HStack(spacing: 16) {
                    if !plan.participants.isEmpty {
                        Label {
                            Text("\(plan.participants.count)人")
                                .font(DesignSystem.Typography.body)
                                .fontWeight(.medium)
                        } icon: {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 16))
                        }
                        .foregroundColor(DesignSystem.Colors.secondary)
                    }
                    
                    if !plan.totalAmount.isEmpty {
                        Label {
                            Text("¥\(viewModel.formatAmount(plan.totalAmount))")
                                .font(DesignSystem.Typography.body)
                                .fontWeight(.semibold)
                        } icon: {
                            Image(systemName: "yensign.circle.fill")
                                .font(.system(size: 16))
                        }
                        .foregroundColor(DesignSystem.Colors.primary)
                    }
                }
                
                // 集金進捗バー（最重要！）
                if collectionStatus.total > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("集金状況")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.secondary)
                            
                            Spacer()
                            
                            Text("\(collectionStatus.count)/\(collectionStatus.total)人")
                                .font(DesignSystem.Typography.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(collectionStatus.isComplete ? DesignSystem.Colors.success : DesignSystem.Colors.primary)
                        }
                        
                        // 視覚的な進捗バー
                        CollectionProgressBar(
                            collected: collectionStatus.count,
                            total: collectionStatus.total
                        )
                        
                        // ドットインジケーター
                        HStack(spacing: 4) {
                            ForEach(0..<collectionStatus.total, id: \.self) { index in
                                Circle()
                                    .fill(index < collectionStatus.count ? DesignSystem.Colors.success : DesignSystem.Colors.gray3)
                                    .frame(width: 8, height: 8)
                            }
                            
                            if collectionStatus.count < collectionStatus.total {
                                Text("未: \(collectionStatus.total - collectionStatus.count)人")
                                    .font(DesignSystem.Typography.caption2)
                                    .foregroundColor(DesignSystem.Colors.warning)
                                    .padding(.leading, 4)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(DesignSystem.Colors.secondaryBackground)
                    .shadow(
                        color: isPressed ? Color.black.opacity(0.12) : Color.black.opacity(0.06),
                        radius: isPressed ? 12 : 8,
                        x: 0,
                        y: isPressed ? 6 : 4
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isPressed ? DesignSystem.Colors.primary.opacity(0.3) : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("削除", systemImage: "trash")
            }
            
            if !hasSchedule {
                Button(action: onCreateSchedule) {
                    Label("スケジュール調整を作成", systemImage: "calendar.badge.plus")
                }
            }
        }
    }
    
    // 日付を簡潔にフォーマット
    private func formatDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日(E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

// MARK: - 集金進捗バー

struct CollectionProgressBar: View {
    let collected: Int
    let total: Int
    
    private var progress: Double {
        total > 0 ? Double(collected) / Double(total) : 0
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(DesignSystem.Colors.gray2)
                    .frame(height: 12)
                
                // 進捗
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: collected == total
                                ? [DesignSystem.Colors.success, DesignSystem.Colors.success.opacity(0.8)]
                                : [DesignSystem.Colors.primary, DesignSystem.Colors.primary.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress, height: 12)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
            }
        }
        .frame(height: 12)
    }
}

#Preview {
    TopView(selectedTab: .constant(0))
}

