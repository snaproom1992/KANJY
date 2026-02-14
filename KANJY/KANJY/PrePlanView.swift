import SwiftUI
import Combine

// 絵文字の選択肢
private let availableEmojis = ["🍻", "🍺", "🥂", "🍷", "🍸", "🍹", "🍾", "🥃", "🍴", "🍖", "🍗", "🍣", "🍕", "🍔", "🥩", "🍙", "🤮", "🤢", "🥴", "😵", "😵‍💫", "💸", "🎊"]

// Role, RoleType, Participant, CustomRole moved to their own files


struct PrePlanView: View {
    @ObservedObject var viewModel: PrePlanViewModel
    @StateObject private var scheduleViewModel = ScheduleManagementViewModel()
    var planName: String
    var planDate: Date?
    var onFinish: (() -> Void)? = nil
    var initialTask: TaskSection? = nil // 初期表示するタスク
    @Environment(\.dismiss) private var dismiss
    
    init(viewModel: PrePlanViewModel, planName: String, planDate: Date? = nil, initialTask: TaskSection? = nil, onFinish: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.planName = planName
        self.planDate = planDate
        self.initialTask = initialTask
        self.onFinish = onFinish
        _selectedTask = State(initialValue: initialTask ?? .basicInfo)
        // 初期ステップは企画
        // 初期ステップは飲み会前
        _selectedStep = State(initialValue: .before)
    }
    
    // 編集関連の状態
    @State private var editingParticipant: Participant? = nil
    @State private var editingText: String = ""
    @State private var editingRoleType: RoleType = .standard(.staff)
    @State private var showingDeleteAlert = false
    @State private var participantToDelete: Participant? = nil
    @State private var editingHasCollected: Bool = false
    @State private var editingHasFixedAmount: Bool = false
    @State private var editingFixedAmount: Int = 0
    
    // 新規参加者追加用の状態
    @State private var newParticipant: String = ""
    
    // スワイプヒント用の状態
    @State private var showSwipeHint = false
    @State private var swipeHintOffset: CGFloat = 0
    @AppStorage("hasShownEditHint") private var hasShownEditHint: Bool = false
    
    @FocusState private var focusedField: Field?
    
    // 編集用バインディング
    @State private var localPlanName: String = "" {
        didSet {
            scheduleAutoSave()
        }
    }
    @State private var localPlanDate: Date? = nil {
        didSet {
            scheduleAutoSave()
        }
    }
    @State private var localPlanLocation: String = ""
    @State private var localPlanDescription: String = ""
    @State private var isInitialized = false
    @State private var autoSaveWorkItem: DispatchWorkItem?
    // タイトル編集用の状態は PrePlanHeaderView に移動しました

    
    // 金額追加ダイアログ用
    @State private var showAddAmountDialog = false
    @State private var additionalAmount: String = ""
    @State private var additionalItemName: String = ""
    @State private var additionalUseMultiplier: Bool = true
    @State private var additionalSelectedParticipantIds: Set<UUID> = []
    
    // 金額編集ダイアログ用
    @State private var showEditAmountDialog = false
    @State private var editingAmountItem: AmountItem? = nil
    @State private var editingAmount: String = ""
    @State private var editingItemName: String = ""
    @State private var editingUseMultiplier: Bool = true
    @State private var editingSelectedParticipantIds: Set<UUID> = []
    
    // アコーディオン表示制御用（未使用だが互換性のため残す）
    @State private var isBreakdownExpanded: Bool = false
    
    // アイコン選択ダイアログ用
    @State private var showIconPicker = false
    @State private var showColorPicker = false
    
    // 新しい状態変数を追加
    @State private var showPaymentGenerator = false
    
    // スケジュール調整関連の状態変数を追加
    @State private var scheduleEvent: ScheduleEvent?
    @State private var showingScheduleUrlSheet = false
    @State private var showingSchedulePreview = false
    @State private var hasScheduleEvent = false // スケジュール調整済みかどうか
    @State private var showingHelpGuide = false
    @State private var showingUrlPublishedAlert = false
    @State private var showingScheduleUpdatedAlert = false
    
    // スケジュール作成用の状態変数（インライン作成用）
    @State private var isCreatingSchedule = false
    @State private var scheduleTitle = ""
    @State private var scheduleDescription = ""
    @State private var scheduleCandidateDates: [Date] = []
    @State private var scheduleCandidateDatesWithTime: [Date: Bool] = [:] // 各日時に時間を含むかどうか
    @State private var hasTimeForAllCandidates = true // 全候補日時に時間を含むかどうか
    @State private var scheduleLocation = ""
    @State private var scheduleBudget = ""
    @State private var scheduleDeadline: Date?
    @State private var hasScheduleDeadline = false
    @State private var showingScheduleDatePicker = false
    @State private var selectedScheduleDate = Date()
    @State private var selectedScheduleDateHasTime = true // 選択中の日時に時間を含むかどうか
    
    // 開催確定用の状態変数
    @State private var confirmedDate: Date?
    @State private var confirmedLocation: String = ""
    @State private var selectedParticipantIds: Set<UUID> = []
    @State private var showingInvitationGenerator = false
    @State private var showingAddParticipant = false
    @State private var webResponsesCount: Int = 0  // Web回答数
    @State private var showingCopyToast = false  // コピー完了トースト
    
    // Webフォームの回答
    @State private var scheduleResponses: [ScheduleResponse] = []
    @State private var isLoadingResponses = false
    
    // スケジュール編集シート用
    @State private var showScheduleEditSheet = false
    
    // 参加者同期確認用
    @State private var showSyncConfirmation = false
    
    // 2ステップのタブ構造（飲み会前・飲み会後）
    enum MainStep: String, CaseIterable {
        case before = "飲み会前"
        case after = "飲み会後"
        
        var icon: String {
            switch self {
            case .before: return "calendar"
            case .after: return "creditcard.fill"
            }
        }
        
        var description: String {
            switch self {
            case .before: return "企画・調整"
            case .after: return "集金管理"
            }
        }
    }
    
    @State private var selectedStep: MainStep = .before
    @Namespace private var stepTabNamespace
    
    // タスク選択（セグメントコントロール用）- 企画タブ内で使用
    enum TaskSection: String, CaseIterable, Hashable {
        case basicInfo = "１ 基本情報入力"
        case schedule = "２ スケジュール調整"
        
        var icon: String {
            switch self {
            case .basicInfo: return "info.circle.fill"
            case .schedule: return "calendar"
            }
        }
    }
    
    @State private var selectedTask: TaskSection = .basicInfo
    
    enum Field {
        case totalAmount, newParticipant, editParticipant, additionalAmount
    }
    
