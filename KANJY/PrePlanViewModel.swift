import SwiftUI
import Combine

class PrePlanViewModel: ObservableObject {
    static let shared = PrePlanViewModel()
    
    @Published var participants: [Participant] = []
    @Published var customRoles: [CustomRole] = []
    @Published var newParticipantName = ""
    @Published var selectedRoleType: RoleType = .standard(.staff)
    @Published var savedPlans: [Plan] = []
    @AppStorage("participants") private var participantsData: Data = Data()
    @AppStorage("customRoles") private var customRolesData: Data = Data()
    @AppStorage("totalAmount") private var savedTotalAmount: String = ""
    @AppStorage("roleMultipliers") private var roleMultipliersData: Data = Data()
    @AppStorage("roleNames") private var roleNamesData: Data = Data()
    @AppStorage("savedPlans") private var savedPlansData: Data = Data()
    
    private var roleMultipliers: [String: Double] = [:]
    private var roleNames: [String: String] = [:]
    
    // 合計金額
    @Published var totalAmount: String = "" {
        didSet {
            savedTotalAmount = totalAmount
        }
    }
    
    // 編集用の状態
    @Published var editingPlanId: UUID? = nil
    @Published var editingPlanName: String = ""
    @Published var editingPlanDate: Date? = nil
    
    init() {
        loadData()
        // UserDefaultsの変更を監視
        NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange), name: UserDefaults.didChangeNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func userDefaultsDidChange() {
        // 倍率が変更された可能性があるため、画面を更新
        objectWillChange.send()
    }
    
    // データの読み込み
    func loadData() {
        if let decoded = try? JSONDecoder().decode([Participant].self, from: participantsData) {
            participants = decoded
        }
        if let decodedRoles = try? JSONDecoder().decode([CustomRole].self, from: customRolesData) {
            customRoles = decodedRoles
        }
        if let decodedMultipliers = try? JSONDecoder().decode([String: Double].self, from: roleMultipliersData) {
            roleMultipliers = decodedMultipliers
        }
        if let decodedNames = try? JSONDecoder().decode([String: String].self, from: roleNamesData) {
            roleNames = decodedNames
        }
        if let decodedPlans = try? JSONDecoder().decode([Plan].self, from: savedPlansData) {
            savedPlans = decodedPlans
        }
        totalAmount = savedTotalAmount
    }
    
    // データの保存
    private func saveData() {
        // 途中保存も許可するため、空でも保存
        if let encoded = try? JSONEncoder().encode(participants) {
            participantsData = encoded
        }
        // 合計金額が空でも保存
        savedTotalAmount = totalAmount
        if let encodedRoles = try? JSONEncoder().encode(customRoles) {
            customRolesData = encodedRoles
        }
        if let encodedMultipliers = try? JSONEncoder().encode(roleMultipliers) {
            roleMultipliersData = encodedMultipliers
        }
        if let encodedNames = try? JSONEncoder().encode(roleNames) {
            roleNamesData = encodedNames
        }
        if let encodedPlans = try? JSONEncoder().encode(savedPlans) {
            savedPlansData = encodedPlans
        }
    }
    
    // 参加者の追加
    func addParticipant(name: String, roleType: RoleType) {
        let participant = Participant(name: name, roleType: roleType)
        participants.append(participant)
        saveData()
    }
    
    // 参加者の更新
    func updateParticipant(_ participant: Participant, name: String, roleType: RoleType) {
        if let index = participants.firstIndex(where: { $0.id == participant.id }) {
            participants[index] = Participant(id: participant.id, name: name, roleType: roleType)
            saveData()
        }
    }
    
    // 参加者の削除
    func deleteParticipant(id: UUID) {
        participants.removeAll(where: { $0.id == id })
        saveData()
    }
    
    // カスタム役職の追加
    func addCustomRole(name: String, multiplier: Double) {
        let role = CustomRole(name: name, multiplier: multiplier)
        customRoles.append(role)
        saveData()
    }
    
