import SwiftUI
import Combine

// 役職を表す列挙型
enum Role: String, CaseIterable, Identifiable, Codable {
    case director = "部長"
    case manager = "課長"
    case staff = "一般"
    case newbie = "新人"
    
    var id: String { rawValue }
    
    var defaultMultiplier: Double {
        return PrePlanViewModel.shared.getRoleMultiplier(self)
    }
    
    func setMultiplier(_ value: Double) {
        PrePlanViewModel.shared.setRoleMultiplier(self, value: value)
    }
    
    var name: String {
        return PrePlanViewModel.shared.getRoleName(self)
    }
    
    func setName(_ value: String) {
        PrePlanViewModel.shared.setRoleName(self, value: value)
    }
    
    var displayText: String {
        "\(self.name) ×\(String(format: "%.1f", self.defaultMultiplier))"
    }
}

// 役職の種類を表す列挙型
enum RoleType: Identifiable, Codable, Hashable {
    case standard(Role)
    case custom(CustomRole)
    
    var id: UUID {
        switch self {
        case .standard(let role):
            return UUID(uuidString: role.id) ?? UUID()
        case .custom(let role):
            return role.id
        }
    }
    
    var name: String {
        switch self {
        case .standard(let role):
            return role.name
        case .custom(let role):
            return role.name
        }
    }
    
    // Hashableの実装
    func hash(into hasher: inout Hasher) {
        switch self {
        case .standard(let role):
            hasher.combine("standard")
            hasher.combine(role)
        case .custom(let role):
            hasher.combine("custom")
            hasher.combine(role.id)
        }
    }
    
    static func == (lhs: RoleType, rhs: RoleType) -> Bool {
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
struct Participant: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var roleType: RoleType
    
    init(id: UUID = UUID(), name: String, roleType: RoleType) {
        self.id = id
        self.name = name
        self.roleType = roleType
    }
    
    static func == (lhs: Participant, rhs: Participant) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    var effectiveMultiplier: Double {
        switch roleType {
        case .standard(let role):
            return role.defaultMultiplier
        case .custom(let customRole):
            return customRole.multiplier
        }
    }
}

// カスタム役職を表す構造体
struct CustomRole: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var multiplier: Double
    
    init(id: UUID = UUID(), name: String, multiplier: Double) {
        self.id = id
        self.name = name
        self.multiplier = multiplier
    }
    
    var displayText: String {
        "\(name) ×\(String(format: "%.1f", multiplier))"
    }
}

// プランを表す構造体
struct Plan: Identifiable, Codable {
    let id: UUID
    var name: String
    var date: Date
    var participants: [Participant]
    var totalAmount: String
    var roleMultipliers: [String: Double]
    var roleNames: [String: String]
    
    init(id: UUID = UUID(), name: String, date: Date, participants: [Participant], totalAmount: String, roleMultipliers: [String: Double], roleNames: [String: String]) {
        self.id = id
        self.name = name
        self.date = date
        self.participants = participants
        self.totalAmount = totalAmount
        self.roleMultipliers = roleMultipliers
        self.roleNames = roleNames
    }
}

struct PrePlanView: View {
    @ObservedObject var viewModel: PrePlanViewModel
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
    
    // 新規参加者追加用の状態
    @State private var newParticipant: String = ""
    
    // スワイプヒント用の状態
    @State private var showSwipeHint = false
    @State private var swipeHintOffset: CGFloat = 0
    @AppStorage("hasShownEditHint") private var hasShownEditHint: Bool = false
    
    @FocusState private var focusedField: Field?
    
    // 編集用バインディング
    @State private var localPlanName: String = ""
    @State private var localPlanDate: Date? = nil
    @State private var isEditingTitle: Bool = false
    @FocusState private var isTitleFocused: Bool
    
    enum Field {
        case totalAmount, newParticipant, editParticipant
    }
    