    // 共通の入力フィールドスタイル
    private func standardInputField<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(height: 44)
            .padding(.horizontal, 16)
    }
    // 参加者個別の支払い案内を生成
    private func generatePaymentInfoForParticipant(_ participant: Participant) {
        // この機能は削除
    }
    
    // 編集シート
    private func editSheet(participant: Participant) -> some View {
        // --- 参加者の全カード合計支払額を計算 ---
        let totalPayment = viewModel.totalPaymentAmount(for: participant)
        let paymentAmountText = totalPayment > 0 ? "¥" + viewModel.formatAmount(String(totalPayment)) : ""
        
        return NavigationStack {
            Form {
                Section {
                    TextField("参加者名", text: $editingText)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.black)
                        .submitLabel(.done)
                    // 役職選択用のビュー
                    rolePickerView
                    
                    // 集金確認用のトグル
                    Toggle("集金済み", isOn: $editingHasCollected)
                        .toggleStyle(SwitchToggleStyle(tint: DesignSystem.Colors.success))
                } header: {
                    Text("参加者情報")
                        .font(DesignSystem.Typography.headline)
                }
                
                Section(header: Text("合計金額").font(DesignSystem.Typography.headline)) {
                    // 金額固定トグル
                    Toggle("金額を固定する", isOn: $editingHasFixedAmount)
                        .toggleStyle(SwitchToggleStyle(tint: DesignSystem.Colors.primary))
                        .onChange(of: editingHasFixedAmount) { _, newValue in
                            if newValue && editingFixedAmount == 0 {
                                // 固定する場合で金額が0なら現在の計算金額をセット
                                let currentPayment = viewModel.totalPaymentAmount(for: participant)
                                if currentPayment > 0 {
                                    editingFixedAmount = currentPayment
                                }
                            }
                        }
                    
                    // 金額固定時の入力フィールド
                    if editingHasFixedAmount {
                        HStack {
                            Text("固定金額")
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.black)
                            Spacer()
                            TextField("金額", text: Binding(
                                get: { viewModel.formatAmount(String(editingFixedAmount)) },
                                set: { newValue in
                                    if let amount = Int(newValue.filter { $0.isNumber }), amount >= 0 {
                                        editingFixedAmount = amount
                                    }
                                }
                            ))
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.black)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.blue)
                            Text("円")
                        }
                    } else {
                        HStack {
                            Text("計算金額")
                            Spacer()
                            Text(paymentAmountText)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Section {
                    Button(action: { confirmDelete(participant: participant) }) {
                        HStack {
                            Spacer()
                            Text("この参加者を削除")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
                
                Section {
                    HStack {
                        Button("キャンセル") {
                            editingParticipant = nil
                        }
                        .foregroundColor(.red)
                        Spacer()
                        Button("保存") {
                            viewModel.updateParticipant(
                                participant, 
                                name: editingText, 
                                roleType: editingRoleType, 
                                hasCollected: editingHasCollected,
                                hasFixedAmount: editingHasFixedAmount,
                                fixedAmount: editingFixedAmount
                            )
                            editingParticipant = nil
                        }
                        .disabled(editingText.isEmpty)
                    }
                }
            }
            .navigationTitle("参加者を編集")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    // 役職選択用のビュー
    private var rolePickerView: some View {
        Picker("役職", selection: $editingRoleType) {
            // 標準役職
            ForEach(Role.allCases) { role in
                Text("\(role.name) ×\(String(format: "%.1f", role.defaultMultiplier))")
                    .tag(RoleType.standard(role))
            }
            
            // カスタム役職
            if !viewModel.customRoles.isEmpty {
                Divider()
                ForEach(viewModel.customRoles) { role in
                    Text("\(role.name) ×\(String(format: "%.1f", role.multiplier))")
                        .tag(RoleType.custom(role))
                }
            }
        }
    }
    
    // 編集開始
    private func startEdit(_ participant: Participant) {
        editingText = participant.name
        editingRoleType = participant.roleType
        editingHasCollected = participant.hasCollected
        editingHasFixedAmount = participant.hasFixedAmount
        editingFixedAmount = participant.fixedAmount
        editingParticipant = participant
    }
    
    // 削除確認
    private func confirmDelete(participant: Participant) {
        participantToDelete = participant
        showingDeleteAlert = true
    }
    
    // スワイプヒントアニメーション
    private func showSwipeHintAnimation() {
        guard !hasShownEditHint else { return }
        
        showSwipeHint = false
        swipeHintOffset = 50
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.5)) {
                showSwipeHint = true
                swipeHintOffset = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut(duration: 0.8)) {
                    swipeHintOffset = -30
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        swipeHintOffset = 0
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showSwipeHint = false
                        }
                        hasShownEditHint = true
                    }
                }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            contentWithStateLogic
                .planSync(
                    viewModel: viewModel,
                    localPlanLocation: $localPlanLocation,
                    localPlanDescription: $localPlanDescription,
                    scheduleEvent: $scheduleEvent,
                    scheduleTitle: $scheduleTitle,
                    scheduleDescription: $scheduleDescription,
                    scheduleCandidateDates: $scheduleCandidateDates,
                    scheduleLocation: $scheduleLocation,
                    scheduleBudget: $scheduleBudget
                )
        }
    }

    @ViewBuilder
    private var contentWithBaseSheets: some View {
        mainContent
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingHelpGuide = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: RoleSettingsView(viewModel: viewModel, selectedRole: .constant(nil))) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingHelpGuide) {
                HelpGuideView()
            }
            .sheet(item: $editingParticipant) { participant in
                editSheet(participant: participant)
            }
            .sheet(isPresented: $showAddAmountDialog) {
                AddAmountDialogView()
            }
            .sheet(item: $editingAmountItem) { item in
                EditAmountDialogView(item: item)
            }
            .sheet(isPresented: $showPaymentGenerator) {
                NavigationStack {
                    PaymentInfoGenerator(viewModel: viewModel)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingScheduleUrlSheet) {
                if let event = scheduleEvent {
                    EventUrlSheet(event: event, viewModel: scheduleViewModel) {
                        showingScheduleUrlSheet = false
                    }
                }
            }
            .alert("URLを発行しました", isPresented: $showingUrlPublishedAlert) {
                if let webUrl = scheduleEvent?.webUrl {
                    Button("URLをコピー") {
                        UIPasteboard.general.string = webUrl
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                }
                Button("OK", role: .cancel) { }
            } message: {
                if let webUrl = scheduleEvent?.webUrl {
                    Text(webUrl)
                        .font(.system(.caption, design: .monospaced))
                } else {
                    Text("URLをコピーして共有できます")
                }
            }
    }

    @ViewBuilder
    private var contentWithScheduleSheets: some View {
        contentWithBaseSheets
            .sheet(isPresented: $showingAddParticipant) {
                NavigationStack {
                    Form {
                        let existingNames = Set(viewModel.participants.map { $0.name })
                        let availableRespondents = scheduleResponses.filter { !existingNames.contains($0.participantName) }
                        
                        if !availableRespondents.isEmpty {
                            Section("回答者から追加") {
                                ForEach(availableRespondents) { response in
                                    Button(action: {
                                        viewModel.addParticipant(name: response.participantName, roleType: .standard(.staff))
                                        showingAddParticipant = false
                                    }) {
                                        HStack {
                                            Image(systemName: response.status.icon)
                                                .foregroundColor(response.status.color)
                                            Text(response.participantName)
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Image(systemName: "plus.circle")
                                                .foregroundColor(DesignSystem.Colors.primary)
                                        }
                                    }
                                }
                            }
                        }
                        
                        Section("回答者以外から追加") {
                            TextField("参加者名", text: $viewModel.newParticipantName)
                                .submitLabel(.done)
                        }
                        Section("役職") {
                            Picker("役職", selection: $viewModel.selectedRoleType) {
                                ForEach(Role.allCases) { role in
                                    Text(role.name).tag(RoleType.standard(role))
                                }
                            }
                        }
                    }
                    .navigationTitle("参加者を追加")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("キャンセル") { showingAddParticipant = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("追加") {
                                viewModel.addParticipant(name: viewModel.newParticipantName, roleType: viewModel.selectedRoleType)
                                viewModel.newParticipantName = ""
                                showingAddParticipant = false
                            }
                            .disabled(viewModel.newParticipantName.isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .alert("公開中の内容を更新しました", isPresented: $showingScheduleUpdatedAlert) {
                Button("OK") { }
            } message: {
                Text("既に共有したURLはそのまま使用できます")
            }
            .sheet(isPresented: $showScheduleEditSheet) {
                NavigationStack {
                    ZStack {
                        Color.clear.background(.ultraThinMaterial)
                        ScrollView {
                            VStack(spacing: DesignSystem.Spacing.lg) {
                                ScheduleCreationFormView()
                                    .padding(.horizontal, DesignSystem.Spacing.lg)
                                    .padding(.vertical, DesignSystem.Spacing.md)
                            }
                            .padding(.bottom, DesignSystem.Spacing.xxl)
                        }
                    }
                    .navigationTitle("スケジュール編集")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("キャンセル") { showScheduleEditSheet = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
            }
            .sheet(isPresented: $showingSchedulePreview) {
                SchedulePreviewSheet(
                    scheduleEvent: scheduleEvent,
                    scheduleTitle: scheduleTitle,
                    scheduleDescription: scheduleDescription,
                    scheduleCandidateDates: scheduleCandidateDates,
                    scheduleLocation: scheduleLocation,
                    scheduleBudget: scheduleBudget,
                    scheduleViewModel: scheduleViewModel
                )
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerView()
            }
    }
    
    @ViewBuilder
    private var contentWithStateLogic: some View {
        contentWithScheduleSheets
            .onAppear {
                setupInitialState()
                loadScheduleEvent()
            }
            .onChange(of: viewModel.participants.count) { _, newCount in
                handleParticipantsCountChange(newCount: newCount)
            }
            .onChange(of: localPlanLocation) { _, _ in
                scheduleAutoSave()
            }
            .onChange(of: localPlanDescription) { _, _ in
                scheduleAutoSave()
            }
            .onDisappear {
                autoSaveWorkItem?.cancel()
                autoSavePlan()
            }
            .alert("参加者を削除", isPresented: $showingDeleteAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {
                    if let participant = participantToDelete {
                        viewModel.deleteParticipant(participant)
                        participantToDelete = nil
                        editingParticipant = nil
                    }
                }
            } message: {
                if let participant = participantToDelete {
                    Text("\(participant.name)を削除しますか？")
                } else {
                    Text("この参加者を削除しますか？")
                }
            }
    }


    

    
    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            MainContentView()
            
            // コピー完了トースト
            if showingCopyToast {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DesignSystem.Colors.white)
                        Text("クリップボードにコピーしました")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.white)
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                            .fill(DesignSystem.Colors.black.opacity(0.8))
                    )
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("")
    }
    
    // 初期状態の設定
    private func setupInitialState() {
        guard !isInitialized else {
            print("setupInitialState: Already initialized, skipping")
            return
        }
        
        localPlanName = viewModel.editingPlanName
        localPlanDate = viewModel.editingPlanDate
        localPlanLocation = viewModel.editingPlanLocation
        localPlanDescription = viewModel.editingPlanDescription
        
        // 確定日時などの読み込み
        if let id = viewModel.editingPlanId, let _ = viewModel.savedPlans.first(where: { $0.id == id }) {
             // 確定情報の読み込み（ViewModelにはないがPlanにはある場合）
             // 注: ViewModelのsavePlanでconfirmedDateなどは引数で渡す設計
        }
        
        isInitialized = true
        
        if !hasShownEditHint && !viewModel.participants.isEmpty {
            showSwipeHintAnimation()
        }
        
        // アイコンと絵文字の初期化 - 新規作成時のみ
        print("初期化前のアイコン: \(viewModel.selectedIcon ?? "nil")")
        print("初期化前の絵文字: \(viewModel.selectedEmoji)")
        
        // 新規作成時のみデフォルトアイコンを設定
        if viewModel.editingPlanId == nil {
            if viewModel.selectedIcon == nil && viewModel.selectedEmoji.isEmpty {
                // デフォルトアイコンを設定
                viewModel.selectedIcon = "wineglass.fill"
                print("新規作成: アイコンを初期化: wineglass.fill")
            }
        } else {
            // 編集時は既存の値をそのまま使用
            if let icon = viewModel.selectedIcon {
                print("編集モード: 既存のアイコンを使用: \(icon)")
            } else {
                print("編集モード: 既存の絵文字を使用: \(viewModel.selectedEmoji)")
            }
        }
        
        // 内訳が少ない場合は最初から展開しておく
        isBreakdownExpanded = viewModel.amountItems.count <= 3
    }
    
    // スケジュールイベントの読み込み
    private func loadScheduleEvent() {
        Task {
            // Supabaseから最新のイベントを取得
            await scheduleViewModel.fetchEventsFromSupabase()
            
            await MainActor.run {
                // 編集時は、PlanのscheduleEventIdからスケジュールイベントを取得
                if let planId = viewModel.editingPlanId,
                   let plan = viewModel.savedPlans.first(where: { $0.id == planId }),
                   let scheduleEventId = plan.scheduleEventId {
                    scheduleEvent = scheduleViewModel.events.first { $0.id == scheduleEventId }
                    hasScheduleEvent = scheduleEvent != nil
                    
                    // 開催日時を復元
                    confirmedDate = plan.confirmedDate
                    
                    // 回答も取得
                    if hasScheduleEvent {
                        loadScheduleResponses(eventId: scheduleEventId)
                    }
                } else {
                    // 新規作成時はスケジュールイベントなし
                    scheduleEvent = nil
                    hasScheduleEvent = false
                    scheduleResponses = []
                }
            }
        }
    }
    
    // Webフォームの回答を取得
    private func loadScheduleResponses(eventId: UUID) {
        isLoadingResponses = true
        Task {
            do {
                let responses = try await AttendanceManager.shared.fetchResponsesFromSupabase(eventId: eventId)
                await MainActor.run {
                    scheduleResponses = responses
                    // scheduleEventのresponsesも更新して、候補日時の人数計算に反映させる
                    scheduleEvent?.responses = responses
                    
                    isLoadingResponses = false
                    
                    // 初回ロード時に参加者リストが空の場合は同期する
                    if viewModel.participants.isEmpty {
                        print("初回ロード: 参加者が空のため同期を実行します")
                        viewModel.syncParticipants(from: responses, date: confirmedDate)
                    }
                }
            } catch {
                print("回答取得エラー: \(error)")
                await MainActor.run {
                    isLoadingResponses = false
                }
            }
        }
    }
    
    // 参加者数変更時の処理
    private func handleParticipantsCountChange(newCount: Int) {
        if newCount > 0 && !hasShownEditHint {
            DispatchQueue.main.async {
                showSwipeHintAnimation()
            }
        }
    }
    
    // 金額追加処理
    private func addAmount() {
        guard !additionalAmount.isEmpty else { return }
        
        // 数字のみを抽出
        let numbers = additionalAmount.filter { $0.isNumber }
        if let amount = Int(numbers) {
            // 項目名（空の場合はデフォルト名を設定）
            let itemName = additionalItemName.isEmpty ? "追加のお会計" : additionalItemName
            
            // 参加者IDの配列（全員選択の場合はnil）
            let participantIds: [UUID]? = additionalSelectedParticipantIds.count == viewModel.participants.count ? nil : Array(additionalSelectedParticipantIds)
            
            // お会計カードを追加
            viewModel.addAmountItem(name: itemName, amount: amount, participantIds: participantIds, useMultiplier: additionalUseMultiplier)
            
            // 入力欄をクリア
            additionalAmount = ""
            additionalItemName = ""
        }
    }
    
    // 金額編集開始
    private func startEditingAmount(_ item: AmountItem) {
        editingAmountItem = item
        editingItemName = item.name
        editingAmount = viewModel.formatAmount(String(item.amount))
        editingUseMultiplier = item.useMultiplier
        if let ids = item.participantIds {
            editingSelectedParticipantIds = Set(ids)
        } else {
            editingSelectedParticipantIds = Set(viewModel.participants.map { $0.id })
        }
    }
    
    // 金額更新処理
    private func updateAmount() {
        guard let item = editingAmountItem, !editingAmount.isEmpty else { return }
        
        // 数字のみを抽出
        let numbers = editingAmount.filter { $0.isNumber }
        if let amount = Int(numbers) {
            // 項目名（空の場合はデフォルト名を設定）
            let itemName = editingItemName.isEmpty ? "お会計" : editingItemName
            
            // 参加者IDの配列（全員選択の場合はnil）
            let participantIds: [UUID]? = editingSelectedParticipantIds.count == viewModel.participants.count ? nil : Array(editingSelectedParticipantIds)
            
            // お会計カードを更新
            viewModel.updateAmountItem(id: item.id, name: itemName, amount: amount, participantIds: participantIds, useMultiplier: editingUseMultiplier)
        }
    }
    
    // お会計カード削除
    private func deleteAmountItem(at offsets: IndexSet) {
        viewModel.removeAmountItems(at: offsets)
    }
    
    // メインコンテンツビュー
    private func MainContentView() -> some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                // 絵文字と飲み会名の行（リファクタリング済み）
                PrePlanHeaderView(
                    viewModel: viewModel,
                    localPlanName: $localPlanName,
                    showIconPicker: $showIconPicker
                )
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.md)
                
                // 🎨 ステップタブ + コンテンツ：2つのステップで分ける
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // ステップタブコントロール
                    MainStepTabControl(selectedStep: $selectedStep)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                
                    // 選択されたステップのコンテンツ
                    MainStepContentView(selectedStep: selectedStep)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                }
                .padding(.bottom, DesignSystem.Spacing.xxxl * 3) // 下部ボタン用のスペース
            }
            .padding(.top, DesignSystem.Spacing.xxl)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .safeAreaInset(edge: .bottom) {
            SaveButton()
        }
    }
    
    // アイコンボタン、飲み会名ビューは PrePlanHeaderView に移動しました
    
    // サマリーカード（重要情報を集約）
    @ViewBuilder
    private func SummaryCard() -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // タイトル（控えめに）
            HStack {
                Text("サマリー")
                    .font(DesignSystem.Typography.emphasizedSubheadline)
                    .foregroundColor(DesignSystem.Colors.secondary)
                Spacer()
            }
            
            // グリッドレイアウトで重要情報を表示
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignSystem.Spacing.sm) {
                // 開催日（確定日時があれば表示）
                SummaryItem(
                    icon: "calendar",
                    label: "開催日",
                    value: summaryConfirmedDateText
                )
                
                // 参加者数（Webフォームの回答から）
                SummaryItem(
                    icon: "person.2.fill",
                    label: "参加者",
                    value: summaryParticipantCountText
                )
                
                // 合計金額
                SummaryItem(
                    icon: "yensign.circle.fill",
                    label: "合計金額",
                    value: summaryTotalAmountText
                )
                
                // 集金状況（Webフォームの回答から）
                SummaryItem(
                    icon: "creditcard.fill",
                    label: "集金状況",
                    value: summaryCollectionStatusText
                )
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
    
    // サマリー用のcomputed properties
    private var summaryConfirmedDateText: String {
        confirmedDate != nil ? scheduleViewModel.formatDateTime(confirmedDate!) : "未設定"
    }
    
    private var summaryParticipantCountText: String {
        if let confirmedDate = confirmedDate {
            let attendingCount = attendingResponsesForDate(confirmedDate).count
            return "\(attendingCount)人"
        } else {
            let attendingCount = scheduleResponses.filter { $0.status == .attending }.count
            return attendingCount > 0 ? "\(attendingCount)人" : "未回答"
        }
    }
    
    private var summaryTotalAmountText: String {
        viewModel.totalAmountValue > 0 ? "¥\(viewModel.formatAmount(String(viewModel.totalAmountValue)))" : "未設定"
    }
    
    private var summaryCollectionStatusText: String {
        let targetResponses = targetResponsesForCollection
        let totalCount = targetResponses.count
        if totalCount == 0 {
            return "未回答"
        } else {
            return "\(totalCount)人回答"
        }
    }
    
    // 特定日時に参加と回答した人を取得
    private func attendingResponsesForDate(_ date: Date) -> [ScheduleResponse] {
        scheduleResponses.filter { response in
            response.status == .attending && response.availableDates.contains { responseDate in
                Calendar.current.isDate(responseDate, inSameDayAs: date)
            }
        }
    }
    
    // 集金対象の回答を取得
    private var targetResponsesForCollection: [ScheduleResponse] {
        if let confirmedDate = confirmedDate {
            return attendingResponsesForDate(confirmedDate)
        } else {
            return scheduleResponses.filter { $0.status == .attending }
        }
    }
    
    // 確定日時に基づいて利用可能な参加者を取得
    private var availableParticipantsForEvent: [ScheduleResponse] {
        if let confirmedDate = confirmedDate {
            return attendingResponsesForDate(confirmedDate)
        } else {
            return scheduleResponses.filter { $0.status == .attending }
        }
    }
    
    // 開催ステップの参加者リストコンテンツ
    @ViewBuilder
    private func EventParticipantsListContent() -> some View {
        let availableParticipants = availableParticipantsForEvent
        
        if availableParticipants.isEmpty {
            if confirmedDate != nil {
                Text("この日時に参加可能な人はいません")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .padding(.vertical, DesignSystem.Spacing.sm)
            } else {
                Text("確定日時を設定すると、参加可能な人が表示されます")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .padding(.vertical, DesignSystem.Spacing.sm)
            }
        } else {
            // 全員選択ボタン
            Button(action: {
                selectedParticipantIds = Set(availableParticipants.map { $0.id })
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.success)
                    Text("全員選択（\(availableParticipants.count)人）")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
            .padding(.bottom, DesignSystem.Spacing.xs)
            
            // 参加者リスト
            ForEach(availableParticipants) { response in
                EventParticipantRow(response: response)
            }
        }
    }
    
    // 参加者行のビュー
    @ViewBuilder
    private func EventParticipantRow(response: ScheduleResponse) -> some View {
        HStack {
            Button(action: {
                if selectedParticipantIds.contains(response.id) {
                    selectedParticipantIds.remove(response.id)
                } else {
                    selectedParticipantIds.insert(response.id)
                }
            }) {
                HStack {
                    Image(systemName: selectedParticipantIds.contains(response.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(selectedParticipantIds.contains(response.id) ? DesignSystem.Colors.success : DesignSystem.Colors.gray4)
                    Text(response.participantName)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.black)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
    
    // サマリー項目（情報に強弱をつける）
    @ViewBuilder
    private func SummaryItem(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // ラベル（小さく、控えめに）
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.Icon.Size.small, weight: DesignSystem.Typography.FontWeight.medium))
                    .foregroundColor(DesignSystem.Colors.secondary)
                Text(label)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(DesignSystem.Colors.secondary)
            }
            
            // 値（大きく、強調）
            Text(value)
                .font(DesignSystem.Typography.emphasizedTitle)
                .foregroundColor(value.contains("未設定") ? DesignSystem.Colors.secondary : DesignSystem.Colors.black)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                .fill(DesignSystem.Colors.background)
        )
    }
    
    // 触覚フィードバック生成
    private func stepTabHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    // メインステップタブコントロール（リキッドレイアウト・タブ）
    @ViewBuilder
    private func MainStepTabControl(selectedStep: Binding<MainStep>) -> some View {
        HStack(spacing: 0) {
            ForEach(MainStep.allCases, id: \.self) { step in
                let isSelected = selectedStep.wrappedValue == step
                
                Button {
                    guard selectedStep.wrappedValue != step else { return }
                    stepTabHaptic()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75, blendDuration: 0.2)) {
                        selectedStep.wrappedValue = step
                    }
                } label: {
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: step.icon)
                            .font(.system(size: DesignSystem.Icon.Size.medium, weight: DesignSystem.Typography.FontWeight.semibold))
                            .foregroundColor(isSelected ? DesignSystem.Colors.white : DesignSystem.Colors.primary)
                            .scaleEffect(isSelected ? 1.15 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isSelected)
                        
                        Text(step.rawValue)
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(isSelected ? DesignSystem.Colors.white : DesignSystem.Colors.black)
                        
                        Text(step.description)
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(isSelected ? DesignSystem.Colors.white.opacity(0.9) : DesignSystem.Colors.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .background(
                        Group {
                            if isSelected {
                                RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadius, style: .continuous)
                                    .fill(DesignSystem.Colors.primary)
                                    .matchedGeometryEffect(id: "stepTabBackground", in: stepTabNamespace)
                                    .shadow(
                                        color: DesignSystem.Colors.primary.opacity(0.3),
                                        radius: 8, x: 0, y: 4
                                    )
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadius + 2, style: .continuous)
                .fill(DesignSystem.Colors.secondaryBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadius + 2, style: .continuous)
                .stroke(DesignSystem.Colors.gray3.opacity(0.5), lineWidth: 1)
        )
    }
    
    // メインステップコンテンツビュー（2ステップ：飲み会前・飲み会後）
    @ViewBuilder
    private func MainStepContentView(selectedStep: MainStep) -> some View {
        Group {
            switch selectedStep {
            case .before:
                // 飲み会前（企画）：日程調整・参加者・基本情報（統合済み）
                ScheduleAndParticipantsCardView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            case .after:
                // 飲み会後（集金）：金額設定・集金管理
                CollectionStepContent()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedStep)
    }
    
    // 企画ステップのコンテンツ
    @ViewBuilder
    private func PlanningStepContent() -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // 企画タブ内のサブタブ
            TaskSegmentControl(selectedTask: $selectedTask)
            
            // 選択されたタスクのコンテンツを表示
            TaskContentView(selectedTask: selectedTask)
        }
    }
    
    // 開催ステップのコンテンツ
    @ViewBuilder
    private func EventStepContent() -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // 確定日時
            InfoCard(
                title: "確定日時",
                icon: "calendar.badge.checkmark"
            ) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    if let date = confirmedDate {
                        HStack {
                            Text(scheduleViewModel.formatDateTime(date))
                                .font(DesignSystem.Typography.headline)
                                .foregroundColor(DesignSystem.Colors.black)
                            Spacer()
                            Button(action: {
                                confirmedDate = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(DesignSystem.Colors.alert)
                            }
                        }
                    } else {
                        // スケジュール調整の結果から選択
                        if hasScheduleEvent, let event = scheduleEvent, let optimalDate = event.optimalDate {
                            Button(action: {
                                confirmedDate = optimalDate
                            }) {
                                HStack {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(DesignSystem.Colors.warning)
                                    Text("最適日時を確定: \(scheduleViewModel.formatDateTime(optimalDate))")
                                        .font(DesignSystem.Typography.body)
                                        .foregroundColor(DesignSystem.Colors.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(DesignSystem.Colors.secondary)
                                }
                                .padding(DesignSystem.Spacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                                        .fill(DesignSystem.Colors.warning.opacity(0.1))
                                )
                            }
                        }
                        
                        // 手動で日時を選択
                        DatePicker("日時を選択", selection: Binding(
                            get: { confirmedDate ?? (localPlanDate ?? planDate ?? Date()) },
                            set: { confirmedDate = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                        .font(DesignSystem.Typography.body)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                    }
                }
            }
            
            // 確定場所
            InfoCard(
                title: "確定場所",
                icon: "location.fill"
            ) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    TextField("場所を入力", text: $confirmedLocation)
                        .standardTextFieldStyle()
                        .submitLabel(.done)
                    
                    // スケジュール調整から場所を引き継ぐ
                    if hasScheduleEvent, let event = scheduleEvent, let location = event.location, confirmedLocation.isEmpty {
                        Button(action: {
                            confirmedLocation = location
                        }) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(DesignSystem.Colors.primary)
                                Text("スケジュール調整から引き継ぐ: \(location)")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.primary)
                            }
                        }
                    }
                }
            }
            
            // 確定参加者（Webフォームの回答から）
            InfoCard(
                title: "確定参加者",
                icon: "person.2.fill"
            ) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    if isLoadingResponses {
                        HStack {
                            ProgressView()
                            Text("回答を読み込み中...")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(DesignSystem.Colors.secondary)
                        }
                        .padding(.vertical, DesignSystem.Spacing.sm)
                    } else if scheduleResponses.isEmpty {
                        Text("まだ回答がありません")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondary)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                        Text("スケジュール調整のURLを配布して、参加者に回答してもらいましょう")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondary)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                    } else {
                        EventParticipantsListContent()
                    }
                }
            }
            
            // 開催案内作成ボタン
            if confirmedDate != nil && !selectedParticipantIds.isEmpty {
                Button(action: {
                    showingInvitationGenerator = true
                }) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(DesignSystem.Colors.white)
                        Text("開催案内を作成")
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(DesignSystem.Button.Padding.vertical)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                            .fill(DesignSystem.Colors.primary)
                    )
                }
            }
        }
        .onAppear {
            // 既存の確定情報を読み込む
            if let planId = viewModel.editingPlanId,
               let plan = viewModel.savedPlans.first(where: { $0.id == planId }) {
                confirmedDate = plan.confirmedDate
                confirmedLocation = plan.confirmedLocation ?? ""
                selectedParticipantIds = Set(plan.confirmedParticipants ?? [])
            }
        }
        .onChange(of: confirmedDate) { _, _ in
            // 確定情報が変更されたら保存
            viewModel.saveConfirmedInfo(
                confirmedDate: confirmedDate,
                confirmedLocation: confirmedLocation.isEmpty ? nil : confirmedLocation,
                confirmedParticipants: Array(selectedParticipantIds)
            )
            // 確定日時が変更されたら回答を再取得
            if let scheduleEventId = scheduleEvent?.id {
                loadScheduleResponses(eventId: scheduleEventId)
            }
        }
        .onChange(of: confirmedLocation) { _, _ in
            // 確定情報が変更されたら保存
            viewModel.saveConfirmedInfo(
                confirmedDate: confirmedDate,
                confirmedLocation: confirmedLocation.isEmpty ? nil : confirmedLocation,
                confirmedParticipants: Array(selectedParticipantIds)
            )
        }
        .onChange(of: selectedParticipantIds) { _, _ in
            // 確定情報が変更されたら保存
            viewModel.saveConfirmedInfo(
                confirmedDate: confirmedDate,
                confirmedLocation: confirmedLocation.isEmpty ? nil : confirmedLocation,
                confirmedParticipants: Array(selectedParticipantIds)
            )
        }
        .sheet(isPresented: $showingInvitationGenerator) {
            if let confirmedDate = confirmedDate, !selectedParticipantIds.isEmpty {
                // Webフォームの回答から参加者を取得
                let confirmedResponses = scheduleResponses.filter { selectedParticipantIds.contains($0.id) }
                // ScheduleResponseからParticipantに変換（名前のみ）
                let confirmedParticipants = confirmedResponses.map { response in
                    Participant(
                        name: response.participantName,
                        roleType: .standard(.staff) // デフォルト値（集金計算には使用しない）
                    )
                }
                EventInvitationGenerator(
                    viewModel: viewModel,
                    confirmedDate: confirmedDate,
                    confirmedLocation: confirmedLocation.isEmpty ? nil : confirmedLocation,
                    confirmedParticipants: confirmedParticipants,
                    planName: localPlanName.isEmpty ? planName : localPlanName,
                    planEmoji: viewModel.selectedIcon ?? viewModel.selectedEmoji
                )
            }
        }
    }
    
    // 集金ステップのコンテンツ
    @ViewBuilder
    private func CollectionStepContent() -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // お会計カード一覧
            ForEach(Array(viewModel.amountItems.enumerated()), id: \.element.id) { index, item in
                PaymentCardView(item: item, index: index)
            }
            
            // お会計を追加ボタン（カードを追加するだけ）
            Button(action: {
                withAnimation {
                    viewModel.addAmountItem(name: "追加のお会計", amount: 0, participantIds: nil, useMultiplier: true)
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                    Text("お会計を追加")
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                }
                .foregroundColor(DesignSystem.Colors.primary)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DesignSystem.Colors.primary.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
                )
            }
            
            // 合計サマリー（カードが2枚以上の場合のみ表示）
            if viewModel.amountItems.count >= 2 {
                PaymentSummaryView()
            }
            
            // 集金管理セクション
            InfoCard(
                title: "集金管理",
                icon: "creditcard",
                isOptional: true
            ) {
                PrePlanParticipantListView(
                    viewModel: viewModel,
                    confirmedDate: confirmedDate,
                    editingParticipant: $editingParticipant,
                    showingAddParticipant: $showingAddParticipant,
                    showPaymentGenerator: $showPaymentGenerator
                )
            }
        }
        .onAppear {
            viewModel.ensureMainAmountItem()
        }
    }
    
    // タスクセグメントコントロール（企画タブ内で使用）
    @ViewBuilder
    private func TaskSegmentControl(selectedTask: Binding<TaskSection>) -> some View {
        Picker("", selection: selectedTask) {
            ForEach(TaskSection.allCases, id: \.self) { task in
                Text(task.rawValue)
                    .font(.system(size: 20, weight: .semibold))
                    .tag(task)
            }
        }
        .pickerStyle(.segmented)
        .frame(height: 64) // タブの高さをさらに高くして存在感を出す
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
    
    // タスクコンテンツビュー
    @ViewBuilder
    private func TaskContentView(selectedTask: TaskSection) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            switch selectedTask {
            case .basicInfo:
                PrePlanBasicInfoView(
                    viewModel: viewModel,
                    onAutoSave: { autoSavePlan() }
                )
                
            case .schedule:
                ScheduleSectionContent()
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
    }
    
    // MARK: - 🎨 カード式ビュー
    
    // 👤 参加者行ビュー
    // ParticipantRow moved to PrePlanParticipantListView.swift
    
    // 📋 基本情報カード
    @ViewBuilder
    private func BasicInfoCardView() -> some View {
        InfoCard(
            title: "基本情報",
            icon: "info.circle.fill"
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // 場所
                SimpleInfoRow(
                    icon: "location.fill",
                    value: $viewModel.editingPlanLocation,
                    placeholder: "場所を追加"
                )
                
                // 説明
                SimpleInfoRow(
                    icon: "text.alignleft",
                    value: $viewModel.editingPlanDescription,
                    placeholder: "メモを追加",
                    isMultiline: true
                )
            }
        }
    }
    
    // 📅👥 日程＆参加者カード（統合）
    @ViewBuilder
    private func ScheduleAndParticipantsCardView() -> some View {
        VStack(spacing: DesignSystem.Spacing.xxl) {
            
            // 案内テキスト（タブとカードの間）
            if hasScheduleEvent {
                Text("QRコードをスキャンまたはタップすると調整用Webページが開きます")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, DesignSystem.Spacing.sm)
                    .padding(.bottom, -DesignSystem.Spacing.lg) // 下のカードとの隙間を詰める
            }

            // 🔗 URL・プレビュー・編集カード（一番上、独立）
            if hasScheduleEvent, let event = scheduleEvent {
                ScheduleUrlAndActionsCardView(
                    event: event,
                    webResponsesCount: webResponsesCount,
                    onShowUrl: {
                        showingScheduleUrlSheet = true
                    },
                    onPreview: {
                        showingSchedulePreview = true
                    },
                    onSyncResponses: {
                        Task {
                            await syncWebResponses()
                        }
                    }
                )
            }
            
            // 📊 統合情報カード（候補日時・回答者・基本情報を1つに）
            VStack(spacing: 8) {
                // 案内テキスト & 更新ボタン（カードの上、同じ行）
                if hasScheduleEvent {
                    HStack(alignment: .bottom) {
                        Text("回答状況は下のセクションで確認できます")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            Task {
                                await syncWebResponses()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("回答を更新")
                            }
                            .font(DesignSystem.Typography.caption.weight(.semibold))
                            .foregroundColor(DesignSystem.Colors.primary)
                        }
                    }
                    .padding(.top, DesignSystem.Spacing.sm)
                    .padding(.horizontal, DesignSystem.Spacing.sm) // 少し余白追加
                }
                
                VStack(spacing: 0) {
                // 📅 候補日時セクション
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    // セクションヘッダー
                    HStack {
                        Image(systemName: "calendar")
                            .font(.system(size: DesignSystem.Icon.Size.medium, weight: DesignSystem.Typography.FontWeight.medium))
                            .foregroundColor(DesignSystem.Colors.primary)
                        Text("候補日時")
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.black)
                        
                        Spacer()
                        
                        // 編集ボタン（テキスト付き）
                        Button(action: {
                            if hasScheduleEvent, let event = scheduleEvent {
                                startEditingScheduleForSheet(event: event)
                                showScheduleEditSheet = true
                            } else {
                                prepareScheduleForEditing()
                                showScheduleEditSheet = true
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 12, weight: .medium))
                                Text("編集")
                                    .font(DesignSystem.Typography.caption)
                            }
                            .foregroundColor(DesignSystem.Colors.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(DesignSystem.Colors.primary.opacity(0.1))
                            )
                        }
                    }
                    
                    // 候補日時リスト
                    if hasScheduleEvent, let event = scheduleEvent {
                        // 締切がある場合は表示
                        if let deadline = event.deadline {
                            let isPassed = Date() > deadline
                            Text(getDeadlineText(deadline: deadline))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(isPassed ? DesignSystem.Colors.gray6 : DesignSystem.Colors.Attendance.notAttending)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(isPassed ? DesignSystem.Colors.gray3.opacity(0.3) : DesignSystem.Colors.Attendance.notAttending.opacity(0.1))
                                )
                                .padding(.bottom, DesignSystem.Spacing.sm)
                        }

                        CandidateDatesListView(
                            event: event,
                            scheduleViewModel: scheduleViewModel,
                            confirmedDate: $confirmedDate
                        )
                    } else {
                        PrePlanScheduleEmptyStateView(
                            candidateDatesCount: scheduleCandidateDates.count,
                            onEdit: {
                                prepareScheduleForEditing()
                                showScheduleEditSheet = true
                            },
                            onPreview: {
                                createPreviewEvent()
                            }
                        )
                    }
                }
                .padding(DesignSystem.Spacing.lg)
                
                // ──── 罫線 ────
                Divider()
                    .padding(.vertical, DesignSystem.Spacing.md)
                
                // 👥 回答者一覧セクション
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    // セクションヘッダー
                    HStack {
                        Image(systemName: "person.2")
                            .font(.system(size: DesignSystem.Icon.Size.medium, weight: DesignSystem.Typography.FontWeight.medium))
                            .foregroundColor(DesignSystem.Colors.primary)
                        Text("回答者一覧")
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.black)
                        
                        Spacer()
                        
                        // 回答者数
                        Text("\(scheduleResponses.count)人")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondary)
                    }
                    
                    // 回答者リスト
                    if scheduleResponses.isEmpty {
                        Text("まだ回答がありません")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.lg)
                    } else {
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(scheduleResponses) { response in
                                HStack {
                                    // 開催日程が決まっている場合、参加可能な回答者にチェックを表示
                                    if let confirmedDate = confirmedDate {
                                        let isAvailable = attendingResponsesForDate(confirmedDate).contains { $0.id == response.id }
                                        Image(systemName: isAvailable ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(isAvailable ? DesignSystem.Colors.success : DesignSystem.Colors.gray4)
                                    }
                                    
                                    Text(response.participantName)
                                        .font(DesignSystem.Typography.body)
                                        .foregroundColor(DesignSystem.Colors.black)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, DesignSystem.Spacing.sm)
                            }
                        }
                    }
                }
                .padding(DesignSystem.Spacing.lg)
                
                // ──── 罫線 ────
                Divider()
                    .padding(.vertical, DesignSystem.Spacing.md)
                
                // 📋 基本情報セクション
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    // セクションヘッダー
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.system(size: DesignSystem.Icon.Size.medium, weight: DesignSystem.Typography.FontWeight.medium))
                            .foregroundColor(DesignSystem.Colors.primary)
                        Text("基本情報")
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.black)
                    }
                    
                    // 場所
                    SimpleInfoRow(
                        icon: "location.fill",
                        value: $localPlanLocation,
                        placeholder: "場所を追加"
                    )
                    
                    // 説明
                    SimpleInfoRow(
                        icon: "text.alignleft",
                        value: $localPlanDescription,
                        placeholder: "メモを追加",
                        isMultiline: true
                    )
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .background(Color(.systemBackground))
            .cornerRadius(DesignSystem.Card.cornerRadius)
            .shadow(color: DesignSystem.Colors.black.opacity(0.05), radius: 8, x: 0, y: 2)
            .onAppear {
                // 画面表示時に自動的にWeb回答をチェック・取り込み
                if hasScheduleEvent {
                    Task {
                        await syncWebResponses()
                    }
                }
            }
            .onChange(of: confirmedDate) { _, _ in
                // 確定情報が変更されたら保存
                viewModel.saveConfirmedInfo(
                    confirmedDate: confirmedDate,
                    confirmedLocation: confirmedLocation.isEmpty ? nil : confirmedLocation,
                    confirmedParticipants: Array(selectedParticipantIds)
                )
                // 確定日時が変更されたら回答を再取得
                if let scheduleEventId = scheduleEvent?.id {
                    loadScheduleResponses(eventId: scheduleEventId)
                }
            }
            .onChange(of: scheduleResponses.count) { _, _ in
                // 回答者が追加されたら、参加者を再反映
            }
            }
        }
    }
    
    // 📢 開催準備カード
    @ViewBuilder
    private func EventCardView() -> some View {
        InfoCard(
            title: "開催準備",
            icon: "calendar.badge.checkmark"
        ) {
            EventStepContent()
        }
    }
    
    // 💰 集金管理カード
    @ViewBuilder
    private func CollectionCardView() -> some View {
        InfoCard(
            title: "集金管理",
            icon: "creditcard.fill"
        ) {
            CollectionStepContent()
        }
    }
    
    // MARK: - 📊 参加希望数の計算
    
    // 各候補日時の参加希望数を計算
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
    
    // MARK: - 🔄 自動同期機能
    
    // 画面表示時の自動チェック＆同期（初回のみ自動取り込み）
    private func autoCheckAndSyncResponses(eventId: UUID) async {
        do {
            let responses = try await AttendanceManager.shared.fetchResponsesFromSupabase(eventId: eventId)
            
            // Web回答数を更新
            webResponsesCount = responses.count
            scheduleResponses = responses
            scheduleEvent?.responses = responses
            
            // 参加者が0人の場合のみ自動取り込み
            if viewModel.participants.isEmpty && !responses.isEmpty {
                let addedCount = viewModel.syncParticipantsFromWebResponses(responses)
                
                if addedCount > 0 {
                    // 成功のhaptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            }
        } catch {
            print("Web回答のチェックエラー: \(error)")
        }
    }
    
    // Web回答を手動で取り込む
    private func syncWebResponses() async {
        guard let event = scheduleEvent else { return }
        
        do {
            let responses = try await AttendanceManager.shared.fetchResponsesFromSupabase(eventId: event.id)
            let addedCount = viewModel.syncParticipantsFromWebResponses(responses)
            
            // Web回答数を更新
            webResponsesCount = responses.count
            scheduleResponses = responses
            scheduleEvent?.responses = responses
            
            if addedCount > 0 {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        } catch {
            print("Web回答の取り込みエラー: \(error)")
        }
    }
    
    // 情報カード（シンプルで見やすい）
    @ViewBuilder
    private func InfoCard<Content: View>(
        title: String,
        icon: String,
        isOptional: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // ヘッダー（シンプルに）
            HStack {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.Icon.Size.medium, weight: DesignSystem.Typography.FontWeight.medium))
                    .foregroundColor(DesignSystem.Colors.primary)
                
                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.black)
                
                if isOptional {
                    Text("（任意）")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondary)
                }
                
                Spacer()
            }
            
            // コンテンツ
            content()
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
    
    // 保存ボタン
    @ViewBuilder
    private func SaveButton() -> some View {
        Button {
            // 保留中のデバウンスをキャンセルして即時保存
            autoSaveWorkItem?.cancel()
            autoSavePlan()
            // トップに戻る
            onFinish?()
        } label: {
            Label("保存して閉じる", systemImage: "checkmark")
        }
        .primaryButtonStyle()
        .tint(DesignSystem.Colors.primary)
        .controlSize(DesignSystem.Button.Control.large)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.xl)
    }
    
    // 金額追加ダイアログビュー
    @ViewBuilder
    private func AddAmountDialogView() -> some View {
        NavigationStack {
            Form {
                Section {
                    TextField("項目名（例：二次会、カラオケ代）", text: $additionalItemName)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.black)
                        .submitLabel(.done)
                    
                    HStack {
                        Text("金額")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.black)
                        Spacer()
                        TextField("0", text: $additionalAmount)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.black)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .additionalAmount)
                            .onChange(of: additionalAmount) { _, newValue in
                                let formatted = viewModel.formatAmount(newValue)
                                if formatted != newValue {
                                    additionalAmount = formatted
                                }
                            }
                    }
                } header: {
                    Text("基本情報")
                }
                
                // 割り方セクション
                Section {
                    Picker("割り方", selection: $additionalUseMultiplier) {
                        Text("倍率適用").tag(true)
                        Text("均等割り").tag(false)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("割り勘の方法")
                } footer: {
                    Text(additionalUseMultiplier ? "役職の倍率に応じて金額が変わります" : "全員同じ金額で割ります")
                        .font(DesignSystem.Typography.caption)
                }
                
                // 参加者選択セクション
                Section {
                    ForEach(viewModel.participants) { participant in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if additionalSelectedParticipantIds.contains(participant.id) {
                                    additionalSelectedParticipantIds.remove(participant.id)
                                } else {
                                    additionalSelectedParticipantIds.insert(participant.id)
                                }
                            }
                        }) {
                            HStack {
                                Text(participant.name)
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(DesignSystem.Colors.black)
                                Spacer()
                                Image(systemName: additionalSelectedParticipantIds.contains(participant.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(additionalSelectedParticipantIds.contains(participant.id) ? DesignSystem.Colors.primary : DesignSystem.Colors.gray4)
                                    .font(.system(size: 22))
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("支払い者（\(additionalSelectedParticipantIds.count)人選択中）")
                        Spacer()
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                let allIds = Set(viewModel.participants.map { $0.id })
                                if additionalSelectedParticipantIds == allIds {
                                    additionalSelectedParticipantIds = []
                                } else {
                                    additionalSelectedParticipantIds = allIds
                                }
                            }
                        }) {
                            let isAllSelected = additionalSelectedParticipantIds.count == viewModel.participants.count
                            Text(isAllSelected ? "全解除" : "全選択")
                                .font(.system(size: DesignSystem.Typography.FontSize.caption, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.primary)
                                .padding(.horizontal, DesignSystem.Spacing.sm)
                                .padding(.vertical, DesignSystem.Spacing.xs)
                                .background(
                                    Capsule()
                                        .fill(DesignSystem.Colors.primary.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("お会計を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        additionalAmount = ""
                        additionalItemName = ""
                        showAddAmountDialog = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        addAmount()
                        showAddAmountDialog = false
                    }
                    .disabled(additionalAmount.isEmpty || additionalSelectedParticipantIds.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    // 金額編集ダイアログビュー
    @ViewBuilder
    private func EditAmountDialogView(item: AmountItem) -> some View {
        NavigationStack {
            Form {
                Section {
                    TextField("項目名（例：二次会、カラオケ代）", text: $editingItemName)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.black)
                        .submitLabel(.done)
                    
                    HStack {
                        Text("金額")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.black)
                        Spacer()
                        TextField("0", text: $editingAmount)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.black)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: editingAmount) { _, newValue in
                                let formatted = viewModel.formatAmount(newValue)
                                if formatted != newValue {
                                    editingAmount = formatted
                                }
                            }
                    }
                } header: {
                    Text("基本情報")
                }
                
                // 割り方セクション
                Section {
                    Picker("割り方", selection: $editingUseMultiplier) {
                        Text("倍率適用").tag(true)
                        Text("均等割り").tag(false)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("割り勘の方法")
                } footer: {
                    Text(editingUseMultiplier ? "役職の倍率に応じて金額が変わります" : "全員同じ金額で割ります")
                        .font(DesignSystem.Typography.caption)
                }
                
                // 参加者選択セクション
                Section {
                    ForEach(viewModel.participants) { participant in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if editingSelectedParticipantIds.contains(participant.id) {
                                    editingSelectedParticipantIds.remove(participant.id)
                                } else {
                                    editingSelectedParticipantIds.insert(participant.id)
                                }
                            }
                        }) {
                            HStack {
                                Text(participant.name)
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(DesignSystem.Colors.black)
                                Spacer()
                                Image(systemName: editingSelectedParticipantIds.contains(participant.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(editingSelectedParticipantIds.contains(participant.id) ? DesignSystem.Colors.primary : DesignSystem.Colors.gray4)
                                    .font(.system(size: 22))
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("支払い者（\(editingSelectedParticipantIds.count)人選択中）")
                        Spacer()
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                let allIds = Set(viewModel.participants.map { $0.id })
                                if editingSelectedParticipantIds == allIds {
                                    editingSelectedParticipantIds = []
                                } else {
                                    editingSelectedParticipantIds = allIds
                                }
                            }
                        }) {
                            let isAllSelected = editingSelectedParticipantIds.count == viewModel.participants.count
                            Text(isAllSelected ? "全解除" : "全選択")
                                .font(.system(size: DesignSystem.Typography.FontSize.caption, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.primary)
                                .padding(.horizontal, DesignSystem.Spacing.sm)
                                .padding(.vertical, DesignSystem.Spacing.xs)
                                .background(
                                    Capsule()
                                        .fill(DesignSystem.Colors.primary.opacity(0.1))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .navigationTitle("お会計の編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        editingAmountItem = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        updateAmount()
                        editingAmountItem = nil
                    }
                    .disabled(editingAmount.isEmpty || editingSelectedParticipantIds.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    // アイコン選択ダイアログビュー
    @ViewBuilder
    private func IconPickerView() -> some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        // 絵文字セクション
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("絵文字")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(DesignSystem.Colors.secondary)
                            
                            SimpleEmojiGridRow(emojis: availableEmojis)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        
                        Divider()
                        
                        // 現在選択されている色を1つだけ表示（補助的な機能）
                        CurrentColorButton()
                        
                        // アイコンセクション
                        SimpleIconGridRow(icons: availableIcons.map { $0.name })
                        
                        Divider()
                        
                        // その他部（アプリアイコン）
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("その他")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(DesignSystem.Colors.secondary)
                            
                            HStack(spacing: 12) {
                                Button(action: {
                                    viewModel.selectedEmoji = ""
                                    viewModel.selectedIcon = nil
                                    showIconPicker = false
                                    autoSavePlan()
                                }) {
                                    Group {
                                        if let appLogo = UIImage(named: "AppLogo") {
                                            Image(uiImage: appLogo)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 32, height: 32)
                                                .cornerRadius(4)
                                        } else {
                                            Image(systemName: "face.smiling")
                                                .font(.system(size: 24))
                                        }
                                    }
                                    .frame(width: 50, height: 50)
                                    .background(
                                        Circle()
                                            .fill(viewModel.selectedEmoji.isEmpty && viewModel.selectedIcon == nil ? DesignSystem.Colors.primary.opacity(0.2) : Color.gray.opacity(0.1))
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(viewModel.selectedEmoji.isEmpty && viewModel.selectedIcon == nil ? DesignSystem.Colors.primary : Color.clear, lineWidth: 2)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Spacer()
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    }
                    .padding(.bottom, DesignSystem.Spacing.xl)
                    .padding(.top, DesignSystem.Spacing.md)
                }
                
                // ポップオーバー外をタップしたら閉じる背景
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if showColorPicker {
                            withAnimation(.spring(.snappy)) {
                                showColorPicker = false
                            }
                            }
                        }
                    .zIndex(998)
                    .opacity(showColorPicker ? 1.0 : 0.0)
                    .allowsHitTesting(showColorPicker)
                
                // カスタムポップオーバーメニュー（最上位に配置）
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Spacer()
                        ColorPickerPopover()
                            .scaleEffect(showColorPicker ? 1.0 : 0.001, anchor: .bottomTrailing)
                            .opacity(showColorPicker ? 1.0 : 0.0)
                            .padding(.trailing, 24)
                    }
                    .padding(.top, 140)
                    Spacer()
                }
                .zIndex(999)
                .allowsHitTesting(showColorPicker)
            }
            .navigationTitle("アイコンを選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        showIconPicker = false
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    // 現在選択されている色を表示するボタン
    @ViewBuilder
    private func CurrentColorButton() -> some View {
        HStack {
            Text("色")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.secondary)
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(.snappy)) {
                    showColorPicker.toggle()
                }
            }) {
                Circle()
                    .fill(
                        colorFromString(viewModel.selectedIconColor) ?? DesignSystem.Colors.primary
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
    
    // シンプルなアイコングリッド行
    @ViewBuilder
    private func SimpleIconGridRow(icons: [String]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("アイコン")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .center), count: 6), spacing: 12) {
                ForEach(icons, id: \.self) { iconName in
                    Button(action: {
                        viewModel.selectedIcon = iconName
                        viewModel.selectedEmoji = ""
                        // 色が設定されていない場合はデフォルト色を設定
                        if viewModel.selectedIconColor == nil {
                            viewModel.selectedIconColor = "0.067,0.094,0.157" // プライマリカラー
                        }
                        showIconPicker = false
                        // アイコン選択後に自動保存
                        autoSavePlan()
                    }) {
                        Image(systemName: iconName)
                            .font(.system(size: 28))
                            .foregroundColor(
                                colorFromString(viewModel.selectedIconColor) ?? DesignSystem.Colors.primary
                            )
                            .frame(width: 50, height: 50)
                            .background(
                                Circle()
                                    .fill(Color.gray.opacity(0.1))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }
    
    // シンプルな絵文字グリッド行
    @ViewBuilder
    private func SimpleEmojiGridRow(emojis: [String]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .center), count: 6), spacing: 12) {
            ForEach(emojis, id: \.self) { emoji in
                Button(action: {
                    viewModel.selectedEmoji = emoji
                    viewModel.selectedIcon = nil
                    showIconPicker = false
                    // 絵文字選択後に自動保存
                    autoSavePlan()
                }) {
                    Text(emoji)
                        .font(.system(size: 32))
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // 色選択ポップオーバー
    @ViewBuilder
    private func ColorPickerPopover() -> some View {
        VStack(spacing: 12) {
            // ヘッダー（バツボタン）
            HStack {
                Spacer()
                Button(action: {
                    withAnimation(.spring(.snappy)) {
                        showColorPicker = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(DesignSystem.Colors.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, DesignSystem.Spacing.xs)
            .padding(.horizontal, DesignSystem.Spacing.xs)
            
            // プレビューアイコン（現在選択されているアイコンがある場合）
            if let iconName = viewModel.selectedIcon {
                Image(systemName: iconName)
                    .font(.system(size: 40))
                    .foregroundColor(
                        colorFromString(viewModel.selectedIconColor) ?? DesignSystem.Colors.primary
                    )
            }
            
            // 色選択セクション
            ColorPickerSection()
        }
        .padding(DesignSystem.Spacing.md)
        .frame(width: 280)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .allowsHitTesting(true)
    }
    
    // 色選択セクション
    @ViewBuilder
    private func ColorPickerSection() -> some View {
        let colors: [(String, Color)] = [
            ("0.067,0.094,0.157", DesignSystem.Colors.primary), // プライマリ
            ("0.937,0.267,0.267", Color(red: 0.937, green: 0.267, blue: 0.267)), // 赤
            ("0.976,0.451,0.086", DesignSystem.Colors.orangeAccent), // オレンジ
            ("0.063,0.725,0.506", Color(red: 0.063, green: 0.725, blue: 0.506)), // 緑
            ("0.259,0.522,0.957", Color(red: 0.259, green: 0.522, blue: 0.957)), // 青
            ("0.647,0.318,0.580", Color(red: 0.647, green: 0.318, blue: 0.580)), // 紫
            ("0.5,0.5,0.5", Color.gray), // グレー
            ("0.0,0.0,0.0", Color.black), // 黒
        ]
        
        VStack(spacing: 16) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 8), spacing: 16) {
                ForEach(colors, id: \.0) { colorData in
                    Button(action: {
                        viewModel.selectedIconColor = colorData.0
                        // 色選択後に自動保存
                        autoSavePlan()
                        // 色選択時はメニューを閉じない
                    }) {
                        ZStack {
                            Circle()
                                .fill(colorData.1)
                                .frame(width: 36, height: 36)
                            
                            // 選択状態の表示
                            if viewModel.selectedIconColor == colorData.0 {
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                                    .frame(width: 36, height: 36)
                                Circle()
                                    .stroke(colorData.1, lineWidth: 2)
                                    .frame(width: 40, height: 40)
                            } else {
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    .frame(width: 36, height: 36)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
    }
    
    // 文字列からColorを生成するヘルパー関数
    private func colorFromString(_ colorString: String?) -> Color? {
        guard let colorString = colorString, !colorString.isEmpty else { return nil }
        let components = colorString.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard components.count == 3 else { return nil }
        return Color(red: components[0], green: components[1], blue: components[2])
    }
    
    // 利用可能なアイコンのリスト
    private let availableIcons: [(name: String, label: String)] = [
        ("wineglass.fill", "ワイン"),
        ("cup.and.saucer.fill", "ビール"),
        ("drop.fill", "カクテル"),
        ("heart.fill", "乾杯"),
        ("fork.knife", "食事"),
        ("building.2.fill", "レストラン"),
        ("takeoutbag.and.cup.and.straw.fill", "テイクアウト"),
        ("party.popper.fill", "パーティー"),
        ("sparkles", "お祝い"),
        ("star.fill", "特別"),
        ("person.3.fill", "会議"),
        ("rectangle.3.group.fill", "グループ"),
        ("briefcase.fill", "ビジネス")
    ]
    
    // MARK: - お会計カードビュー
    
    @ViewBuilder
    private func PaymentCardView(item: AmountItem, index: Int) -> some View {
        let itemParticipants = viewModel.participantsForItem(item)
        let perPerson = viewModel.baseAmount(for: item)
        let isAllParticipants = item.participantIds == nil
        
        VStack(spacing: 0) {
            // 上部: タイトルバー（タップで編集シートへ）
            Button(action: {
                startEditingAmount(item)
            }) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text(item.name)
                        .font(DesignSystem.Typography.emphasizedSubheadline)
                        .foregroundColor(DesignSystem.Colors.black)
                    
                    Spacer()
                    
                    // 情報タグ
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                        Text(isAllParticipants ? "全員" : "\(itemParticipants.count)人")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(DesignSystem.Colors.primary)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.primary.opacity(0.08))
                    )
                    
                    HStack(spacing: 4) {
                        Image(systemName: item.useMultiplier ? "slider.horizontal.3" : "equal.circle")
                            .font(.system(size: 10))
                        Text(item.useMultiplier ? "倍率" : "均等")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(
                        Capsule()
                            .fill(Color(.systemGray5))
                    )
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.secondary.opacity(0.4))
                }
                .padding(.horizontal, DesignSystem.Card.Padding.medium)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.primary.opacity(0.03))
            }
            .buttonStyle(ScaleButtonStyle())
            
            Divider()
                .padding(.horizontal, DesignSystem.Spacing.md)
            
            // 下部: 金額入力エリア
            VStack(spacing: DesignSystem.Spacing.sm) {
                // 金額入力（右寄せ + カード上で直接入力）
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("¥")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.primary)
                    
                    TextField("0", text: cardAmountBinding(for: item.id))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.black)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.top, DesignSystem.Spacing.xs)
                
                // 一人あたり + 参加者名
                HStack {
                    // 参加者がフィルタリングされている場合、名前を表示
                    if !isAllParticipants && !itemParticipants.isEmpty {
                        Text(itemParticipants.map { $0.name }.joined(separator: "、"))
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    if perPerson > 0 {
                        Text("一人あたり約 ¥\(viewModel.formatAmount(String(Int(perPerson))))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.primary.opacity(0.8))
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Card.Padding.medium)
            .padding(.vertical, DesignSystem.Spacing.md)
            
            // カードが2枚以上のときのみ削除ボタン表示
            if viewModel.amountItems.count > 1 {
                Divider()
                    .padding(.horizontal, DesignSystem.Spacing.md)
                
                Button(action: {
                    withAnimation {
                        viewModel.removeAmountItem(id: item.id)
                    }
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                        Text("このお会計を削除")
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundColor(DesignSystem.Colors.alert.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadius, style: .continuous)
                .fill(DesignSystem.Colors.secondaryBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadius, style: .continuous)
                .stroke(DesignSystem.Colors.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(0.04),
            radius: 6,
            x: 0,
            y: 2
        )
    }
    
    // カード金額のBinding生成（直接入力用）
    private func cardAmountBinding(for itemId: UUID) -> Binding<String> {
        Binding<String>(
            get: {
                guard let item = viewModel.amountItems.first(where: { $0.id == itemId }) else { return "0" }
                return item.amount > 0 ? viewModel.formatAmount(String(item.amount)) : ""
            },
            set: { newValue in
                let numbers = newValue.filter { $0.isNumber }
                let amount = Int(numbers) ?? 0
                viewModel.updateAmountItemAmount(id: itemId, amount: amount)
            }
        )
    }
    
    // MARK: - 合計サマリービュー
    
    @ViewBuilder
    private func PaymentSummaryView() -> some View {
        HStack {
            Text("\(viewModel.amountItems.count)件のお会計")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.secondary)
            
            Spacer()
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("合計")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondary)
                Text("¥")
                    .font(.system(size: 18, weight: .bold))
                Text(viewModel.formatAmount(String(viewModel.totalAmountValue)))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
            }
            .foregroundColor(DesignSystem.Colors.primary)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DesignSystem.Colors.primary.opacity(0.05))
        )
    }
    
    // サブビュー：基準金額セクションの内容
    @ViewBuilder
    private func BaseAmountSectionContent() -> some View {
        VStack(alignment: .center, spacing: 8) {
            HStack(spacing: 4) {
                Text("¥")
                    .font(.system(size: 28, weight: .bold))
                Text("\(viewModel.formatAmount(String(Int(viewModel.baseAmount))))")
                    .font(.system(size: 28, weight: .bold))
            }
            .foregroundColor(.blue)
            
            Text("※役職の倍率により実際の支払額は異なります")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
    
    // デバウンス付き自動保存（入力が止まって0.5秒後に保存）
    private func scheduleAutoSave() {
        guard isInitialized else { return }
        autoSaveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [self] in
            autoSavePlan()
        }
        autoSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    // 即時保存処理（画面を閉じる時・保存ボタン押下時に使用）
    private func autoSavePlan() {
        guard isInitialized else { return }
        
        // ローカル変数をViewModelに反映
        viewModel.editingPlanName = localPlanName
        viewModel.editingPlanLocation = localPlanLocation
        viewModel.editingPlanDescription = localPlanDescription
        
        // 確定情報も一緒に保存
        // dateパラメータは確定日時があればそれを使い、なければ現在日時
        viewModel.savePlan(
            name: localPlanName,
            date: confirmedDate ?? Date(),
            description: localPlanDescription.isEmpty ? nil : localPlanDescription,
            location: localPlanLocation.isEmpty ? nil : localPlanLocation,
            confirmedDate: confirmedDate,
            confirmedLocation: confirmedLocation.isEmpty ? nil : confirmedLocation,
            confirmedParticipants: Array(selectedParticipantIds)
        )
        
        // Supabase連携（スケジュール調整イベントがある場合）
        if let event = scheduleEvent {
            Task {
                do {
                    print("🍙 Supabase同期開始: \(event.id)")
                    try await scheduleViewModel.updateEventInSupabase(
                        eventId: event.id,
                        title: scheduleTitle,  // スケジュールタイトルは別途管理されている場合が多いが、ここでは同期対象外または既存値を維持
                        description: localPlanDescription.isEmpty ? nil : localPlanDescription,
                        candidateDates: scheduleCandidateDates,
                        location: localPlanLocation.isEmpty ? nil : localPlanLocation,
                        budget: scheduleBudget.isEmpty ? nil : Int(scheduleBudget),
                        deadline: hasScheduleDeadline ? scheduleDeadline : nil
                    )
                    print("✅ Supabase同期完了")
                } catch {
                    print("❌ Supabase同期エラー: \(error)")
                }
            }
        }
    }
    
    // スケジュール調整セクションの内容
    @ViewBuilder
    private func ScheduleSectionContent() -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            if hasScheduleEvent, let event = scheduleEvent {
                // スケジュール作成済み（Supabaseに保存済み）
                ScheduleDisplayView(
                    event: event,
                    scheduleViewModel: scheduleViewModel,
                    onShowUrl: {
                        showingScheduleUrlSheet = true
                    },
                    onEdit: {
                        // シート表示のための準備
                        startEditingScheduleForSheet(event: event)
                        showScheduleEditSheet = true
                    }
                )
            } else {
                // 未作成の状態：プレビュー・編集可能な表示
                PrePlanScheduleEmptyStateView(
                    candidateDatesCount: scheduleCandidateDates.count,
                    onEdit: {
                        // シート表示のための準備
                        prepareScheduleForEditing()
                        showScheduleEditSheet = true
                    },
                    onPreview: {
                        createPreviewEvent()
                    }
                )
            }
        }
    }
    
    // スケジュール作成開始
    private func startCreatingSchedule() {
        // 基本情報から自動的に引き継ぐ（タイトル、説明、場所、予算）
        scheduleTitle = localPlanName.isEmpty ? (planName.isEmpty ? "無題の飲み会" : planName) : localPlanName
        scheduleDescription = viewModel.editingPlanDescription
        scheduleLocation = viewModel.editingPlanLocation
        let amountString = viewModel.totalAmount.filter { $0.isNumber }
        if !amountString.isEmpty, let amount = Int(amountString) {
            scheduleBudget = String(amount)
        } else {
            scheduleBudget = ""
        }
        // 確定日時があればそれを使い、なければplanDate、それもなければ空配列
        if let date = confirmedDate ?? planDate {
            scheduleCandidateDates = [date]
        } else {
            scheduleCandidateDates = []
        }
        scheduleDeadline = nil
        hasScheduleDeadline = false
        isCreatingSchedule = true
    }
    
    // シート編集の準備（未作成状態から）
    private func prepareScheduleForEditing() {
        // 基本情報から自動的に引き継ぐ（タイトル、説明、場所、予算）
        scheduleTitle = localPlanName.isEmpty ? (planName.isEmpty ? "無題の飲み会" : planName) : localPlanName
        scheduleDescription = viewModel.editingPlanDescription
        scheduleLocation = viewModel.editingPlanLocation
        let amountString = viewModel.totalAmount.filter { $0.isNumber }
        if !amountString.isEmpty, let amount = Int(amountString) {
            scheduleBudget = String(amount)
        } else {
            scheduleBudget = ""
        }
        // scheduleCandidateDatesはそのまま（既に追加された候補日を維持）
        // scheduleDeadlineもそのまま
        
        print("🍙 シート編集準備（未作成状態）: 候補日時 \(scheduleCandidateDates.count)個")
    }
    
    // スケジュール編集開始
    // シート表示用の編集準備（インライン編集モードにはしない）
    private func startEditingScheduleForSheet(event: ScheduleEvent) {
        // 基本情報から自動的に引き継ぐ（タイトル、説明、場所、予算）
        scheduleTitle = event.title
        scheduleDescription = event.description ?? ""
        scheduleCandidateDates = event.candidateDates
        scheduleLocation = event.location ?? ""
        if let budget = event.budget {
            scheduleBudget = String(budget)
        } else {
            scheduleBudget = ""
        }
        
        // スケジュール調整イベントの内容を基本情報にも反映（同期）
        // localPlanLocationが空の場合、またはイベントのlocationがより具体的であれば更新
        if !scheduleLocation.isEmpty && (localPlanLocation.isEmpty || (event.location != nil && event.location != localPlanLocation)) {
            localPlanLocation = scheduleLocation
            viewModel.editingPlanLocation = scheduleLocation
        }
        // localPlanDescriptionが空の場合、またはイベントのdescriptionがより具体的であれば更新
        if !scheduleDescription.isEmpty && (localPlanDescription.isEmpty || (event.description != nil && event.description != localPlanDescription)) {
            localPlanDescription = scheduleDescription
            viewModel.editingPlanDescription = scheduleDescription
        }
        
        // scheduleCandidateDatesWithTime を初期化
        scheduleCandidateDatesWithTime.removeAll()
        for date in event.candidateDates {
            // 時間が設定されているかチェック
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: date)
            let hasTime = (components.hour ?? 0) != 0 || (components.minute ?? 0) != 0
            scheduleCandidateDatesWithTime[date] = hasTime
        }
        
        scheduleDeadline = event.deadline
        hasScheduleDeadline = event.deadline != nil
        
        print("🍙 シート編集準備: 候補日時 \(event.candidateDates.count)個")
    }
    
    // スケジュール作成・編集フォーム
    @ViewBuilder
    private func ScheduleCreationFormView() -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // 候補日時カード
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("候補日時")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.black)
                    .padding(.bottom, DesignSystem.Spacing.xs)
                
                // 時間設定トグル（回答期限を設定と同じスタイル）
                Toggle("時間を設定", isOn: Binding(
                    get: { hasTimeForAllCandidates },
                    set: { newValue in
                        hasTimeForAllCandidates = newValue
                        // 全候補日時の時間設定を更新
                        for date in scheduleCandidateDates {
                            scheduleCandidateDatesWithTime[date] = newValue
                            // 時間を無効にする場合、時間を00:00にリセット
                            if !newValue {
                                let calendar = Calendar.current
                                let components = calendar.dateComponents([.year, .month, .day], from: date)
                                if let dateOnly = calendar.date(from: components),
                                   let index = scheduleCandidateDates.firstIndex(of: date) {
                                    scheduleCandidateDates[index] = dateOnly
                                }
                            }
                        }
                    }
                ))
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.black)
                
                if scheduleCandidateDates.isEmpty {
                    Text("候補日時が設定されていません")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondary)
                        .italic()
                        .padding(.vertical, DesignSystem.Spacing.sm)
                } else {
                    ForEach(Array(scheduleCandidateDates.sorted().enumerated()), id: \.element) { index, date in
                        HStack {
                            // 日時選択（回答期限と全く同じスタイル - 常にDatePickerを表示）
                            let dateBinding = Binding(
                                get: { scheduleCandidateDates.sorted()[index] },
                                set: { newDate in
                                    let sortedDates = scheduleCandidateDates.sorted()
                                    let oldDate = sortedDates[index]
                                    scheduleCandidateDates.removeAll { $0 == oldDate }
                                    scheduleCandidateDates.append(newDate)
                                    scheduleCandidateDatesWithTime.removeValue(forKey: oldDate)
                                    scheduleCandidateDatesWithTime[newDate] = hasTimeForAllCandidates
                                }
                            )
                            
                            if hasTimeForAllCandidates {
                                DatePicker("候補\(index + 1)", selection: dateBinding, displayedComponents: [.date, .hourAndMinute])
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(DesignSystem.Colors.black)
                                    .environment(\.locale, Locale(identifier: "ja_JP"))
                            } else {
                                DatePicker("候補\(index + 1)", selection: dateBinding, displayedComponents: [.date])
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(DesignSystem.Colors.black)
                                    .environment(\.locale, Locale(identifier: "ja_JP"))
                            }
                            
                            // 削除ボタン（バツ）
                            Button(action: {
                                scheduleCandidateDates.removeAll { $0 == date }
                                scheduleCandidateDatesWithTime.removeValue(forKey: date)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(DesignSystem.Colors.alert)
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, DesignSystem.Spacing.sm)
                    }
                }
                
                // 候補を追加ボタン
                Button(action: {
                    // デフォルト日時を設定（最後の候補の1日後、または現在時刻）
                    let defaultDate: Date
                    if let lastDate = scheduleCandidateDates.sorted().last {
                        defaultDate = Calendar.current.date(byAdding: .day, value: 1, to: lastDate) ?? Date()
                    } else {
                        defaultDate = confirmedDate ?? planDate ?? Date()
                    }
                    
                    scheduleCandidateDates.append(defaultDate)
                    scheduleCandidateDatesWithTime[defaultDate] = hasTimeForAllCandidates
                }) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(DesignSystem.Colors.primary)
                        Text("候補を追加")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(DesignSystem.Button.Padding.vertical)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                            .fill(DesignSystem.Colors.primary.opacity(0.1))
                    )
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadius, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            
            // 回答期限カード
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("回答期限")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.black)
                    .padding(.bottom, DesignSystem.Spacing.xs)
                
                Toggle("回答期限を設定", isOn: $hasScheduleDeadline)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.black)
                    .onChange(of: hasScheduleDeadline) { _, newValue in
                        if newValue && scheduleDeadline == nil {
                            scheduleDeadline = Date()
                        }
                    }
                
                if hasScheduleDeadline {
                    DatePicker("期限", selection: Binding(
                        get: { scheduleDeadline ?? Date() },
                        set: { scheduleDeadline = $0 }
                    ), displayedComponents: [.date, .hourAndMinute])
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.black)
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                    .padding(.top, DesignSystem.Spacing.xs)
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadius, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            
            // アクションボタン
            VStack(spacing: DesignSystem.Spacing.md) {
                // 説明文
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("スケジュール調整ページを公開")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.black)
                    
                    Text("URLを発行すると、参加者が候補日時に回答できるようになります")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, DesignSystem.Spacing.xs)
                
                Button(action: {
                    print("🔘 ボタンがタップされました")
                    print("  hasScheduleEvent: \(hasScheduleEvent)")
                    print("  canCreateSchedule: \(canCreateSchedule)")
                    print("  候補日数: \(scheduleCandidateDates.count)")
                    
                    if hasScheduleEvent {
                        // 既存のイベントがある場合は更新
                        updateScheduleEvent()
                    } else {
                        // 新規作成
                        createScheduleEvent()
                    }
                    // シートを閉じる
                    showScheduleEditSheet = false
                }) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: hasScheduleEvent ? "arrow.clockwise" : "link.badge.plus")
                            .font(.system(size: 18, weight: .semibold))
                        Text(hasScheduleEvent ? "公開中の内容を更新" : "URLを発行して公開")
                            .font(DesignSystem.Typography.body)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(DesignSystem.Colors.white)
                    .frame(maxWidth: .infinity)
                    .padding(DesignSystem.Button.Padding.vertical)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                            .fill(canCreateSchedule ? DesignSystem.Colors.primary : DesignSystem.Colors.gray4)
                    )
                }
                .disabled(!canCreateSchedule)
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadius, style: .continuous)
                    .fill(Color(.systemBackground))
            )
        }
        // 候補日時追加用のシート
        .sheet(isPresented: $showingScheduleDatePicker) {
            DatePickerSheet(
                selectedDate: $selectedScheduleDate,
                hasTime: Binding(
                    get: { selectedScheduleDateHasTime },
                    set: { newValue in
                        selectedScheduleDateHasTime = newValue
                        hasTimeForAllCandidates = newValue
                    }
                ),
                isEditing: false,
                onAdd: {
                    scheduleCandidateDates.append(selectedScheduleDate)
                    scheduleCandidateDatesWithTime[selectedScheduleDate] = selectedScheduleDateHasTime
                    hasTimeForAllCandidates = selectedScheduleDateHasTime
                    showingScheduleDatePicker = false
                },
                onCancel: {
                    showingScheduleDatePicker = false
                }
            )
        }
    }
    
    // スケジュール作成可能かどうか
    private var canCreateSchedule: Bool {
        // タイトルは基本情報から自動的に設定されるので、候補日時があれば作成可能
        !scheduleCandidateDates.isEmpty
    }
    
    // プレビュー可能かどうか
    private var canPreviewSchedule: Bool {
        if let _ = scheduleEvent, hasScheduleEvent {
            return true
        }
        return !scheduleCandidateDates.isEmpty
    }
    
    // 候補日時を年月日曜日形式でフォーマット（日付部分）
    private func formatCandidateDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日(E)"
        return formatter.string(from: date)
    }
    
    // 候補日時を時間形式でフォーマット（時間部分）
    private func formatCandidateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    // プレビュー用の一時的なイベントを作成
    private func createPreviewEvent() {
        guard canPreviewSchedule else { return }
        
        // 既にイベントが作成されている場合はそのままプレビュー
        if scheduleEvent != nil, hasScheduleEvent {
            showingSchedulePreview = true
            return
        }
        
        // 作成前の場合は一時的にイベントを作成してプレビュー
        let budgetInt = scheduleBudget.isEmpty ? nil : Int(scheduleBudget)
        let finalDeadline = hasScheduleDeadline ? scheduleDeadline : nil
        
        Task {
            do {
                let previewEvent = try await scheduleViewModel.createEventInSupabase(
                    title: scheduleTitle.isEmpty ? "プレビュー" : scheduleTitle,
                    description: scheduleDescription.isEmpty ? nil : scheduleDescription,
                    candidateDates: scheduleCandidateDates,
                    location: scheduleLocation.isEmpty ? nil : scheduleLocation,
                    budget: budgetInt,
                    deadline: finalDeadline
                )
                
                await MainActor.run {
                    // プレビュー用の一時的なイベントとして設定
                    scheduleEvent = previewEvent
                    showingSchedulePreview = true
                }
            } catch {
                await MainActor.run {
                    print("プレビュー用イベント作成エラー: \(error)")
                    // エラーが発生した場合はプレビューシートを閉じる
                    showingSchedulePreview = false
                }
            }
        }
    }
    
    // スケジュール作成キャンセル
    private func cancelScheduleCreation() {
        isCreatingSchedule = false
    }
    
    // スケジュール作成
    private func createScheduleEvent() {
        guard canCreateSchedule else { 
            print("⚠️ スケジュール作成不可: 候補日が設定されていません")
            return 
        }
        
        print("📅 スケジュール作成開始...")
        print("  タイトル: \(scheduleTitle)")
        print("  候補日数: \(scheduleCandidateDates.count)")
        
        let budgetInt = scheduleBudget.isEmpty ? nil : Int(scheduleBudget)
        let finalDeadline = hasScheduleDeadline ? scheduleDeadline : nil
        
        Task {
            do {
                let event = try await scheduleViewModel.createEventInSupabase(
                    title: scheduleTitle,
                    description: scheduleDescription.isEmpty ? nil : scheduleDescription,
                    candidateDates: scheduleCandidateDates,
                    location: scheduleLocation.isEmpty ? nil : scheduleLocation,
                    budget: budgetInt,
                    deadline: finalDeadline
                )
                
                print("✅ スケジュール作成成功: \(event.id)")
                
                await MainActor.run {
                    scheduleEvent = event
                    hasScheduleEvent = true
                    isCreatingSchedule = false
                    
                    print("📝 状態更新完了")
                    
                    // PlanにscheduleEventIdを紐づける
                    if let planId = viewModel.editingPlanId,
                       let planIndex = viewModel.savedPlans.firstIndex(where: { $0.id == planId }) {
                        viewModel.savedPlans[planIndex].scheduleEventId = event.id
                        viewModel.saveData()
                        print("💾 Planに紐づけ完了")
                    }
                    
                    // 確定日時に反映
                    if let optimalDate = event.optimalDate {
                        confirmedDate = optimalDate
                        print("📆 確定日時を設定: \(optimalDate)")
                    }
                    
                    // シンプルな確認アラートを表示
                    showingUrlPublishedAlert = true
                }
            } catch {
                print("❌ スケジュール作成エラー: \(error)")
                await MainActor.run {
                    // エラーメッセージを表示（TODO: アラート実装）
                    isCreatingSchedule = false
                }
            }
        }
    }
    
    // スケジュール更新
    private func updateScheduleEvent() {
        guard canCreateSchedule, let event = scheduleEvent else { return }
        
        let budgetInt = scheduleBudget.isEmpty ? nil : Int(scheduleBudget)
        let finalDeadline = hasScheduleDeadline ? scheduleDeadline : nil
        
        Task {
            do {
                try await scheduleViewModel.updateEventInSupabase(
                    eventId: event.id,
                    title: scheduleTitle,
                    description: scheduleDescription.isEmpty ? nil : scheduleDescription,
                    candidateDates: scheduleCandidateDates,
                    location: scheduleLocation.isEmpty ? nil : scheduleLocation,
                    budget: budgetInt,
                    deadline: finalDeadline
                )
                
                // 更新後にイベント一覧を再取得
                await scheduleViewModel.fetchEventsFromSupabase()
                
                await MainActor.run {
                    // 更新されたイベントを取得
                    if let updatedEvent = scheduleViewModel.events.first(where: { $0.id == event.id }) {
                        scheduleEvent = updatedEvent
                        
                        // 確定日時に反映
                        if let optimalDate = updatedEvent.optimalDate {
                            confirmedDate = optimalDate
                        }
                    }
                    
                    // 更新確認アラートを表示
                    showingScheduleUpdatedAlert = true
                }
            } catch {
                print("スケジュール更新エラー: \(error)")
                // エラーハンドリング
            }
        }
    }
    
    // 🔗 シンプル版チケットUI（QRコード＋共有機能のみ）
    @ViewBuilder
    private func ScheduleUrlAndActionsCardView(
        event: ScheduleEvent,
        webResponsesCount: Int,
        onShowUrl: @escaping () -> Void,
        onPreview: @escaping () -> Void,
        onSyncResponses: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // シンプル版チケット
            VStack(spacing: 0) {
                // 上部：ヘッダーエリア（プライマリーカラー）
                ZStack {
                    Rectangle()
                        .fill(DesignSystem.Colors.primary)
                        .frame(height: 50)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                        Text("INVITATION")
                            .font(.system(.subheadline, design: .serif))
                            .fontWeight(.bold)
                            .tracking(3)
                            .foregroundColor(.white)
                    }
                }
                .mask(
                    TicketTopShape(cornerRadius: 16)
                )
                
                // メインコンテンツ：QRコードのみ
                VStack(spacing: DesignSystem.Spacing.md) {
                    // QRコード（中央配置）
                    VStack(spacing: 8) {
                        Text("調整用QRコード")
                            .font(DesignSystem.Typography.subheadline) // タイトルとして少し大きめに
                            .foregroundColor(DesignSystem.Colors.gray5)
                            .fontWeight(.bold)
                        
                        Image(uiImage: generateQRCodeForPrePlanView(from: scheduleViewModel.getWebUrl(for: event)))
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 180, height: 180)
                            .background(Color.white)
                            .cornerRadius(8)
                        
                        
                        /*
                        Text("QRコードをスキャンまたはタップすると\n調整用Webページが開きます")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.gray6)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        */
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(DesignSystem.Spacing.xl)
                .contentShape(Rectangle()) // タップ領域を確保
                .onTapGesture {
                    if let url = URL(string: scheduleViewModel.getWebUrl(for: event)) {
                        UIApplication.shared.open(url)
                    }
                }
                
                // ミシン目
                DashedLine()
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundColor(DesignSystem.Colors.gray3)
                    .frame(height: 1)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .anchorPreference(key: TicketDividerAnchorKey.self, value: .bounds) { $0 }
                
                // 下部：アクションボタンエリア
                if let webUrl = event.webUrl {
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        // シェアボタン（プライマリーアクション）
                        Button(action: {
                            shareUrl(scheduleViewModel.getShareUrl(for: event))
                        }) {
                            Label("招待状を送る", systemImage: "square.and.arrow.up")
                                .font(DesignSystem.Typography.body.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .primaryButtonStyle()
                        .controlSize(DesignSystem.Button.Control.large)
                        
                        // コピーボタン（セカンダリーアクション）
                        Button(action: {
                            UIPasteboard.general.string = webUrl
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                            withAnimation {
                                showingCopyToast = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    showingCopyToast = false
                                }
                            }
                        }) {
                            Label("URLをコピー", systemImage: "doc.on.doc")
                                .font(DesignSystem.Typography.body)
                                .frame(maxWidth: .infinity)
                        }
                        .secondaryButtonStyle()
                        .controlSize(DesignSystem.Button.Control.large)
                        .tint(DesignSystem.Colors.primary)
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
            }
            .backgroundPreferenceValue(TicketDividerAnchorKey.self) { anchor in
                GeometryReader { geo in
                    if let anchor = anchor {
                        let dividerY = geo[anchor].midY
                        TicketShape(notchYPosition: dividerY)
                            .fill(DesignSystem.Colors.white)
                            .shadow(
                                color: DesignSystem.Colors.black.opacity(0.08),
                                radius: 12,
                                x: 0,
                                y: 4
                            )
                    } else {
                        // フォールバック（アンカー取得前）
                        TicketShape(notchOffset: 0.6)
                            .fill(DesignSystem.Colors.white)
                            .shadow(
                                color: DesignSystem.Colors.black.opacity(0.08),
                                radius: 12,
                                x: 0,
                                y: 4
                            )
                    }
                }
            }
        }
    }
    
    // QRコード生成（PrePlanView用） - 丸いドット＆アイコン付き
    private func generateQRCodeForPrePlanView(from string: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "H" // アイコンを載せるため誤り訂正レベルを高く設定
        
        guard let qrImage = filter.outputImage else {
            return UIImage(systemName: "xmark.circle") ?? UIImage()
        }
        
        // 1. まずは正確なサイズ（1セル=1ピクセル）の正規化された画像を取得
        // QRコードのCIImageは座標系が特殊なため、一度CGImageにして確実にピクセルデータを取り出せるようにする
        let scale = CGAffineTransform(scaleX: 1, y: 1) // そのままの解像度
        guard let cgImage = context.createCGImage(qrImage.transformed(by: scale), from: qrImage.extent) else {
            return UIImage(systemName: "xmark.circle") ?? UIImage()
        }
        
        // 2. ピクセルデータの読み取り準備
        let width = cgImage.width
        let height = cgImage.height
        let dataSize = width * height * 4
        var rawData = [UInt8](repeating: 0, count: dataSize)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let bitmapContext = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return UIImage(systemName: "xmark.circle") ?? UIImage()
        }
        
        bitmapContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // 3. ドットによる描画（高解像度化）
        let moduleSize: CGFloat = 20.0 // 1ドットの描画サイズ
        let finalSize = CGSize(width: CGFloat(width) * moduleSize, height: CGFloat(height) * moduleSize)
        
        UIGraphicsBeginImageContextWithOptions(finalSize, false, 0.0)
        guard let drawContext = UIGraphicsGetCurrentContext() else { return UIImage() }
        
        // 背景を白で塗りつぶし
        UIColor.white.setFill()
        drawContext.fill(CGRect(origin: .zero, size: finalSize))
        
        // ドットの色（プライマリーカラー）を設定
        DesignSystem.Colors.uiPrimary.setFill()
        
        // 全ピクセルを走査して黒い部分（QRコードのデータ部分）だけ丸を描画
        // ピクセルデータの黒判定: R,G,Bが全て0に近い場合（CIImageからの変換では完全な白黒になるはず）
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * 4
                let red = rawData[pixelIndex]
                
                // 黒いピクセル（データあり）の場合のみ描画
                if red < 128 {
                    // 丸を描画（隣とくっつかないよう少し小さめにするとドット感が出る）
                    // 20.0のサイズに対して、直径18.0くらいで描画
                    let dotRect = CGRect(
                        x: CGFloat(x) * moduleSize + 1.0,
                        y: CGFloat(y) * moduleSize + 1.0,
                        width: moduleSize - 2.0,
                        height: moduleSize - 2.0
                    )
                    drawContext.fillEllipse(in: dotRect)
                }
            }
        }
        
        let dotQRImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // 4. アイコンの合成（前のロジックと同じ、ただしサイズ感は合わせる）
        guard let baseImage = dotQRImage else { return UIImage() }
        
        UIGraphicsBeginImageContextWithOptions(baseImage.size, false, 0.0)
        baseImage.draw(in: CGRect(origin: .zero, size: baseImage.size))
        
        // 中央にアイコンを描画
        // アプリアイコンまたはシンボルを使用
        let icon: UIImage?
        if let appIcon = UIImage(named: "AppLogo") {
            icon = appIcon
        } else {
            icon = UIImage(systemName: "wineglass.fill")?.withTintColor(DesignSystem.Colors.uiPrimary, renderingMode: .alwaysOriginal)
        }
        
        if let iconImage = icon {
            let iconSize = baseImage.size.width * 0.22 // 少し大きめに調整
            
            // アスペクト比を維持してサイズ計算
            let aspectRatio = iconImage.size.width / iconImage.size.height
            var drawSize = CGSize(width: iconSize, height: iconSize)
            
            if aspectRatio > 1 {
                drawSize.height = iconSize / aspectRatio
            } else {
                drawSize.width = iconSize * aspectRatio
            }
            
            // 中央配置のための原点計算
            let iconOrigin = CGPoint(
                x: (baseImage.size.width - drawSize.width) / 2, 
                y: (baseImage.size.height - drawSize.height) / 2
            )
            let iconRect = CGRect(origin: iconOrigin, size: drawSize)
            
            // アイコンの背景（白）- 丸角四角形
            let bgPadding: CGFloat = 8.0
            let bgSize = CGSize(width: drawSize.width + bgPadding * 2, height: drawSize.height + bgPadding * 2)
            let bgOrigin = CGPoint(
                x: (baseImage.size.width - bgSize.width) / 2,
                y: (baseImage.size.height - bgSize.height) / 2
            )
            let bgRect = CGRect(origin: bgOrigin, size: bgSize)
            let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: 12) // 背景も丸みを持たせる
            UIColor.white.setFill()
            bgPath.fill()
            
            iconImage.draw(in: iconRect)
        }
        
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return finalImage ?? baseImage
    }
    
    // チケット用日付フォーマッター（コンパクト版）
    private func formatDateForTicketCompact(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d(E) H:mm"
        return formatter.string(from: date)
    }
    
    // URL共有
    private func shareUrl(_ url: String) {
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    
    // 📅 候補日時リストビュー
    @ViewBuilder
    private func CandidateDatesListView(
        event: ScheduleEvent,
        scheduleViewModel: ScheduleManagementViewModel,
        confirmedDate: Binding<Date?>
    ) -> some View {
        if !event.candidateDates.isEmpty {
            // 各候補日時の参加希望数を計算
            let voteCounts = calculateVoteCounts(for: event)
            let maxVotes = voteCounts.values.max() ?? 0
            
            VStack(spacing: DesignSystem.Spacing.md) {
                // ガイドテキスト
                HStack {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.secondary)
                    Text("開催する日程が決まったら選択してください")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondary)
                    Spacer()
                }
                .padding(.bottom, 4)
                
                ForEach(Array(event.candidateDates.sorted().enumerated()), id: \.element) { index, date in
                    let votes = voteCounts[date] ?? 0
                    let isTopChoice = votes > 0 && votes == maxVotes
                    let isConfirmedDate = confirmedDate.wrappedValue != nil && Calendar.current.isDate(date, inSameDayAs: confirmedDate.wrappedValue!)
                    
                    Button(action: {
                        // 候補日時をタップして開催日として設定 & 即座に同期
                        if isConfirmedDate {
                            // 既に開催日になっている場合は解除 -> 全員リストに戻す
                            confirmedDate.wrappedValue = nil
                            viewModel.syncParticipants(from: scheduleResponses, date: nil)
                        } else {
                            // 開催日として設定 -> その日の参加者に絞り込み
                            confirmedDate.wrappedValue = date
                            viewModel.syncParticipants(from: scheduleResponses, date: date)
                        }
                    }) {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            // 開催日フラグ
                            if isConfirmedDate {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(DesignSystem.Colors.success)
                                    .font(.system(size: 20))
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(DesignSystem.Colors.gray4)
                                    .font(.system(size: 20))
                            }
                            
                            // 番号バッジ
                            Text("\(index + 1)")
                                .font(DesignSystem.Typography.caption)
                                .fontWeight(.bold)
                                .foregroundColor(isTopChoice ? .white : DesignSystem.Colors.gray6)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle().fill(isTopChoice ? DesignSystem.Colors.primary : DesignSystem.Colors.gray2)
                                )
                            
                            // 日時
                            Text(scheduleViewModel.formatDateTime(date))
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.black)
                            
                            Spacer()
                            
                            // 参加希望数
                            Text("\(votes)人")
                                .font(DesignSystem.Typography.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(votes > 0 ? DesignSystem.Colors.gray6 : DesignSystem.Colors.secondary)
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                                .fill(DesignSystem.Colors.gray1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                                .stroke(isConfirmedDate ? DesignSystem.Colors.success : DesignSystem.Colors.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)

            }
            }
        } else {
            Text("候補日時が設定されていません")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.secondary)
                .italic()
        }
    }
    
    // スケジュール表示ビュー
    // ScheduleDisplayView definition removed. Use struct from PrePlanScheduleView.swift
    
    // スケジュールプレビューシート
    // SchedulePreviewSheet definition removed. Use struct from PrePlanScheduleView.swift
    