    // カスタム役職の削除
    func deleteCustomRole(id: UUID) {
        customRoles.removeAll(where: { $0.id == id })
        saveData()
    }
    
    // 一人当たりの基準金額を計算（倍率1.0の場合の金額）
    var baseAmount: Double {
        let amountString = totalAmount.filter { $0.isNumber }
        guard let total = Double(amountString),
              !participants.isEmpty else {
            return 0
        }
        let totalMultiplier = participants.reduce(into: 0.0) { sum, participant in
            sum += participant.effectiveMultiplier
        }
        return total / totalMultiplier
    }
    
    // 参加者ごとの支払金額を計算
    func paymentAmount(for participant: Participant) -> Int {
        Int(round(baseAmount * participant.effectiveMultiplier))
    }
    
    // 金額をカンマ区切りにフォーマットする
    func formatAmount(_ input: String) -> String {
        let numbers = input.filter { $0.isNumber }
        if numbers.isEmpty { return "" }
        guard let amount = Int(numbers) else { return input }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        
        return formatter.string(from: NSNumber(value: amount)) ?? input
    }
    
    // 日付をフォーマットする
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    // 役職の倍率を取得
    func getRoleMultiplier(_ role: Role) -> Double {
        if let multiplier = roleMultipliers[role.rawValue] {
            return multiplier
        }
        // デフォルト値を返す
        switch role {
        case .director: return 2.0
        case .manager: return 1.5
        case .staff: return 1.0
        case .newbie: return 0.5
        }
    }
    
    // 役職の倍率を設定
    func setRoleMultiplier(_ role: Role, value: Double) {
        roleMultipliers[role.rawValue] = value
        saveData()
        objectWillChange.send()
    }
    
    // 役職の名前を取得
    func getRoleName(_ role: Role) -> String {
        if let name = roleNames[role.rawValue] {
            return name
        }
        return role.rawValue
    }
    
    // 役職の名前を設定
    func setRoleName(_ role: Role, value: String) {
        roleNames[role.rawValue] = value
        saveData()
        objectWillChange.send()
    }
    
    // デバッグ情報用のプロパティ
    var debugInfo: [String: Any] {
        [
            "savedPlansCount": savedPlans.count,
            "participantsCount": participants.count,
            "totalAmount": totalAmount,
            "roleMultipliersCount": roleMultipliers.count,
            "roleNamesCount": roleNames.count
        ]
    }
    
    // プランの保存
    func savePlan(name: String, date: Date) {
        if let id = editingPlanId, let idx = savedPlans.firstIndex(where: { $0.id == id }) {
            // 既存プランを上書き
            savedPlans[idx] = Plan(id: id, name: name, date: date, participants: participants, totalAmount: totalAmount, roleMultipliers: roleMultipliers, roleNames: roleNames)
        } else {
            // 新規プランとして追加
            let plan = Plan(name: name, date: date, participants: participants, totalAmount: totalAmount, roleMultipliers: roleMultipliers, roleNames: roleNames)
            savedPlans.append(plan)
            editingPlanId = plan.id
        }
        editingPlanName = name
        editingPlanDate = date
        saveData()
    }
    
    // プランの読み込み
    func loadPlan(_ plan: Plan) {
        participants = plan.participants
        totalAmount = plan.totalAmount
        roleMultipliers = plan.roleMultipliers
        roleNames = plan.roleNames
        editingPlanId = plan.id
        editingPlanName = plan.name
        editingPlanDate = plan.date
        saveData()
    }
    
    // プランの削除
    func deletePlan(id: UUID) {
        savedPlans.removeAll { $0.id == id }
        saveData()
    }
    
    // フォームのリセット
    func resetForm() {
        participants = []
        roleMultipliers = [:]
        roleNames = [:]
        totalAmount = ""
        editingPlanId = nil
        editingPlanName = ""
        editingPlanDate = nil
        saveData()
    }
} 