    // 共通の入力フィールドスタイル
    private func standardInputField<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(height: 44)
            .padding(.horizontal, 16)
    }
    
    // 参加者セルのビュー
    private func participantCell(_ participant: Participant) -> some View {
        Button(action: { startEdit(participant) }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(participant.name)
                        .font(.body)
                        .foregroundColor(.primary)
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
                
                if viewModel.totalAmount.filter({ $0.isNumber }).isEmpty {
                    Text("¥---")
                        .font(.headline)
                        .foregroundColor(.gray)
                } else {
                    Text("¥\(viewModel.formatAmount(String(viewModel.paymentAmount(for: participant))))")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                confirmDelete(participant: participant)
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }
    
    // 編集シート
    private func editSheet(participant: Participant) -> some View {
        // --- ここからロジックをViewビルダーの外に出す ---
        let tempParticipants = viewModel.participants.map { p in
            if p.id == participant.id {
                return Participant(id: p.id, name: editingText, roleType: editingRoleType)
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
                    // 役職選択用のビュー
                    rolePickerView
                }
                Section {
                    HStack {
                        Text("支払金額")
                        Spacer()
                        Text(paymentAmountText)
                            .foregroundColor(.blue)
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
                            viewModel.updateParticipant(participant, name: editingText, roleType: editingRoleType)
                            editingParticipant = nil
                        }
                        .disabled(editingText.isEmpty)
                    }
                }
            }
            .navigationTitle("参加者を編集")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
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
                VStack(spacing: 0) {
                    VStack(spacing: 16) {  // 縦方向の間隔を統一
                        // 飲み会名の表示・編集切り替え
                        if isEditingTitle {
                            TextField("", text: $localPlanName)
                                .font(.system(size: 32, weight: .bold))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .focused($isTitleFocused)
                                .onSubmit { isEditingTitle = false }
                                .onChange(of: isTitleFocused) { _, focused in
                                    if !focused { isEditingTitle = false }
                                }
                        } else {
                            if localPlanName.isEmpty {
                                Text("飲み会名")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(Color(UIColor.placeholderText))
                                    .italic()
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .onTapGesture {
                                        isEditingTitle = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            isTitleFocused = true
                                        }
                                    }
                            } else {
                                Text(localPlanName)
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .onTapGesture {
                                        isEditingTitle = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            isTitleFocused = true
                                        }
                                    }
                            }
                        }
                        
                        List {
                            // 日付入力セクション
                            Section {
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.blue)
                                    Spacer()
                                    if let date = localPlanDate {
                                        DatePicker("日付", selection: Binding(
                                            get: { date },
                                            set: { localPlanDate = $0 }
                                        ), displayedComponents: .date)
                                        .labelsHidden()
                                        .datePickerStyle(.compact)
                                    } else {
                                        Button(action: {
                                            localPlanDate = Date()
                                        }) {
                                            Text("日付を選択")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                .frame(height: 44)
                            } header: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("開催日")
                                        .font(.headline)
                                    Text("タップして開催日を選択してください")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // 合計金額セクション
                            Section {
                                HStack {
                                    Text("¥")
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                    TextField("", text: $viewModel.totalAmount)
                                        .font(.title2)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .focused($focusedField, equals: .totalAmount)
                                        .onChange(of: viewModel.totalAmount) { _, newValue in
                                            let formatted = viewModel.formatAmount(newValue)
                                            if formatted != newValue {
                                                viewModel.totalAmount = formatted
                                            }
                                        }
                                }
                                .frame(height: 44)
                            } header: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("合計金額")
                                        .font(.headline)
                                    Text("後から入力しても構いません")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // 参加者一覧セクション
                            Section {
                                // 新規参加者追加フォーム
                                HStack {
                                    TextField("参加者名を入力", text: $newParticipant)
                                        .focused($focusedField, equals: .newParticipant)
                                        .submitLabel(.done)
                                        .onSubmit {
                                            if !newParticipant.isEmpty {
                                                viewModel.addParticipant(name: newParticipant, roleType: viewModel.selectedRoleType)
                                                newParticipant = ""
                                                focusedField = nil
                                            }
                                        }
                                        .frame(height: 44)
                                    
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
                                    .buttonStyle(.bordered)
                                    
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
                            } header: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("参加者一覧")
                                        .font(.headline)
                                    Text("タップで編集・スワイプで削除")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            } footer: {
                                if !viewModel.participants.isEmpty {
                                    Text("参加者数: \(viewModel.participants.count)人")
                                }
                            }
                            
                            // 基準金額セクション（合計金額が入力されている場合のみ表示）
                            if viewModel.baseAmount > 0 {
                                Section {
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
                                } header: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("一人当たりの基準金額")
                                            .font(.headline)
                                        Text("役職の倍率を考慮する前の金額です")
                                            .font(.footnote)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                    .padding(.horizontal)
                    .padding(.top, 24)
                    .padding(.bottom, 8)
                    // 保存ボタン
                    Button {
                        viewModel.editingPlanName = localPlanName
                        viewModel.savePlan(name: localPlanName, date: localPlanDate ?? Date())
                        onFinish?()
                    } label: {
                        Label("飲み会を保存してトップに戻る", systemImage: "folder")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: RoleSettingsView(viewModel: viewModel, selectedRole: .constant(nil))) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(item: $editingParticipant) { participant in
                editSheet(participant: participant)
            }
            .onAppear {
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
            }
            .onChange(of: viewModel.participants.count) { _, newCount in
                if newCount > 0 && !hasShownEditHint {
                    DispatchQueue.main.async {
                        showSwipeHintAnimation()
                    }
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

