import SwiftUI
import Combine

// 絵文字の選択肢
private let availableEmojis = ["🍻", "🍺", "🥂", "🍷", "🍸", "🍹", "🍾", "🥃", "🍴", "🍖", "🍗", "🍣", "🍕", "🍔", "🥩", "🍙", "🤮", "🤢", "🥴", "😵", "😵‍💫", "💸", "🎊"]

// 役職を表す列挙型
public enum Role: String, CaseIterable, Identifiable, Codable {
    case director = "部長"
    case manager = "課長"
    case staff = "一般"
    case newbie = "新人"
    
    public var id: String { rawValue }
    
    public var defaultMultiplier: Double {
        return PrePlanViewModel.shared.getRoleMultiplier(self)
    }
    
    public func setMultiplier(_ value: Double) {
        PrePlanViewModel.shared.setRoleMultiplier(self, value: value)
    }
    
    public var name: String {
        return PrePlanViewModel.shared.getRoleName(self)
    }
    
    public func setName(_ value: String) {
        PrePlanViewModel.shared.setRoleName(self, value: value)
    }
    
    public var displayText: String {
        "\(self.name) ×\(String(format: "%.1f", self.defaultMultiplier))"
    }
}

// 役職の種類を表す列挙型
public enum RoleType: Identifiable, Codable, Hashable {
    case standard(Role)
    case custom(CustomRole)
    
    public var id: UUID {
        switch self {
        case .standard(let role):
            return UUID(uuidString: role.id) ?? UUID()
        case .custom(let role):
            return role.id
        }
    }
    
    public var name: String {
        switch self {
        case .standard(let role):
            return role.name
        case .custom(let role):
            return role.name
        }
    }
    
    // Hashableの実装
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .standard(let role):
            hasher.combine("standard")
            hasher.combine(role)
        case .custom(let role):
            hasher.combine("custom")
            hasher.combine(role.id)
        }
    }
    
    public static func == (lhs: RoleType, rhs: RoleType) -> Bool {
        switch (lhs, rhs) {
        case (.standard(let lRole), .standard(let rRole)):
            return lRole == rRole
        case (.custom(let lRole), .custom(let rRole)):
            return lRole.id == rRole.id
        default:
            return false
        }
    }
}

// 参加者を表す構造体
public struct Participant: Identifiable, Hashable, Codable {
    public let id: UUID
    public var name: String
    public var roleType: RoleType
    public var hasCollected: Bool = false  // 集金確認用のプロパティを追加
    public var hasFixedAmount: Bool = false  // 金額固定フラグ
    public var fixedAmount: Int = 0  // 固定金額
    public var source: ParticipantSource = .manual  // 参加者の追加元
    
    public init(id: UUID = UUID(), name: String, roleType: RoleType, hasCollected: Bool = false, hasFixedAmount: Bool = false, fixedAmount: Int = 0, source: ParticipantSource = .manual) {
        self.id = id
        self.name = name
        self.roleType = roleType
        self.hasCollected = hasCollected
        self.hasFixedAmount = hasFixedAmount
        self.fixedAmount = fixedAmount
        self.source = source
    }
    
    // 参加者の追加元
    public enum ParticipantSource: String, Codable {
        case manual = "手動追加"
        case webResponse = "Web回答"
    }
    
    public static func == (lhs: Participant, rhs: Participant) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public var effectiveMultiplier: Double {
        switch roleType {
        case .standard(let role):
            return role.defaultMultiplier
        case .custom(let customRole):
            return customRole.multiplier
        }
    }
}

