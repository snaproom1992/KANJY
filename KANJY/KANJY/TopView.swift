import SwiftUI

struct TopView: View {
    @StateObject private var viewModel = PrePlanViewModel()
    @StateObject private var scheduleViewModel = ScheduleManagementViewModel()
    @Binding var selectedTab: Int
    @State private var showingCreateView = false
    @State private var showingDeleteAlert = false
    @State private var planToDelete: Plan? = nil
    @State private var showingCalendarSheet = false
    @State private var showingHelpGuide = false
    @State private var shouldOpenScheduleTab = false
    @State private var isRefreshing = false
    @State private var appearedItems: Set<UUID> = []
    @State private var selectedPlanForNavigation: Plan? = nil
    @Namespace private var animation
    
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
                            .foregroundColor(DesignSystem.Colors.primary)
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
            .navigationDestination(isPresented: $showingCreateView) {
                QuickCreatePlanView(viewModel: viewModel)
                    .modifier(CreateViewTransitionModifier(sourceID: "createButton", namespace: animation))
            }
            .navigationDestination(item: $selectedPlanForNavigation) { plan in
                        PrePlanView(
                            viewModel: viewModel,
                            planName: viewModel.editingPlanName.isEmpty ? "" : viewModel.editingPlanName,
                            planDate: viewModel.editingPlanDate,
                            initialTask: shouldOpenScheduleTab ? .schedule : nil,
                            onFinish: {
                            // NavigationStackから戻る
                            selectedPlanForNavigation = nil
                            }
                        )
                .modifier(NavigationTransitionModifier(planId: plan.id, namespace: animation))
                .navigationBarTitleDisplayMode(.inline)
            }
            .alert("飲み会の削除", isPresented: $showingDeleteAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {
                    if let plan = planToDelete {
                        hapticNotification(.success)
                        
                        // Supabase連携データの削除（IDがある場合）
                        if let eventId = plan.scheduleEventId {
                            scheduleViewModel.deleteEvent(id: eventId)
                        }
                        
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.deletePlan(id: plan.id)
                        }
                    }
                }
            } message: {
                Text("この飲み会を削除しますか？\n（連携済みのスケジュール調整も同時にクラウドから削除されます）")
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
            showingCreateView = true
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
        .matchedGeometryEffect(id: "createButton", in: animation)
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
            
            // 説明テキスト（回答があるスケジュールがある場合のみ）
            if filteredPlans.contains(where: { plan in
                if let eventId = plan.scheduleEventId,
                   let event = scheduleViewModel.events.first(where: { $0.id == eventId }),
                   !event.responses.isEmpty {
                    return true
                }
                return false
            }) {
                Text("候補日の数字は参加可能回答者数を表します")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .padding(.top, 4)
            }
            
            // 飲み会リスト or 空状態
            if filteredPlans.isEmpty {
                EmptyStateView {
                    hapticImpact(.medium)
                    viewModel.resetForm()
                    viewModel.editingPlanId = nil
                    viewModel.editingPlanName = ""
                    viewModel.editingPlanDate = nil
                    viewModel.selectedEmoji = "🍻"
                    showingCreateView = true
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
                                selectedPlanForNavigation = plan
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
                                selectedPlanForNavigation = plan
                            }
                        )
                        .modifier(NavigationTransitionModifier(planId: plan.id, namespace: animation))
                        .opacity(appearedItems.contains(plan.id) ? 1 : 0)
                        .offset(y: appearedItems.contains(plan.id) ? 0 : 20)
                        .onAppear {
                            let animation = Animation.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.05)
                            _ = withAnimation(animation) {
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
    
    // 文字列からColorを生成するヘルパー関数
    private func colorFromString(_ colorString: String?) -> Color? {
        guard let colorString = colorString, !colorString.isEmpty else { return nil }
        let components = colorString.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard components.count == 3 else { return nil }
        return Color(red: components[0], green: components[1], blue: components[2])
    }
    let onCreateSchedule: () -> Void
    @State private var isPressed = false

    private var collectionStatus: (isComplete: Bool, count: Int, total: Int) {
        let collectedCount = plan.participants.filter { $0.hasCollected }.count
        let totalCount = plan.participants.count
        return (collectedCount == totalCount && totalCount > 0, collectedCount, totalCount)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                // ヘッダー：絵文字 + タイトル + 日付
                HStack(alignment: .center, spacing: 12) {
                    Group {
                        if let iconName = plan.icon {
                            Image(systemName: iconName)
                                .font(.system(size: 44))
                                .foregroundColor(colorFromString(plan.iconColor) ?? DesignSystem.Colors.primary)
                        } else {
                    Text(plan.emoji ?? "🍻")
                        .font(.system(size: 44))
                        }
                    }
                    .frame(width: 70, height: 70)
                    .background(
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                    )
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(plan.name)
                            .font(DesignSystem.Typography.title3)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.black)
                        
                        // 候補日タグ表示
                        if let scheduleEventId = plan.scheduleEventId,
                           let event = scheduleViewModel.events.first(where: { $0.id == scheduleEventId }),
                           !event.candidateDates.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(Array(event.candidateDates.prefix(5).enumerated()), id: \.offset) { _, date in
                                        let status = getDateResponseStatus(date: date, event: event)
                                        HStack(spacing: 4) {
                                            // 日付表示（統一色）
                                            Text(formatDateTag(date))
                                                .font(DesignSystem.Typography.caption)
                                                .fontWeight(DesignSystem.Typography.FontWeight.medium)
                                                .foregroundColor(DesignSystem.Colors.primary)
                                            
                                            // 回答がある場合のみ人数バッジを表示
                                            if status.hasResponses && status.count > 0 {
                                                Text("\(status.count)")
                                                    .font(DesignSystem.Typography.caption2)
                                                    .fontWeight(DesignSystem.Typography.FontWeight.bold)
                                                    .foregroundColor(.white)
                                                    .frame(minWidth: 16, minHeight: 16)
                                                    .padding(.horizontal, 4)
                                                    .background(
                                                        Circle()
                                                            .fill(status.color)
                                                    )
                                            }
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(Color.gray.opacity(0.1))
                                        )
                                    }
                                    
                                    if event.candidateDates.count > 5 {
                                        Text("+\(event.candidateDates.count - 5)")
                                            .font(DesignSystem.Typography.caption)
                                            .fontWeight(DesignSystem.Typography.FontWeight.medium)
                                            .foregroundColor(DesignSystem.Colors.secondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule()
                                                    .fill(Color.gray.opacity(0.1))
                                            )
                                    }
                                }
                            }
                        } else {
                            Text(formatDateShort(plan.date))
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(DesignSystem.Colors.secondary)
                        }
                    }
                    
                    Spacer()
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
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
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
            
            if plan.scheduleEventId == nil {
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
    
    // タグ用の日付フォーマット（よりコンパクト）
    private func formatDateTag(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d(E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    // 候補日の回答状況を計算
    private func getDateResponseStatus(date: Date, event: ScheduleEvent) -> (color: Color, count: Int, hasResponses: Bool) {
        let responses = event.responses
        
        guard !responses.isEmpty else {
            // 回答がない場合
            return (DesignSystem.Colors.secondary, 0, false)
        }
        
        let availableCount = responses.filter { response in
            response.availableDates.contains { Calendar.current.isDate($0, inSameDayAs: date) }
        }.count
        
        let totalResponses = responses.count
        let availableRatio = Double(availableCount) / Double(totalResponses)
        
        // 色を決定（文字色のみ）
        let color: Color
        if availableRatio >= 0.5 {
            color = DesignSystem.Colors.success  // 緑（50%以上）
        } else if availableRatio >= 0.3 {
            color = DesignSystem.Colors.warning  // 黄色（30-50%）
        } else if availableCount > 0 {
            color = DesignSystem.Colors.alert    // 赤（30%未満）
        } else {
            color = DesignSystem.Colors.secondary // グレー（0人）
        }
        
        return (color, availableCount, true)
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
    
    // 文字列からColorを生成するヘルパー関数
    private func colorFromString(_ colorString: String?) -> Color? {
        guard let colorString = colorString, !colorString.isEmpty else { return nil }
        let components = colorString.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard components.count == 3 else { return nil }
        return Color(red: components[0], green: components[1], blue: components[2])
    }
}

// iOS 18のnavigationTransitionを条件付きで適用するためのViewModifier
struct NavigationTransitionModifier: ViewModifier {
    let planId: UUID
    let namespace: Namespace.ID
    
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .navigationTransition(.zoom(sourceID: planId, in: namespace))
        } else {
            content
        }
    }
}

struct CreateViewTransitionModifier: ViewModifier {
    let sourceID: String
    let namespace: Namespace.ID
    
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            content
        }
    }
}

#Preview {
    TopView(selectedTab: .constant(0))
}