// カスタムトグルスタイル
    // ToggleStyles removed. Use structs from PrePlanScheduleView.swift if needed, or DesignSystem.

// MARK: - Simple Info Row Component
/// シンプルな情報入力行（アイコン＋入力フィールド）
struct SimpleInfoRow: View {
    let icon: String
    @Binding var value: String
    let placeholder: String
    var isMultiline: Bool = false
    
    var body: some View {
        HStack(alignment: isMultiline ? .top : .center, spacing: DesignSystem.Spacing.md) {
            // アイコン
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(value.isEmpty ? DesignSystem.Colors.secondary : DesignSystem.Colors.primary)
                .frame(width: 24, height: 24)
                .padding(.top, isMultiline ? 8 : 0)
            
            // 入力フィールド
            if isMultiline {
                ZStack(alignment: .topLeading) {
                    if value.isEmpty {
                        Text(placeholder)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(Color(uiColor: .placeholderText))
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $value)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.black)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 100)
                }
            } else {
                TextField(placeholder, text: $value)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.black)
                    .submitLabel(.done)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    value.isEmpty ? Color(.separator) : DesignSystem.Colors.primary.opacity(0.3),
                    lineWidth: 1
                )
        )
    }
    // Helper functions removed from here
}

}

extension PrePlanView {
    private func getDeadlineText(deadline: Date) -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d HH:mm"
        let dateString = formatter.string(from: deadline)
        
        if now > deadline {
            return "\(dateString) (終了)"
        } else {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: deadline))
            
            if let days = components.day {
                if days == 0 {
                    return "\(dateString) (本日中)"
                } else {
                    return "\(dateString) (あと\(days)日)"
                }
            } else {
                return dateString
            }
        }
    }
}

#Preview {
    NavigationStack {
        PrePlanView(viewModel: PrePlanViewModel(), planName: "Sample Plan", planDate: Date())
    }
}