// カスタム役職を表す構造体
public struct CustomRole: Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String
    public var multiplier: Double
    
    public init(id: UUID = UUID(), name: String, multiplier: Double) {
        self.id = id
        self.name = name
        self.multiplier = multiplier
    }
    
    public var displayText: String {
        "\(name) ×\(String(format: "%.1f", multiplier))"
    }
}

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
        _selectedStep = State(initialValue: .planning)
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
            // 自動保存
            autoSavePlan()
        }
    }
    @State private var localPlanDate: Date? = nil {
        didSet {
            // 自動保存
            autoSavePlan()
        }
    }
    @State private var isEditingTitle: Bool = false
    @FocusState private var isTitleFocused: Bool
    
    // 金額追加ダイアログ用
    @State private var showAddAmountDialog = false
    @State private var additionalAmount: String = ""
    @State private var additionalItemName: String = ""
    
    // 金額編集ダイアログ用
    @State private var showEditAmountDialog = false
    @State private var editingAmountItem: AmountItem? = nil
    @State private var editingAmount: String = ""
    @State private var editingItemName: String = ""
    
    // アコーディオン表示制御用
    @State private var isBreakdownExpanded: Bool = false
    
    // 絵文字選択ダイアログ用
    @State private var showEmojiPicker = false
    
    // 新しい状態変数を追加
    @State private var showPaymentGenerator = false
    
    // スケジュール調整関連の状態変数を追加
    @State private var scheduleEvent: ScheduleEvent?
    @State private var showingScheduleUrlSheet = false
    @State private var showingSchedulePreview = false
    @State private var hasScheduleEvent = false // スケジュール調整済みかどうか
    @State private var showingHelpGuide = false
    
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
    
    // Webフォームの回答
    @State private var scheduleResponses: [ScheduleResponse] = []
    @State private var isLoadingResponses = false
    
    // スケジュール編集シート用
    @State private var showScheduleEditSheet = false
    
    // 3ステップのタブ構造
    enum MainStep: String, CaseIterable {
        case planning = "企画"
        case event = "開催"
        case collection = "集金"
        
        var icon: String {
            switch self {
            case .planning: return "lightbulb.fill"
            case .event: return "calendar.badge.checkmark"
            case .collection: return "creditcard.fill"
            }
        }
        
        var description: String {
            switch self {
            case .planning: return "飲み会を企画する"
            case .event: return "開催準備と案内"
            case .collection: return "集金管理"
            }
        }
    }
    
    @State private var selectedStep: MainStep = .planning
    
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
        // --- ここからロジックをViewビルダーの外に出す ---
        let tempParticipants = viewModel.participants.map { p in
            if p.id == participant.id {
                return Participant(id: p.id, name: editingText, roleType: editingRoleType, hasCollected: p.hasCollected, hasFixedAmount: p.hasFixedAmount, fixedAmount: p.fixedAmount)
            }
            return p
        }
        let totalMultiplier = tempParticipants.reduce(0.0) { sum, p in
            switch p.roleType {
            case .standard(let role):
                return sum + role.defaultMultiplier
            case .custom(let customRole):
                return sum + customRole.multiplier
            }
        }
        let amountString = viewModel.totalAmount.filter { $0.isNumber }
        var paymentAmountText: String = ""
        if let total = Double(amountString), totalMultiplier > 0 {
            let baseAmount = total / totalMultiplier
            let editingMultiplier: Double
            switch editingRoleType {
            case .standard(let role):
                editingMultiplier = role.defaultMultiplier
            case .custom(let customRole):
                editingMultiplier = customRole.multiplier
            }
            let paymentAmount = Int(round(baseAmount * editingMultiplier))
            paymentAmountText = "¥" + viewModel.formatAmount(String(paymentAmount))
        }
        // --- ここまでロジックをViewビルダーの外に出す ---
        
        return NavigationStack {
            Form {
                Section {
                    TextField("参加者名", text: $editingText)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.black)
                    // 役職選択用のビュー
                    rolePickerView
                    
                    // 集金確認用のトグル
                    Toggle("集金済み", isOn: $editingHasCollected)
                        .toggleStyle(SwitchToggleStyle(tint: DesignSystem.Colors.success))
                } header: {
                    Text("参加者情報")
                        .font(DesignSystem.Typography.headline)
                }
                
                Section(header: Text("支払金額").font(DesignSystem.Typography.headline)) {
                    // 金額固定トグル
                    Toggle("金額を固定する", isOn: $editingHasFixedAmount)
                        .toggleStyle(SwitchToggleStyle(tint: DesignSystem.Colors.primary))
                        .onChange(of: editingHasFixedAmount) { _, newValue in
                            if newValue && editingFixedAmount == 0 {
                                // 固定する場合で金額が0なら現在の計算金額をセット
                                if let amount = Int(amountString), totalMultiplier > 0 {
                                    let baseAmount = Double(amount) / totalMultiplier
                                    let multiplier: Double
                                    switch editingRoleType {
                                    case .standard(let role):
                                        multiplier = role.defaultMultiplier
                                    case .custom(let customRole):
                                        multiplier = customRole.multiplier
                                    }
                                    editingFixedAmount = Int(round(baseAmount * multiplier))
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
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                MainContentView()
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingHelpGuide = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.accentColor)
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
            .sheet(isPresented: $showEmojiPicker) {
                EmojiPickerView()
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
                        // URL表示完了後は飲み会作成画面に戻る（トップには戻らない）
                    }
                }
            }
            .sheet(isPresented: $showScheduleEditSheet) {
                NavigationStack {
                    ZStack {
                        // リキッドグラス効果の背景
                        Color.clear
                            .background(.ultraThinMaterial)
                        
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
                                Button("キャンセル") {
                                    // シートを閉じるだけ（変更は保持される）
                                    showScheduleEditSheet = false
                                }
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
            .onAppear {
                setupInitialState()
                loadScheduleEvent()
            }
            .onChange(of: viewModel.participants.count) { _, newCount in
                handleParticipantsCountChange(newCount: newCount)
            }
            // 削除確認アラートを追加
            .alert("参加者を削除", isPresented: $showingDeleteAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {
                    if let participant = participantToDelete {
                        viewModel.deleteParticipant(id: participant.id)
                        participantToDelete = nil
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
    }
    
    // 初期状態の設定
    private func setupInitialState() {
        // 編集時はeditingPlanName、新規時はplanNameで初期化
        if viewModel.editingPlanId == nil {
            localPlanName = planName
            localPlanDate = nil
        } else {
            localPlanName = viewModel.editingPlanName
            localPlanDate = viewModel.editingPlanDate
        }
        
        if !hasShownEditHint && !viewModel.participants.isEmpty {
            showSwipeHintAnimation()
        }
        
        // 絵文字の初期化 - より確実に
        print("初期化前の絵文字: \(viewModel.selectedEmoji)")
        if viewModel.selectedEmoji.isEmpty {
            viewModel.selectedEmoji = "🍻"
            print("絵文字を初期化: 🍻")
        } else {
            print("既存の絵文字を使用: \(viewModel.selectedEmoji)")
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
                    isLoadingResponses = false
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
            let itemName = additionalItemName.isEmpty ? "追加金額" : additionalItemName
            
            // 内訳アイテムを追加
            viewModel.addAmountItem(name: itemName, amount: amount)
            
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
    }
    
    // 金額更新処理
    private func updateAmount() {
        guard let item = editingAmountItem, !editingAmount.isEmpty else { return }
        
        // 数字のみを抽出
        let numbers = editingAmount.filter { $0.isNumber }
        if let amount = Int(numbers) {
            // 項目名（空の場合はデフォルト名を設定）
            let itemName = editingItemName.isEmpty ? "追加金額" : editingItemName
            
            // 内訳アイテムを更新
            viewModel.updateAmountItem(id: item.id, name: itemName, amount: amount)
        }
    }
    
    // 内訳アイテム削除
    private func deleteAmountItem(at offsets: IndexSet) {
        viewModel.removeAmountItems(at: offsets)
    }
    
    // メインコンテンツビュー
    private func MainContentView() -> some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                // 絵文字と飲み会名の行
                HStack(spacing: DesignSystem.Spacing.md) {
                    EmojiButton()
                    PlanNameView()
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.md)
                
                // サマリーカード（重要情報を集約）
                SummaryCard()
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                
                // 🎨 カード式レイアウト：シンプルで分かりやすい構造
                VStack(spacing: 24) {
                    // 📋 基本情報カード
                    BasicInfoCardView()
                    
                    // 📅👥 日程＆参加者カード（統合）
                    ScheduleAndParticipantsCardView()
                    
                    // 📢 開催準備カード（日程確定後に表示）
                    if confirmedDate != nil || hasScheduleEvent {
                        EventCardView()
                    }
                    
                    // 💰 集金管理カード（参加者がいる場合のみ表示）
                    if !viewModel.participants.isEmpty {
                        CollectionCardView()
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, 100) // 下部ボタン用のスペース
            }
            .padding(.top, DesignSystem.Spacing.xxl)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .safeAreaInset(edge: .bottom) {
            SaveButton()
        }
    }
    
    // 絵文字ボタン
    @ViewBuilder
    private func EmojiButton() -> some View {
        Button(action: {
            showEmojiPicker = true
        }) {
            Text(viewModel.selectedEmoji.isEmpty ? "🍻" : viewModel.selectedEmoji)
                .font(.system(size: 40))
                .frame(width: 70, height: 70)
                .background(
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                )
        }
        .onAppear {
            // 初期表示時に絵文字が空の場合はデフォルト値を設定
            if viewModel.selectedEmoji.isEmpty {
                viewModel.selectedEmoji = "🍻"
            }
            print("現在の絵文字: \(viewModel.selectedEmoji)")
        }
    }
    
    // 飲み会名ビュー
    @ViewBuilder
    private func PlanNameView() -> some View {
        if isEditingTitle {
            TextField("飲み会名を入力", text: $localPlanName)
                .font(DesignSystem.Typography.title1)
                .foregroundColor(DesignSystem.Colors.black)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(DesignSystem.TextField.Padding.horizontal)
                .frame(height: DesignSystem.TextField.Height.large)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                        .fill(DesignSystem.TextField.backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                        .stroke(isTitleFocused ? DesignSystem.TextField.focusedBorderColor : DesignSystem.TextField.borderColor, lineWidth: DesignSystem.TextField.borderWidth)
                )
                .focused($isTitleFocused)
                .onSubmit { isEditingTitle = false }
                .onChange(of: isTitleFocused) { _, focused in
                    if !focused { isEditingTitle = false }
                }
        } else {
            PlanNameDisplayView()
        }
    }
    
    // 飲み会名表示ビュー（編集モードでない場合）
    @ViewBuilder
    private func PlanNameDisplayView() -> some View {
        Group {
            if localPlanName.isEmpty {
                Text("飲み会名")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color(UIColor.placeholderText))
                    .italic()
            } else {
                Text(localPlanName)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .onTapGesture {
            isEditingTitle = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTitleFocused = true
            }
        }
    }
    
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
        viewModel.totalAmount.isEmpty ? "未設定" : "¥\(viewModel.formatAmount(viewModel.totalAmount))"
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
    
    // メインステップタブコントロール（目立つ位置に配置）
    @ViewBuilder
    private func MainStepTabControl(selectedStep: Binding<MainStep>) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(MainStep.allCases, id: \.self) { step in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedStep.wrappedValue = step
                    }
                } label: {
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: step.icon)
                            .font(.system(size: DesignSystem.Icon.Size.medium, weight: DesignSystem.Typography.FontWeight.semibold))
                            .foregroundColor(selectedStep.wrappedValue == step ? DesignSystem.Colors.white : DesignSystem.Colors.primary)
                        
                        Text(step.rawValue)
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(selectedStep.wrappedValue == step ? DesignSystem.Colors.white : DesignSystem.Colors.black)
                        
                        Text(step.description)
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(selectedStep.wrappedValue == step ? DesignSystem.Colors.white.opacity(0.9) : DesignSystem.Colors.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadius, style: .continuous)
                            .fill(selectedStep.wrappedValue == step ? DesignSystem.Colors.primary : DesignSystem.Colors.secondaryBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadius, style: .continuous)
                            .stroke(selectedStep.wrappedValue == step ? Color.clear : DesignSystem.Colors.gray3, lineWidth: 1)
                    )
                    .shadow(
                        color: selectedStep.wrappedValue == step ? DesignSystem.Colors.primary.opacity(0.3) : Color.black.opacity(0.05),
                        radius: selectedStep.wrappedValue == step ? 8 : 2,
                        x: 0,
                        y: selectedStep.wrappedValue == step ? 4 : 1
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // メインステップコンテンツビュー
    @ViewBuilder
    private func MainStepContentView(selectedStep: MainStep) -> some View {
        switch selectedStep {
        case .planning:
            PlanningStepContent()
        case .event:
            EventStepContent()
        case .collection:
            CollectionStepContent()
        }
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
                    planEmoji: viewModel.selectedEmoji.isEmpty ? "🍻" : viewModel.selectedEmoji
                )
            }
        }
    }
    
    // 集金ステップのコンテンツ
    @ViewBuilder
    private func CollectionStepContent() -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // 金額設定セクション
            InfoCard(
                title: "金額設定",
                icon: "yensign.circle.fill"
            ) {
                VStack(spacing: DesignSystem.Spacing.md) {
                    AmountSectionContent()
                    
                    // 内訳セクション（内訳がある場合のみ表示）
                    if !viewModel.amountItems.isEmpty {
                        BreakdownSectionContent()
                    }
                }
            }
            
            // 集金管理セクション
            if !viewModel.participants.isEmpty {
                InfoCard(
                    title: "集金管理",
                    icon: "creditcard.fill",
                    isOptional: true
                ) {
                    CollectionManagementContent()
                }
            } else {
                VStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 50))
                        .foregroundColor(DesignSystem.Colors.secondary)
                    Text("参加者なし")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.black)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.xxxl)
            }
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
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("飲み会名と絵文字は上部で設定できます")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondary)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                    
                    // 説明
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("説明（任意）")
                            .font(DesignSystem.Typography.emphasizedSubheadline)
                            .foregroundColor(DesignSystem.Colors.black)
                        TextField("説明を入力", text: $viewModel.editingPlanDescription, axis: .vertical)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.black)
                            .padding(DesignSystem.TextField.Padding.horizontal)
                            .frame(minHeight: DesignSystem.TextField.Height.medium)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                                    .fill(DesignSystem.TextField.backgroundColor)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                                    .stroke(DesignSystem.TextField.borderColor, lineWidth: DesignSystem.TextField.borderWidth)
                            )
                            .lineLimit(3...6)
                            .onChange(of: viewModel.editingPlanDescription) {
                                autoSavePlan()
                            }
                    }
                    
                    // 場所
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("場所（任意）")
                            .font(DesignSystem.Typography.emphasizedSubheadline)
                            .foregroundColor(DesignSystem.Colors.black)
                        TextField("場所を入力", text: $viewModel.editingPlanLocation)
                            .standardTextFieldStyle()
                            .onChange(of: viewModel.editingPlanLocation) {
                                autoSavePlan()
                            }
                    }
                    
                    // 説明文を削除（シンプルに）
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
    @ViewBuilder
    private func ParticipantRow(participant: Participant) -> some View {
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
            
            // ソースバッジ
            if participant.source == .webResponse {
                Text("Web")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.primary)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(DesignSystem.Colors.primary.opacity(0.1))
                    )
            }
            
            // 集金状態
            if participant.hasCollected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(DesignSystem.Colors.success)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                .fill(DesignSystem.Colors.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
    
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
                .onChange(of: viewModel.editingPlanLocation) {
                    autoSavePlan()
                }
                
                // 説明
                SimpleInfoRow(
                    icon: "text.alignleft",
                    value: $viewModel.editingPlanDescription,
                    placeholder: "メモを追加",
                    isMultiline: true
                )
                .onChange(of: viewModel.editingPlanDescription) {
                    autoSavePlan()
                }
            }
        }
    }
    
    // 📅👥 日程＆参加者カード（統合）
    @ViewBuilder
    private func ScheduleAndParticipantsCardView() -> some View {
        VStack(spacing: 24) {
            // 📅 スケジュール調整セクション
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                // セクションヘッダー
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primary)
                    Text("候補日時")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.black)
                }
                
                // スケジュール調整コンテンツ
                ScheduleSectionContent()
            }
            .padding(DesignSystem.Spacing.lg)
            .background(Color(.systemBackground))
            .cornerRadius(DesignSystem.Card.cornerRadius)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            
            // 👥 参加者セクション
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                // セクションヘッダー
                HStack {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primary)
                    Text("参加者")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.black)
                    
                    Spacer()
                    
                    // 参加者数
                    Text("\(viewModel.participants.count)人")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondary)
                }
                
                // Web回答取り込みボタン（スケジュール作成後は常に表示）
                if hasScheduleEvent {
                    Button(action: {
                        Task {
                            await syncWebResponses()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            if webResponsesCount > 0 {
                                Text("回答を同期 (\(webResponsesCount)人)")
                            } else {
                                Text("回答を同期")
                            }
                        }
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(DesignSystem.Button.Padding.vertical)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                                .fill(DesignSystem.Colors.primary.opacity(0.15))
                        )
                    }
                    .padding(.bottom, DesignSystem.Spacing.sm)
                }
                
                // 参加者リスト
                if viewModel.participants.isEmpty {
                    Text("参加者がいません")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.lg)
                } else {
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(viewModel.participants) { participant in
                            ParticipantRow(participant: participant)
                        }
                    }
                }
                
                // 手動で参加者追加ボタン
                Button(action: {
                    showingAddParticipant = true
                }) {
                    Label("参加者を追加", systemImage: "plus.circle.fill")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(DesignSystem.Button.Padding.vertical)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                                .fill(DesignSystem.Colors.primary.opacity(0.1))
                        )
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .background(Color(.systemBackground))
            .cornerRadius(DesignSystem.Card.cornerRadius)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            .onAppear {
                // 画面表示時に自動的にWeb回答をチェック・取り込み
                if hasScheduleEvent, let event = scheduleEvent {
                    Task {
                        await autoCheckAndSyncResponses(eventId: event.id)
                    }
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
    
    // 集金管理コンテンツ
    @ViewBuilder
    private func CollectionManagementContent() -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
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
        }
    }
    
    // 保存ボタン
    @ViewBuilder
    private func SaveButton() -> some View {
        Button {
            // 既に自動保存されているので、トップに戻る
            onFinish?()
        } label: {
            Label("完了", systemImage: "checkmark")
        }
        .primaryButtonStyle()
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
                    TextField("項目名（例：二次会、カラオケ代）空欄可", text: $additionalItemName)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.black)
                    
                    HStack {
                        Text("金額")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.black)
                        Spacer()
                        TextField("金額を入力（例：1000）", text: $additionalAmount)
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
                    Text("内訳項目の追加")
                        .font(DesignSystem.Typography.headline)
                }
            }
            .navigationTitle("金額の追加")
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
                    .disabled(additionalAmount.isEmpty)
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
                    TextField("項目名（例：二次会、カラオケ代）空欄可", text: $editingItemName)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.black)
                    
                    HStack {
                        Text("金額")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.black)
                        Spacer()
                        TextField("金額を入力（例：1000）", text: $editingAmount)
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
                    Text("内訳項目の編集")
                        .font(DesignSystem.Typography.headline)
                }
            }
            .navigationTitle("金額の編集")
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
                    .disabled(editingAmount.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    // 絵文字選択ダイアログビュー
    @ViewBuilder
    private func EmojiPickerView() -> some View {
        NavigationStack {
            Form {
                Section {
                    // ランダム絵文字ボタン
                    Button(action: {
                        viewModel.selectedEmoji = availableEmojis.randomElement() ?? "🍻"
                        showEmojiPicker = false
                    }) {
                        HStack {
                            Image(systemName: "dice")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                            Text("ランダムな絵文字を使用")
                                .foregroundColor(.blue)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("ランダム")
                }
                
                // 絵文字キーボードからの入力セクション
                Section {
                    TextField("タップして絵文字を入力", text: $viewModel.selectedEmoji)
                        .font(.system(size: 36))
                        .multilineTextAlignment(.center)
                        .keyboardType(.default) // 標準キーボード（絵文字切り替え可能）
                        .submitLabel(.done)
                        .onChange(of: viewModel.selectedEmoji) { _, newValue in
                            if newValue.count > 1 {
                                // 最初の絵文字だけを取り出す
                                if let firstChar = newValue.first {
                                    viewModel.selectedEmoji = String(firstChar)
                                }
                            }
                        }
                        .onSubmit {
                            if !viewModel.selectedEmoji.isEmpty {
                                showEmojiPicker = false
                            }
                        }
                        .padding(.vertical, 8)
                } header: {
                    Text("絵文字キーボードから入力")
                } footer: {
                    Text("キーボードの🌐または😀ボタンをタップして絵文字キーボードに切り替えてください")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    SimpleEmojiGridRow(emojis: ["🍻", "🍺", "🥂", "🍷"])
                    SimpleEmojiGridRow(emojis: ["🍸", "🍹", "🍾", "🥃"])
                } header: {
                    Text("飲み物")
                }
                
                Section {
                    SimpleEmojiGridRow(emojis: ["🍴", "🍖", "🍗", "🍣"])
                    SimpleEmojiGridRow(emojis: ["🍕", "🍔", "🍙", "🍱"])
                } header: {
                    Text("食べ物")
                }
                
                Section {
                    SimpleEmojiGridRow(emojis: ["🤮", "🤢", "🥴", "🤪"])
                    SimpleEmojiGridRow(emojis: ["😵‍💫", "💸", "💰", "💯"])
                    SimpleEmojiGridRow(emojis: ["😂", "😆", "😅", "😬"])
                    SimpleEmojiGridRow(emojis: ["😇", "😍", "😎", "😤"])
                    SimpleEmojiGridRow(emojis: ["😳", "🤭", "😈", "🙈"])
                    SimpleEmojiGridRow(emojis: ["💀", "🤡", "🐒", "🦛"])
                    SimpleEmojiGridRow(emojis: ["😹", "😵", "🥳", "😶‍🌫️"])
                } header: {
                    Text("エモーション")
                }
                
                Section {
                    SimpleEmojiGridRow(emojis: ["🎉", "🎊", "✨", "🎵"])
                    SimpleEmojiGridRow(emojis: ["🎤", "🕺", "💃", "👯‍♂️"])
                } header: {
                    Text("パーティー")
                }
            }
            .navigationTitle("絵文字を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        showEmojiPicker = false
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    // シンプルな絵文字グリッド行
    @ViewBuilder
    private func SimpleEmojiGridRow(emojis: [String]) -> some View {
        HStack(spacing: 0) {
            ForEach(emojis, id: \.self) { emoji in
                Button(action: {
                    viewModel.selectedEmoji = emoji
                    showEmojiPicker = false
                }) {
                    Text(emoji)
                        .font(.system(size: 30))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // サブビュー：金額セクションの内容
    @ViewBuilder
    private func AmountSectionContent() -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Text("¥")
                .font(DesignSystem.Typography.title2)
                .foregroundColor(DesignSystem.Colors.secondary)
            
            TextField("0", text: $viewModel.totalAmount)
                .font(DesignSystem.Typography.title2)
                .foregroundColor(DesignSystem.Colors.black)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .focused($focusedField, equals: .totalAmount)
                .onChange(of: viewModel.totalAmount) { _, newValue in
                    let formatted = viewModel.formatAmount(newValue)
                    if formatted != newValue {
                        viewModel.totalAmount = formatted
                    }
                }
                .padding(DesignSystem.TextField.Padding.horizontal)
                .frame(height: DesignSystem.TextField.Height.medium)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                        .fill(focusedField == .totalAmount ? DesignSystem.TextField.focusedBackgroundColor : DesignSystem.TextField.backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                        .stroke(focusedField == .totalAmount ? DesignSystem.TextField.focusedBorderColor : DesignSystem.TextField.borderColor, lineWidth: DesignSystem.TextField.borderWidth)
                )
            
            Button(action: {
                showAddAmountDialog = true
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: DesignSystem.Icon.Size.large))
                    .foregroundColor(DesignSystem.Colors.primary)
            }
        }
    }
    
    // サブビュー：内訳セクションの内容
    @ViewBuilder
    private func BreakdownSectionContent() -> some View {
        // 内訳ボタン
        Button(action: {
            withAnimation {
                isBreakdownExpanded.toggle()
            }
        }) {
            HStack {
                Text("内訳")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(isBreakdownExpanded ? "閉じる" : "表示")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Image(systemName: isBreakdownExpanded ? "chevron.up" : "chevron.down")
                        .imageScale(.small)
                        .foregroundColor(.blue)
                }
            }
        }
        
        // 内訳リスト（開いているときのみ表示）
        if isBreakdownExpanded {
            ForEach(viewModel.amountItems) { item in
                BreakdownItemRow(item: item)
            }
            .onDelete(perform: deleteAmountItem)
        }
    }
    
    // サブビュー：内訳項目の行
    @ViewBuilder
    private func BreakdownItemRow(item: AmountItem) -> some View {
        Button(action: {
            startEditingAmount(item)
        }) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
                
                Text(item.name)
                    .font(.footnote)
                    .lineLimit(1)
                
                Spacer()
                
                Text("¥\(viewModel.formatAmount(String(item.amount)))")
                    .font(.footnote)
                    .foregroundColor(.blue)
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 8) // 最初の項目に上部余白を追加
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
    
    // 自動保存処理
    private func autoSavePlan() {
        viewModel.editingPlanName = localPlanName
        // 確定情報も一緒に保存
        // dateパラメータは確定日時があればそれを使い、なければ現在日時
        viewModel.savePlan(
            name: localPlanName,
            date: confirmedDate ?? Date(),
            description: viewModel.editingPlanDescription.isEmpty ? nil : viewModel.editingPlanDescription,
            location: viewModel.editingPlanLocation.isEmpty ? nil : viewModel.editingPlanLocation,
            confirmedDate: confirmedDate,
            confirmedLocation: confirmedLocation.isEmpty ? nil : confirmedLocation,
            confirmedParticipants: Array(selectedParticipantIds)
        )
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
        scheduleTitle = localPlanName.isEmpty ? (planName.isEmpty ? "無題の飲み会" : planName) : localPlanName
        scheduleDescription = viewModel.editingPlanDescription
        scheduleLocation = viewModel.editingPlanLocation
        let amountString = viewModel.totalAmount.filter { $0.isNumber }
        if !amountString.isEmpty, let amount = Int(amountString) {
            scheduleBudget = String(amount)
        } else {
            scheduleBudget = ""
        }
        scheduleCandidateDates = event.candidateDates
        
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
                        Text(hasScheduleEvent ? "URLを更新して公開" : "URLを発行して公開")
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
                    
                    // URL表示シートを表示
                    print("🔗 URLシート表示: showingScheduleUrlSheet = true")
                    showingScheduleUrlSheet = true
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
                }
            } catch {
                print("スケジュール更新エラー: \(error)")
                // エラーハンドリング
            }
        }
    }
    
    // スケジュール表示ビュー
    @ViewBuilder
    private func ScheduleDisplayView(
        event: ScheduleEvent,
        scheduleViewModel: ScheduleManagementViewModel,
        onShowUrl: @escaping () -> Void,
        onEdit: @escaping () -> Void
    ) -> some View {
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
                Button(action: {
                    showingSchedulePreview = true
                }) {
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
    }
    
    // スケジュールプレビューシート
    @ViewBuilder
    private func SchedulePreviewSheet(
        scheduleEvent: ScheduleEvent?,
        scheduleTitle: String,
        scheduleDescription: String,
        scheduleCandidateDates: [Date],
        scheduleLocation: String,
        scheduleBudget: String,
        scheduleViewModel: ScheduleManagementViewModel
    ) -> some View {
        NavigationStack {
            if let event = scheduleEvent {
                // WebViewでweb-frontendのページを表示
                ScheduleWebView(event: event, viewModel: scheduleViewModel)
            } else {
                // イベントが作成されていない場合はローディング表示
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
                            showingSchedulePreview = false
                        }
                    }
                }
            }
        }
    }
    
}

// カスタムトグルスタイル
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

// コンパクトなスイッチトグルスタイル
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

// MARK: - PrePlan Schedule Empty State View
/// プレプラン画面用：スケジュール未作成状態の表示（プレビュー・編集ボタン付き）
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
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadius, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

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
                TextField(placeholder, text: $value, axis: .vertical)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.black)
                    .lineLimit(2...4)
            } else {
                TextField(placeholder, text: $value)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.black)
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
}

#Preview {
    NavigationStack {
        PrePlanView(viewModel: PrePlanViewModel(), planName: "Sample Plan", planDate: Date())
    }
}

