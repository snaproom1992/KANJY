import SwiftUI
import Combine

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
    
    public init(id: UUID = UUID(), name: String, roleType: RoleType, hasCollected: Bool = false, hasFixedAmount: Bool = false, fixedAmount: Int = 0) {
        self.id = id
        self.name = name
        self.roleType = roleType
        self.hasCollected = hasCollected
        self.hasFixedAmount = hasFixedAmount
        self.fixedAmount = fixedAmount
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
    @State private var hasScheduleEvent = false // スケジュール調整済みかどうか
    @State private var showingHelpGuide = false
    
    // スケジュール作成用の状態変数（インライン作成用）
    @State private var isCreatingSchedule = false
    @State private var scheduleTitle = ""
    @State private var scheduleDescription = ""
    @State private var scheduleCandidateDates: [Date] = []
    @State private var scheduleLocation = ""
    @State private var scheduleBudget = ""
    @State private var scheduleDeadline: Date?
    @State private var hasScheduleDeadline = false
    @State private var showingScheduleDatePicker = false
    @State private var selectedScheduleDate = Date()
    @State private var isEditingSchedule = false
    
    // 開催確定用の状態変数
    @State private var confirmedDate: Date?
    @State private var confirmedLocation: String = ""
    @State private var selectedParticipantIds: Set<UUID> = []
    @State private var showingInvitationGenerator = false
    
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
        case basicInfo = "基本情報"
        case participants = "参加者"
        case schedule = "スケジュール"
        
        var icon: String {
            switch self {
            case .basicInfo: return "info.circle.fill"
            case .participants: return "person.2.fill"
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
    
    // 参加者セルのビュー
    private func participantCell(_ participant: Participant) -> some View {
        HStack {
            // 参加者情報部分（ここをタップすると編集画面に遷移）
            Button(action: { startEdit(participant) }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                        Text(participant.name)
                            .font(.body)
                            .foregroundColor(.primary)
                            
                            // スケジュール調整の結果を表示
                            if hasScheduleEvent, let event = scheduleEvent {
                                let response = event.responses.first { $0.participantName == participant.name }
                                if let response = response {
                                    Image(systemName: response.status == .attending ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(response.status == .attending ? .green : .red)
                                        .imageScale(.small)
                                }
                            }
                        }
                        
                        // 役職名と倍率を直接参照
                        switch participant.roleType {
                        case .standard(let role):
                            Text("\(role.name) ×\(String(format: "%.1f", role.defaultMultiplier))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        case .custom(let customRole):
                            Text("\(customRole.name) ×\(String(format: "%.1f", customRole.multiplier))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            // 金額表示部分（Textのみ）
            if viewModel.totalAmount.filter({ $0.isNumber }).isEmpty {
                Text("¥---")
                    .font(.headline)
                    .foregroundColor(.gray)
            } else {
                let amount = viewModel.paymentAmount(for: participant)
                Text("¥\(viewModel.formatAmount(String(amount)))")
                    .font(.headline)
                    .foregroundColor(participant.hasCollected ? .green : .blue)
            }
            // 集金確認用のトグル
            Toggle("", isOn: Binding(
                get: { participant.hasCollected },
                set: { newValue in
                    viewModel.updateCollectionStatus(participant: participant, hasCollected: newValue)
                }
            ))
            .labelsHidden()
            .toggleStyle(CompactSwitchToggleStyle())
            .padding(.leading, 8)
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                confirmDelete(participant: participant)
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
        .contextMenu {
            Button(action: {
                startEdit(participant)
            }) {
                Label("編集", systemImage: "pencil")
            }
            Button(action: {
                viewModel.updateCollectionStatus(participant: participant, hasCollected: !participant.hasCollected)
            }) {
                if participant.hasCollected {
                    Label("未集金に変更", systemImage: "circle")
                } else {
                    Label("集金済みに変更", systemImage: "checkmark.circle")
                }
            }
            Button(action: {
                toggleFixedAmount(participant)
            }) {
                if participant.hasFixedAmount {
                    Label("金額固定を解除", systemImage: "lock.open")
                } else {
                    Label("金額を固定", systemImage: "lock")
                }
            }
            Divider()
            Button(role: .destructive, action: {
                confirmDelete(participant: participant)
            }) {
                Label("削除", systemImage: "trash")
            }
        }
    }
    
    // 金額固定のトグル
    private func toggleFixedAmount(_ participant: Participant) {
        if let index = viewModel.participants.firstIndex(where: { $0.id == participant.id }) {
            var updatedParticipant = viewModel.participants[index]
            updatedParticipant.hasFixedAmount = !updatedParticipant.hasFixedAmount
            
            if updatedParticipant.hasFixedAmount && updatedParticipant.fixedAmount == 0 {
                // 金額固定をオンにする場合、現在の計算金額を設定
                updatedParticipant.fixedAmount = viewModel.paymentAmount(for: participant)
            }
            
            viewModel.participants[index] = updatedParticipant
            viewModel.saveData()
        }
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
                } else {
                    // 新規作成時はスケジュールイベントなし
                    scheduleEvent = nil
                    hasScheduleEvent = false
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
            VStack(spacing: DesignSystem.Spacing.lg) {
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
                
                // メインステップタブコントロール（目立つ位置に配置）
                MainStepTabControl(selectedStep: $selectedStep)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.md)
                
                // 選択されたステップのコンテンツを表示
                MainStepContentView(selectedStep: selectedStep)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, 100) // 下部ボタン用のスペース
            }
            .padding(.top, DesignSystem.Spacing.xxl)
            .padding(.bottom, DesignSystem.Spacing.xl)
            .onChange(of: selectedTask) { _, newTask in
                // スケジュールタブが選択されたとき、スケジュール調整が未作成なら自動的にフォームを表示
                if newTask == .schedule && !hasScheduleEvent && !isCreatingSchedule && !isEditingSchedule {
                    startCreatingSchedule()
                }
            }
            .onChange(of: selectedStep) { _, newStep in
                // ステップ変更時の処理
                if newStep == .planning {
                    // 企画タブに戻ったときの処理
                } else if newStep == .event {
                    // 開催タブに移動したときの処理
                } else if newStep == .collection {
                    // 集金タブに移動したときの処理
                }
            }
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
                    value: confirmedDate != nil ? scheduleViewModel.formatDateTime(confirmedDate!) : "未設定"
                )
                
                // 参加者数
                SummaryItem(
                    icon: "person.2.fill",
                    label: "参加者",
                    value: "\(viewModel.participants.count)人"
                )
                
                // 合計金額
                SummaryItem(
                    icon: "yensign.circle.fill",
                    label: "合計金額",
                    value: viewModel.totalAmount.isEmpty ? "未設定" : "¥\(viewModel.formatAmount(viewModel.totalAmount))"
                )
                
                // 集金状況
                SummaryItem(
                    icon: "creditcard.fill",
                    label: "集金状況",
                    value: {
                        let collectedCount = viewModel.participants.filter { $0.hasCollected }.count
                        let totalCount = viewModel.participants.count
                        if totalCount == 0 {
                            return "未設定"
                        } else if collectedCount == totalCount {
                            return "完了"
                        } else {
                            return "\(collectedCount)/\(totalCount)"
                        }
                    }()
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
            
            // 確定参加者
            InfoCard(
                title: "確定参加者",
                icon: "person.2.fill"
            ) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    if viewModel.participants.isEmpty {
                        Text("参加者がいません")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondary)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                    } else {
                        // スケジュール調整の結果から参加者を選択
                        if hasScheduleEvent, let event = scheduleEvent {
                            let attendingResponses = event.responses.filter { $0.status == .attending }
                            if !attendingResponses.isEmpty {
                                Button(action: {
                                    // スケジュール調整で参加と回答した人を自動選択
                                    let attendingNames = Set(attendingResponses.map { $0.participantName })
                                    selectedParticipantIds = Set(viewModel.participants.filter { attendingNames.contains($0.name) }.map { $0.id })
                                }) {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(DesignSystem.Colors.success)
                                        Text("スケジュール調整の結果から自動選択（\(attendingResponses.count)人）")
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundColor(DesignSystem.Colors.primary)
                                    }
                                }
                                .padding(.bottom, DesignSystem.Spacing.xs)
                            }
                        }
                        
                        // 参加者リスト
                        ForEach(viewModel.participants) { participant in
                            HStack {
                                Button(action: {
                                    if selectedParticipantIds.contains(participant.id) {
                                        selectedParticipantIds.remove(participant.id)
                                    } else {
                                        selectedParticipantIds.insert(participant.id)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: selectedParticipantIds.contains(participant.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedParticipantIds.contains(participant.id) ? DesignSystem.Colors.success : DesignSystem.Colors.gray4)
                                        Text(participant.name)
                                            .font(DesignSystem.Typography.body)
                                            .foregroundColor(DesignSystem.Colors.black)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, DesignSystem.Spacing.xs)
                        }
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
                let confirmedParticipants = viewModel.participants.filter { selectedParticipantIds.contains($0.id) }
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
                    Text("参加者がいません")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.black)
                    Text("まず「企画」タブで参加者を追加してください")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondary)
                        .multilineTextAlignment(.center)
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
                    .tag(task)
            }
        }
        .pickerStyle(.segmented)
        .frame(height: 44) // タブの高さを高くして存在感を出す
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
                            .onChange(of: viewModel.editingPlanDescription) { _ in
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
                            .onChange(of: viewModel.editingPlanLocation) { _ in
                                autoSavePlan()
                            }
                    }
                    
                    // 予算
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("予算（任意）")
                            .font(DesignSystem.Typography.emphasizedSubheadline)
                            .foregroundColor(DesignSystem.Colors.black)
                        TextField("予算を入力", text: $viewModel.totalAmount)
                            .standardTextFieldStyle()
                            .keyboardType(.numberPad)
                            .onChange(of: viewModel.totalAmount) { _ in
                                autoSavePlan()
                            }
                    }
                    
                    Text("日程は「スケジュール調整」で候補日時を設定し、「開催」タブで確定してください")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondary)
                        .padding(.vertical, DesignSystem.Spacing.xs)
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
                
            case .participants:
                ParticipantSectionContent()
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
                        let emojis = ["🍻", "🍺", "🥂", "🍷", "🍸", "🍹", "🍾", "🥃", "🍴", "🍖", "🍗", "🍣", "🍕", "🍔", "🥩", "🍙", "🤮", "🤢", "🥴", "��", "😵‍💫", "💸", "🎊"]
                        viewModel.selectedEmoji = emojis.randomElement() ?? "🍻"
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
    
    // サブビュー：参加者セクションの内容
    @ViewBuilder
    private func ParticipantSectionContent() -> some View {
        // 新規参加者追加フォーム
        HStack(spacing: DesignSystem.Spacing.sm) {
            TextField("参加者名を入力", text: $newParticipant)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.black)
                .focused($focusedField, equals: .newParticipant)
                .submitLabel(.done)
                .onSubmit {
                    if !newParticipant.isEmpty {
                        viewModel.addParticipant(name: newParticipant, roleType: viewModel.selectedRoleType)
                        newParticipant = ""
                        focusedField = nil
                    }
                }
                .padding(DesignSystem.TextField.Padding.horizontal)
                .frame(height: DesignSystem.TextField.Height.medium)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                        .fill(focusedField == .newParticipant ? DesignSystem.TextField.focusedBackgroundColor : DesignSystem.TextField.backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                        .stroke(focusedField == .newParticipant ? DesignSystem.TextField.focusedBorderColor : DesignSystem.TextField.borderColor, lineWidth: DesignSystem.TextField.borderWidth)
                )
            
            RolePickerMenu()
            
            Button(action: {
                if !newParticipant.isEmpty {
                    viewModel.addParticipant(name: newParticipant, roleType: viewModel.selectedRoleType)
                    newParticipant = ""
                    focusedField = nil
                }
            }) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.blue)
                    .imageScale(.large)
            }
        }
        .padding(.vertical, 8)
        
        // 参加者リスト
        ForEach(viewModel.participants) { participant in
            participantCell(participant)
        }
        
        // スワイプヒント
        if !viewModel.participants.isEmpty && showSwipeHint {
            SwipeHintView()
        }
    }
    
    // サブビュー：役職選択メニュー
    @ViewBuilder
    private func RolePickerMenu() -> some View {
        Menu {
            // 標準役職
            ForEach(Role.allCases) { role in
                Button(action: {
                    viewModel.selectedRoleType = .standard(role)
                }) {
                    HStack {
                        Text("\(role.name) ×\(String(format: "%.1f", role.defaultMultiplier))")
                        if case .standard(let selectedRole) = viewModel.selectedRoleType,
                           selectedRole == role {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            
            // カスタム役職
            if !viewModel.customRoles.isEmpty {
                Divider()
                ForEach(viewModel.customRoles) { role in
                    Button(action: {
                        viewModel.selectedRoleType = .custom(role)
                    }) {
                        HStack {
                            Text("\(role.name) ×\(String(format: "%.1f", role.multiplier))")
                            if case .custom(let selectedRole) = viewModel.selectedRoleType,
                               selectedRole.id == role.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            RolePickerLabel()
        }
        .buttonStyle(.bordered)
    }
    
    // サブビュー：役職選択ラベル
    @ViewBuilder
    private func RolePickerLabel() -> some View {
        HStack {
            switch viewModel.selectedRoleType {
            case .standard(let role):
                Text("\(role.name)")
                    .foregroundColor(.blue)
                Text("×\(String(format: "%.1f", role.defaultMultiplier))")
                    .foregroundColor(.secondary)
            case .custom(let customRole):
                Text("\(customRole.name)")
                    .foregroundColor(.blue)
                Text("×\(String(format: "%.1f", customRole.multiplier))")
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 80)
    }
    
    // サブビュー：スワイプヒント
    @ViewBuilder
    private func SwipeHintView() -> some View {
        ZStack {
            Color.clear
                .frame(height: 30)
            
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left")
                        .imageScale(.small)
                    Text("スワイプして削除")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                )
                .offset(x: swipeHintOffset)
                .padding(.trailing)
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .transition(.opacity)
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
            if hasScheduleEvent, let event = scheduleEvent, !isEditingSchedule {
                // スケジュール調整済みの場合（表示モード）
                ScheduleDisplayView(
                    event: event,
                    scheduleViewModel: scheduleViewModel,
                    onShowUrl: {
                        showingScheduleUrlSheet = true
                    },
                    onEdit: {
                        startEditingSchedule(event: event)
                    }
                )
            } else {
                // スケジュール作成・編集フォーム（インライン表示）
                // 未作成の場合は自動的にフォームを表示（onAppearで初期化）
                ScheduleCreationFormView()
                    .onAppear {
                        // 基本情報から自動的に引き継ぐ
                        if !isCreatingSchedule && !isEditingSchedule {
                            startCreatingSchedule()
                        }
                    }
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
    
    // スケジュール編集開始
    private func startEditingSchedule(event: ScheduleEvent) {
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
        scheduleDeadline = event.deadline
        hasScheduleDeadline = event.deadline != nil
        isEditingSchedule = true
    }
    
    // スケジュール作成・編集フォーム
    @ViewBuilder
    private func ScheduleCreationFormView() -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // 基本情報から自動的に引き継がれることを説明
            Text("タイトル、説明、場所、予算は「基本情報」タブで設定した内容が使用されます")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.secondary)
                .padding(.vertical, DesignSystem.Spacing.xs)
            
            // 候補日時
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("候補日時")
                    .font(DesignSystem.Typography.emphasizedSubheadline)
                    .foregroundColor(DesignSystem.Colors.black)
                
                if scheduleCandidateDates.isEmpty {
                    Text("候補日時が設定されていません")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondary)
                        .italic()
                        .padding(.vertical, DesignSystem.Spacing.sm)
                } else {
                    ForEach(scheduleCandidateDates.sorted(), id: \.self) { date in
                        HStack {
                            Text(scheduleViewModel.formatDateTime(date))
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(DesignSystem.Colors.black)
                            Spacer()
                            Button(action: {
                                scheduleCandidateDates.removeAll { $0 == date }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(DesignSystem.Colors.alert)
                            }
                        }
                        .padding(DesignSystem.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                                .fill(DesignSystem.Colors.gray1)
                        )
                    }
                }
                
                Button(action: {
                    selectedScheduleDate = scheduleCandidateDates.last ?? (confirmedDate ?? planDate ?? Date())
                    showingScheduleDatePicker = true
                }) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(DesignSystem.Colors.primary)
                        Text("候補日時を追加")
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
            
            // 回答期限
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
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
                }
            }
            
            // アクションボタン
            HStack(spacing: DesignSystem.Spacing.md) {
                Button(action: {
                    cancelScheduleCreation()
                }) {
                    Text("キャンセル")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.black)
                        .frame(maxWidth: .infinity)
                        .padding(DesignSystem.Button.Padding.vertical)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                                .fill(DesignSystem.Colors.gray3.opacity(0.2))
                        )
                }
                
                Button(action: {
                    if isEditingSchedule {
                        updateScheduleEvent()
                    } else {
                        createScheduleEvent()
                    }
                }) {
                    Text(isEditingSchedule ? "更新" : "作成")
                        .font(DesignSystem.Typography.body)
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
        }
        .sheet(isPresented: $showingScheduleDatePicker) {
            DatePickerSheet(
                selectedDate: $selectedScheduleDate,
                onAdd: {
                    scheduleCandidateDates.append(selectedScheduleDate)
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
    
    // スケジュール作成キャンセル
    private func cancelScheduleCreation() {
        isCreatingSchedule = false
        isEditingSchedule = false
    }
    
    // スケジュール作成
    private func createScheduleEvent() {
        guard canCreateSchedule else { return }
        
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
                
                await MainActor.run {
                    scheduleEvent = event
                    hasScheduleEvent = true
                    isCreatingSchedule = false
                    
                    // PlanにscheduleEventIdを紐づける
                    if let planId = viewModel.editingPlanId,
                       let planIndex = viewModel.savedPlans.firstIndex(where: { $0.id == planId }) {
                        viewModel.savedPlans[planIndex].scheduleEventId = event.id
                        viewModel.saveData()
                    }
                    
                    // 確定日時に反映
                    if let optimalDate = event.optimalDate {
                        confirmedDate = optimalDate
                    }
                    
                    // URL表示シートを表示
                    showingScheduleUrlSheet = true
                }
            } catch {
                print("スケジュール作成エラー: \(error)")
                // エラーハンドリング（必要に応じてアラート表示）
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
                        isEditingSchedule = false
                        
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
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(DesignSystem.Colors.success)
                Text("スケジュール調整完了")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.success)
                Spacer()
            }
            
            Text(event.title)
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.secondary)
            
            if let optimalDate = event.optimalDate {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "calendar")
                        .foregroundColor(DesignSystem.Colors.primary)
                    Text("決定日時: \(scheduleViewModel.formatDateTime(optimalDate))")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.black)
                }
            }
            
            // 参加者状況の表示
            let attendingCount = event.responses.filter { $0.status == .attending }.count
            let totalResponses = event.responses.count
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "person.2")
                    .foregroundColor(DesignSystem.Colors.primary)
                Text("参加者: \(attendingCount)/\(totalResponses)人")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.black)
            }
            
            HStack(spacing: DesignSystem.Spacing.md) {
                Button(action: onShowUrl) {
                    Label("URLを表示", systemImage: "link")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(DesignSystem.Button.Padding.vertical)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                                .fill(DesignSystem.Colors.primary.opacity(0.1))
                        )
                }
                
                Button(action: onEdit) {
                    Label("編集", systemImage: "pencil")
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
        }
        .padding(DesignSystem.Card.Padding.medium)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                .fill(DesignSystem.Colors.gray1)
        )
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

#Preview {
    NavigationStack {
        PrePlanView(viewModel: PrePlanViewModel(), planName: "Sample Plan", planDate: Date())
    }
}

