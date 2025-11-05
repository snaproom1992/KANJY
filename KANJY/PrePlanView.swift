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
    @Environment(\.dismiss) private var dismiss
    
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
    @State private var showScheduleCreation = false
    @State private var showScheduleEdit = false
    @State private var scheduleEvent: ScheduleEvent?
    @State private var showingScheduleUrlSheet = false
    @State private var hasScheduleEvent = false // スケジュール調整済みかどうか
    @State private var showingHelpGuide = false
    
    // タスク選択（セグメントコントロール用）
    enum TaskSection: String, CaseIterable {
        case basicInfo = "基本情報"
        case participants = "参加者"
        case amount = "金額"
        case schedule = "スケジュール"
        case collection = "集金"
        
        var icon: String {
            switch self {
            case .basicInfo: return "info.circle.fill"
            case .participants: return "person.2.fill"
            case .amount: return "yensign.circle.fill"
            case .schedule: return "calendar"
            case .collection: return "creditcard.fill"
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
            .sheet(isPresented: $showScheduleCreation) {
                NavigationStack {
                    // 現在の飲み会計画から情報を引き継いでスケジュール調整を作成
                    CreateScheduleEventView(
                        viewModel: scheduleViewModel,
                        plan: Plan(
                            name: localPlanName.isEmpty ? (planName.isEmpty ? "無題の飲み会" : planName) : localPlanName,
                            date: localPlanDate ?? planDate ?? Date(),
                            participants: viewModel.participants,
                            totalAmount: viewModel.totalAmount,
                            roleMultipliers: viewModel.currentRoleMultipliers,
                            roleNames: viewModel.currentRoleNames,
                            amountItems: viewModel.amountItems,
                            emoji: viewModel.selectedEmoji
                        )
                    ) { event in
                        // イベント作成完了時の処理
                        scheduleEvent = event
                        hasScheduleEvent = true
                        showingScheduleUrlSheet = true
                        showScheduleCreation = false
                        
                        // 開催日に反映
                        if let optimalDate = event.optimalDate {
                            localPlanDate = optimalDate
                        }
                    }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showScheduleEdit) {
                if let event = scheduleEvent {
                    NavigationStack {
                        EditScheduleEventView(event: event, viewModel: scheduleViewModel)
                            .onDisappear {
                                // 編集画面が閉じられたら、更新されたイベントを取得
                                if let updatedEvent = scheduleViewModel.events.first(where: { $0.id == event.id }) {
                                    scheduleEvent = updatedEvent
                                    
                                    // 開催日に反映
                                    if let optimalDate = updatedEvent.optimalDate {
                                        localPlanDate = optimalDate
                                    }
                                }
                            }
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
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
    @ViewBuilder
    // 現在のステップを計算
    private var currentStep: PartySetupStep {
        if !localPlanName.isEmpty && localPlanDate != nil {
            if !viewModel.participants.isEmpty {
                if !viewModel.totalAmount.isEmpty {
                    return .amount
                }
                return .participants
            }
        }
        return .basicInfo
    }
    
    // 完了状況を計算
    private var completionStatus: [PartySetupStep: Bool] {
        [
            .basicInfo: !localPlanName.isEmpty && localPlanDate != nil,
            .participants: !viewModel.participants.isEmpty,
            .amount: !viewModel.totalAmount.isEmpty,
            .schedule: hasScheduleEvent,
            .collection: viewModel.participants.filter { $0.hasCollected }.count > 0
        ]
    }
    
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
                
                // タスクセグメントコントロール
                TaskSegmentControl(selectedTask: $selectedTask)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                
                // 選択されたタスクのコンテンツを表示
                TaskContentView(selectedTask: selectedTask)
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
                // 開催日
                SummaryItem(
                    icon: "calendar",
                    label: "開催日",
                    value: localPlanDate != nil ? viewModel.formatDate(localPlanDate!) : "未設定"
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
    
    // タスクセグメントコントロール
    @ViewBuilder
    private func TaskSegmentControl(selectedTask: Binding<TaskSection>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(TaskSection.allCases, id: \.self) { task in
                    // 集金タスクは参加者がいる場合のみ表示
                    if task == .collection && viewModel.participants.isEmpty {
                        EmptyView()
                    } else {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                selectedTask.wrappedValue = task
                            }
                        } label: {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: task.icon)
                                    .font(.system(size: DesignSystem.Icon.Size.small))
                                Text(task.rawValue)
                                    .font(DesignSystem.Typography.caption)
                            }
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                                    .fill(selectedTask.wrappedValue == task ? DesignSystem.Colors.primary : DesignSystem.Colors.gray1)
                            )
                            .foregroundColor(selectedTask.wrappedValue == task ? DesignSystem.Colors.white : DesignSystem.Colors.black)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, DesignSystem.Spacing.sm)
        }
    }
    
    // タスクコンテンツビュー
    @ViewBuilder
    private func TaskContentView(selectedTask: TaskSection) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            switch selectedTask {
            case .basicInfo:
                InfoCard(
                    title: "基本情報",
                    icon: "info.circle.fill"
                ) {
                    DateSectionContent()
                }
                
            case .participants:
                InfoCard(
                    title: "参加者",
                    icon: "person.2.fill"
                ) {
                    ParticipantSectionContent()
                }
                
            case .amount:
                InfoCard(
                    title: "金額",
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
                
            case .schedule:
                InfoCard(
                    title: "スケジュール調整",
                    icon: "calendar",
                    isOptional: true
                ) {
                    ScheduleSectionContent()
                }
                
            case .collection:
                if !viewModel.participants.isEmpty {
                    InfoCard(
                        title: "集金管理",
                        icon: "creditcard.fill",
                        isOptional: true
                    ) {
                        CollectionManagementContent()
                    }
                }
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
    
    // プラン内容リスト（旧実装、削除予定）
    @ViewBuilder
    private func PlanContentList() -> some View {
        List {
            // ステップ1: 基本情報セクション（飲み会名と絵文字は上部に表示済み）
            Section {
                DateSectionContent()
            } header: {
                HStack {
                    StepHeaderView(
                        step: .basicInfo,
                        isCompleted: completionStatus[.basicInfo] ?? false,
                        isCurrent: currentStep == .basicInfo
                    )
                }
            } footer: {
                Text("飲み会名と絵文字は上部で設定できます")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // ステップ2: 参加者セクション
            Section {
                ParticipantSection()
            } header: {
                HStack {
                    StepHeaderView(
                        step: .participants,
                        isCompleted: completionStatus[.participants] ?? false,
                        isCurrent: currentStep == .participants
                    )
                }
            }
            
            // ステップ3: 金額セクション
            Section {
                AmountSectionContent()
            } header: {
                HStack {
                    StepHeaderView(
                        step: .amount,
                        isCompleted: completionStatus[.amount] ?? false,
                        isCurrent: currentStep == .amount
                    )
                }
            }
            .listSectionSpacing(.compact) // セクション間の余白を狭く
            
            // 内訳セクション（ボタンとリストを1つのセクションに）
            if !viewModel.amountItems.isEmpty {
                BreakdownSection()
            }
            
            // ステップ4: スケジュール調整セクション（オプション）
            Section {
                ScheduleSectionContent()
            } header: {
                HStack {
                    StepHeaderView(
                        step: .schedule,
                        isCompleted: completionStatus[.schedule] ?? false,
                        isCurrent: currentStep == .schedule
                    )
                }
            }
            
            // ステップ5: 集金管理セクション（オプション）
            if !viewModel.participants.isEmpty {
                Section {
                    // 集金状況サマリー
                    HStack {
                        let collectedCount = viewModel.participants.filter { $0.hasCollected }.count
                        let totalCount = viewModel.participants.count
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("集金状況")
                                .font(.headline)
                            Text("\(collectedCount)/\(totalCount)人 集金済み")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if collectedCount == totalCount && totalCount > 0 {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // 支払い案内ボタン
                    Button(action: {
                        showPaymentGenerator = true
                    }) {
                        HStack {
                            Image(systemName: "list.bullet.rectangle")
                                .foregroundColor(.white)
                                .font(.headline)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Color.blue))
                                .padding(.trailing, 4)
                            
                            Text("集金案内を作成")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                } header: {
                    HStack {
                        StepHeaderView(
                            step: .collection,
                            isCompleted: completionStatus[.collection] ?? false,
                            isCurrent: false
                        )
                    }
                } footer: {
                    Text("参加者全員の支払い金額をまとめた集金案内を作成できます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 基準金額セクション（合計金額が入力されている場合のみ表示）
            if viewModel.baseAmount > 0 {
                Section {
                    BaseAmountSectionContent()
                } header: {
                    Text("一人当たりの基準金額").font(.headline)
                }
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.defaultMinListRowHeight, 10) // 最小行の高さを小さくして余白を削減
    }
    
    // 内訳セクション
    @ViewBuilder
    private func BreakdownSection() -> some View {
        Section {
            BreakdownSectionContent()
        } footer: {
            if isBreakdownExpanded {
                Text("スワイプで削除できます")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .listRowBackground(Color(.systemGray5)) // 全体の背景よりやや暗いグレー
    }
    
    // 参加者セクション
    @ViewBuilder
    private func ParticipantSection() -> some View {
        Section {
            ParticipantSectionContent()
        } header: {
            HStack {
                Text("参加者一覧").font(.headline)
                Spacer()
                
                if !viewModel.participants.isEmpty {
                    // 全員一括で集金状態を変更するメニュー
                    Menu {
                        Button(action: {
                            // 全員を集金済みにする
                            for participant in viewModel.participants {
                                viewModel.updateCollectionStatus(participant: participant, hasCollected: true)
                            }
                        }) {
                            Label("全員を集金済みにする", systemImage: "checkmark.circle.fill")
                        }
                        
                        Button(action: {
                            // 全員を未集金にする
                            for participant in viewModel.participants {
                                viewModel.updateCollectionStatus(participant: participant, hasCollected: false)
                            }
                        }) {
                            Label("全員を未集金にする", systemImage: "circle")
                        }
                        
                        Divider()
                        
                        Button(action: {
                            showPaymentGenerator = true
                        }) {
                            Label("集金案内を作成", systemImage: "list.bullet.rectangle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .imageScale(.medium)
                            .foregroundColor(.blue)
                    }
                }
            }
        } footer: {
            if !viewModel.participants.isEmpty {
                let collectedCount = viewModel.participants.filter { $0.hasCollected }.count
                let totalCount = viewModel.participants.count
                let progress = Double(collectedCount) / Double(totalCount)
                
                VStack(alignment: .leading, spacing: 8) {
                    // 進捗状況テキスト
                    HStack {
                        Text("集金状況: \(collectedCount)/\(totalCount)")
                            .foregroundColor(collectedCount == totalCount ? .green : .secondary)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .foregroundColor(collectedCount == totalCount ? .green : .secondary)
                    }
                    
                    // 進捗バー
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // 背景
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 6)
                            
                            // 進捗
                            RoundedRectangle(cornerRadius: 4)
                                .fill(progress == 1.0 ? Color.green : Color.blue)
                                .frame(width: max(4, geometry.size.width * progress), height: 6)
                                .animation(.spring(response: 0.3), value: progress)
                        }
                    }
                    .frame(height: 6)
                }
                .font(.caption)
                .padding(.vertical, 8)
            }
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
    
    // サブビュー：日付セクションの内容
    @ViewBuilder
    private func DateSectionContent() -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "calendar")
                .font(.system(size: DesignSystem.Icon.Size.medium))
                .foregroundColor(DesignSystem.Colors.primary)
            
            Spacer()
            
            if let date = localPlanDate {
                DatePicker("日付", selection: Binding(
                    get: { date },
                    set: { localPlanDate = $0 }
                ), displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.black)
            } else {
                Button(action: {
                    localPlanDate = Date()
                }) {
                    Text("日付を選択")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.primary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding(DesignSystem.TextField.Padding.horizontal)
        .frame(height: DesignSystem.TextField.Height.medium)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                .fill(DesignSystem.TextField.backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                .stroke(DesignSystem.TextField.borderColor, lineWidth: DesignSystem.TextField.borderWidth)
        )
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
        viewModel.savePlan(name: localPlanName, date: localPlanDate ?? Date())
    }
    
    // スケジュール調整セクションの内容
    @ViewBuilder
    private func ScheduleSectionContent() -> some View {
        VStack(spacing: 12) {
            if hasScheduleEvent, let event = scheduleEvent {
                // スケジュール調整済みの場合
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("スケジュール調整完了")
                        .font(.headline)
                            .foregroundColor(.green)
                        Spacer()
                }
                
                    Text(event.title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let optimalDate = event.optimalDate {
                HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            Text("決定日時: \(scheduleViewModel.formatDateTime(optimalDate))")
                                .font(.subheadline)
                        }
                    }
                    
                    // 参加者状況の表示
                    let attendingCount = event.responses.filter { $0.status == .attending }.count
                    let totalResponses = event.responses.count
                    HStack {
                        Image(systemName: "person.2")
                            .foregroundColor(.blue)
                        Text("参加者: \(attendingCount)/\(totalResponses)人")
                            .font(.subheadline)
                    }
                    
                    HStack {
                    Button(action: {
                            showingScheduleUrlSheet = true
                    }) {
                            Label("URLを表示", systemImage: "link")
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                    
                    Button(action: {
                            showScheduleEdit = true
                    }) {
                            Label("編集", systemImage: "pencil")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                        .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                // スケジュール調整未完了の場合
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundColor(.blue)
                        Text("スケジュール調整を開始")
                            .font(.headline)
                Spacer()
            }
                    
                    Text("候補日時を設定して参加者に共有できます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        showScheduleCreation = true
                    }) {
                        Label("スケジュール調整を開始", systemImage: "calendar.badge.plus")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
            }
        }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
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

#Preview {
    NavigationStack {
        PrePlanView(viewModel: PrePlanViewModel(), planName: "Sample Plan", planDate: Date())
    }
}

