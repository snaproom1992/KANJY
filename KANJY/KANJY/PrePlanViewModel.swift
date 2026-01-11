import SwiftUI
import Combine

// 金額内訳項目を表す構造体
public struct AmountItem: Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String
    public var amount: Int
    
    public init(id: UUID = UUID(), name: String, amount: Int) {
        self.id = id
        self.name = name
        self.amount = amount
    }
}

// 飲み会を表す構造体（中心オブジェクト）
public struct Plan: Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String
    public var date: Date
    public var participants: [Participant]
    public var totalAmount: String
    public var roleMultipliers: [String: Double]
    public var roleNames: [String: String]
    public var amountItems: [AmountItem]?
    public var emoji: String?
    public var icon: String? // SF Symbolsのアイコン名
    public var iconColor: String? // アイコンの色（RGB値の文字列、例: "0.067,0.094,0.157"）
    // 基本情報
    public var description: String? // 説明
    public var location: String? // 場所
    // スケジュール調整との関係（オプショナル）
    public var scheduleEventId: UUID?
    // 開催確定情報
    public var confirmedDate: Date?
    public var confirmedLocation: String?
    public var confirmedParticipants: [UUID]? // 確定参加者のIDリスト
    
    public init(id: UUID = UUID(), name: String, date: Date, participants: [Participant], totalAmount: String, roleMultipliers: [String: Double], roleNames: [String: String], amountItems: [AmountItem]? = nil, emoji: String? = nil, icon: String? = nil, iconColor: String? = nil, description: String? = nil, location: String? = nil, scheduleEventId: UUID? = nil, confirmedDate: Date? = nil, confirmedLocation: String? = nil, confirmedParticipants: [UUID]? = nil) {
        self.id = id
        self.name = name
        self.date = date
        self.participants = participants
        self.totalAmount = totalAmount
        self.roleMultipliers = roleMultipliers
        self.roleNames = roleNames
        self.amountItems = amountItems
        self.emoji = emoji
        self.icon = icon
        self.iconColor = iconColor
        self.description = description
        self.location = location
        self.scheduleEventId = scheduleEventId
        self.confirmedDate = confirmedDate
        self.confirmedLocation = confirmedLocation
        self.confirmedParticipants = confirmedParticipants
    }
}

public class PrePlanViewModel: ObservableObject {
    public static let shared = PrePlanViewModel()
    
    @Published public var participants: [Participant] = []
    @Published public var customRoles: [CustomRole] = []
    @Published public var newParticipantName = ""
    @Published public var selectedRoleType: RoleType = .standard(.staff)
    @Published public var savedPlans: [Plan] = []
    @Published public var amountItems: [AmountItem] = []
    @Published public var selectedEmoji: String = "🍻" {
        didSet {
            savedEmoji = selectedEmoji
            print("絵文字を保存: \(selectedEmoji)")
        }
    }
    @Published public var selectedIcon: String? = nil {
        didSet {
            savedIcon = selectedIcon ?? ""
            print("アイコンを保存: \(selectedIcon ?? "nil")")
        }
    }
    
    @Published public var selectedIconColor: String? = nil {
        didSet {
            savedIconColor = selectedIconColor ?? ""
            print("アイコン色を保存: \(selectedIconColor ?? "nil")")
        }
    }
    
    @AppStorage("participants") private var participantsData: Data = Data()
    @AppStorage("customRoles") private var customRolesData: Data = Data()
    @AppStorage("totalAmount") private var savedTotalAmount: String = ""
    @AppStorage("roleMultipliers") private var roleMultipliersData: Data = Data()
    @AppStorage("roleNames") private var roleNamesData: Data = Data()
    @AppStorage("savedPlans") private var savedPlansData: Data = Data()
    @AppStorage("amountItems") private var amountItemsData: Data = Data()
    @AppStorage("selectedEmoji") private var savedEmoji: String = "🍻"
    @AppStorage("selectedIcon") private var savedIcon: String = ""
    @AppStorage("selectedIconColor") private var savedIconColor: String = ""
    
    private var roleMultipliers: [String: Double] = [:]
    private var roleNames: [String: String] = [:]
    
    // 外部からアクセス可能なプロパティ
    public var currentRoleMultipliers: [String: Double] {
        return roleMultipliers
    }
    
    public var currentRoleNames: [String: String] {
        return roleNames
    }
    
    // 合計金額
    @Published public var totalAmount: String = "" {
        didSet {
            savedTotalAmount = totalAmount
        }
    }
    
    // 編集用の状態
    @Published public var editingPlanId: UUID? = nil
    @Published public var editingPlanName: String = ""
    @Published public var editingPlanDate: Date? = nil
    @Published public var editingPlanEmoji: String = ""
    @Published public var editingPlanDescription: String = ""
    @Published public var editingPlanLocation: String = ""
    
    // 飲み会関連の絵文字リスト
    public let partyEmojis = ["🍻", "🍺", "🥂", "🍷", "🍸", "🍹", "🍾", "🥃", 
                       "🍴", "🍖", "🍗", "🍣", "🍕", "🍔", "🥩", "🍙",
                       "🎉", "🎊", "✨", "🌟", "🎵", "🎤", "🎯", "🎮",
                       "👥", "👨‍👩‍👧‍👦", "🏢", "🌆", "🌃", "🍱", "🥟", "🍜"]
    
    public init() {
        loadData()
        // UserDefaultsの変更を監視
        NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange), name: UserDefaults.didChangeNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func userDefaultsDidChange() {
        // 倍率が変更された可能性があるため、画面を更新
        // SwiftUIの警告を回避するためメインスレッドの次の更新サイクルで実行
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // データの読み込み
    public func loadData() {
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
        if let decodedItems = try? JSONDecoder().decode([AmountItem].self, from: amountItemsData) {
            amountItems = decodedItems
        }
        totalAmount = savedTotalAmount
        selectedEmoji = savedEmoji.isEmpty ? "🍻" : savedEmoji
        selectedIcon = savedIcon.isEmpty ? nil : savedIcon
        selectedIconColor = savedIconColor.isEmpty ? nil : savedIconColor
        print("絵文字を読み込み: \(selectedEmoji)")
        print("アイコンを読み込み: \(selectedIcon ?? "nil")")
        print("アイコン色を読み込み: \(selectedIconColor ?? "nil")")
    }
    
    // データの保存
    public func saveData() {
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
        if let encodedItems = try? JSONEncoder().encode(amountItems) {
            amountItemsData = encodedItems
        }
    }
    
    // 内訳項目の追加
    public func addAmountItem(name: String, amount: Int) {
        let item = AmountItem(name: name, amount: amount)
        amountItems.append(item)
        
        // 現在の合計金額に追加
        addToTotalAmount(amount)
        
        saveData()
    }
    
    // 内訳項目の削除
    public func removeAmountItems(at offsets: IndexSet) {
        // 削除される項目の金額合計を計算
        let amountToSubtract = offsets.reduce(0) { sum, index in
            sum + amountItems[index].amount
        }
        
        // 項目を削除
        amountItems.remove(atOffsets: offsets)
        
        // 合計金額から削除した金額を引く
        subtractFromTotalAmount(amountToSubtract)
        
        saveData()
    }
    
    // 内訳項目の更新
    public func updateAmountItem(id: UUID, name: String, amount: Int) {
        if let index = amountItems.firstIndex(where: { $0.id == id }) {
            let oldAmount = amountItems[index].amount
            let amountDifference = amount - oldAmount
            
            // 項目を更新
            amountItems[index] = AmountItem(id: id, name: name, amount: amount)
            
            // 合計金額を調整（増減分を反映）
            if amountDifference > 0 {
                addToTotalAmount(amountDifference)
            } else if amountDifference < 0 {
                subtractFromTotalAmount(abs(amountDifference))
            }
            
            saveData()
        }
    }
    
    // 合計金額に追加
    private func addToTotalAmount(_ amount: Int) {
        let currentAmountString = totalAmount.filter { $0.isNumber }
        var currentAmount = Int(currentAmountString) ?? 0
        
        // 金額を追加
        currentAmount += amount
        
        // フォーマットして保存
        totalAmount = formatAmount(String(currentAmount))
    }
    
    // 合計金額から引く
    private func subtractFromTotalAmount(_ amount: Int) {
        let currentAmountString = totalAmount.filter { $0.isNumber }
        var currentAmount = Int(currentAmountString) ?? 0
        
        // 金額を引く（負にならないように）
        currentAmount = max(0, currentAmount - amount)
        
        // フォーマットして保存
        totalAmount = formatAmount(String(currentAmount))
    }
    
    // 合計金額の更新（既存のメソッドは使用しない）
    private func updateTotalAmount() {
        // このメソッドは使用しなくなりましたが、後方互換性のために残しておきます
        let total = amountItems.reduce(0) { $0 + $1.amount }
        totalAmount = formatAmount(String(total))
    }
    
    // 参加者の追加
    func addParticipant(name: String, roleType: RoleType) {
        let participant = Participant(name: name, roleType: roleType, hasCollected: false, hasFixedAmount: false, fixedAmount: 0)
        participants.append(participant)
        saveData()
    }
    
    // 参加者の更新
    func updateParticipant(_ participant: Participant, name: String, roleType: RoleType, hasCollected: Bool = false, hasFixedAmount: Bool = false, fixedAmount: Int = 0) {
        if let index = participants.firstIndex(where: { $0.id == participant.id }) {
            participants[index] = Participant(
                id: participant.id,
                name: name,
                roleType: roleType,
                hasCollected: hasCollected,
                hasFixedAmount: hasFixedAmount,
                fixedAmount: fixedAmount,
                source: participant.source
            )
            saveData()
        }
    }
    
    // スケジュール回答から参加者を同期
    func syncParticipants(from responses: [ScheduleResponse], date: Date?) {
        // 同じ日の回答で、参加(attending)の人を抽出
        // dateがnilの場合は、全員（あるいはとりあえず回答がある人全て）を対象にするか、
        // コアワークフローに従い「集金対象者リスト」としては、dateがnilなら「全回答者」を表示するのが適切
        
        let targetResponses: [ScheduleResponse]
        
        if let targetDate = date {
            // 日程が決まっている場合：その日に参加(attending)の人
            targetResponses = responses.filter { response in
                response.status == .attending && response.availableDates.contains { responseDate in
                    Calendar.current.isDate(responseDate, inSameDayAs: targetDate)
                }
            }
        } else {
            // 日程未定の場合：回答者全員（削除済みを除く）
            targetResponses = responses
        }
        
        let newParticipants = targetResponses.map { response in
            Participant(
                name: response.participantName,
                roleType: .standard(.staff), 
                source: .webResponse
            )
        }
        
        // 重複除去（同名の人がいれば統合などしたいが、一旦単純に置換）
        // ID管理が厳密でないため、名前ベースでユニークにするなどの処理があっても良いが、
        // ここではシンプルにリストを更新する
        participants = newParticipants
        saveData()
    }
    
    // 参加者を削除
    func deleteParticipant(_ participant: Participant) {
        if let index = participants.firstIndex(where: { $0.id == participant.id }) {
            participants.remove(at: index)
            saveData()
        }
    }
    
    // 集金状態の切り替え
    func toggleCollectionStatus(for participant: Participant) {
        if let index = participants.firstIndex(where: { $0.id == participant.id }) {
            var updatedParticipant = participants[index]
            updatedParticipant.hasCollected.toggle()
            participants[index] = updatedParticipant
            saveData()
        }
    }
    
    // 参加者の集金状態を更新
    func updateCollectionStatus(participant: Participant, hasCollected: Bool) {
        if let index = participants.firstIndex(where: { $0.id == participant.id }) {
            var updatedParticipant = participants[index]
            updatedParticipant.hasCollected = hasCollected
            participants[index] = updatedParticipant
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
              total > 0,
              !participants.isEmpty else {
            return 0
        }
        
        // 固定金額を持つ参加者の合計金額を計算
        let fixedTotal = participants.filter { $0.hasFixedAmount }
            .reduce(0) { sum, participant in
                sum + Double(participant.fixedAmount)
            }
        
        // 残りの金額を計算
        let remainingTotal = max(0, total - fixedTotal)
        
        // 固定金額を持たない参加者の倍率合計を計算
        let nonFixedParticipants = participants.filter { !$0.hasFixedAmount }
        
        // 固定金額を持たない参加者がいない場合は0を返す
        if nonFixedParticipants.isEmpty {
            return 0
        }
        
        let totalMultiplier = nonFixedParticipants
            .reduce(into: 0.0) { sum, participant in
                sum += participant.effectiveMultiplier
            }
        
        // 倍率合計が0の場合は0を返す
        guard totalMultiplier > 0 else { return 0 }
        
        return remainingTotal / totalMultiplier
    }
    
    // 参加者ごとの支払金額を計算
    func paymentAmount(for participant: Participant) -> Int {
        // 金額が固定されている場合はその金額を返す
        if participant.hasFixedAmount {
            return participant.fixedAmount
        }
        
        // 基準金額が0以下の場合は0を返す
        guard baseAmount > 0 else { return 0 }
        
        // 通常の計算
        return Int(round(baseAmount * participant.effectiveMultiplier))
    }
    
    // 金額をカンマ区切りにフォーマットする
    func formatAmount(_ input: String) -> String {
        let numbers = input.filter { $0.isNumber }
        if numbers.isEmpty { return "0" }  // 空の場合は"0"を返す
        guard let amount = Int(numbers) else { return input }
        
        // 0の場合はそのまま"0"を返す
        if amount == 0 { return "0" }
        
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
        formatter.locale = Locale(identifier: "ja_JP")
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
    
    // ランダムな絵文字を取得
    public func getRandomEmoji() -> String {
        let emojis = ["🍻", "🍺", "🥂", "🍷", "🍸", "🍹", "🍾", "🥃", 
                      "🍴", "🍖", "🍗", "🍣", "🍕", "🍔", "🥩", "🍙"]
        return emojis.randomElement() ?? "🍻"
    }
    
    // プランの保存
    public func savePlan(name: String, date: Date, description: String? = nil, location: String? = nil, confirmedDate: Date? = nil, confirmedLocation: String? = nil, confirmedParticipants: [UUID]? = nil) {
        let emoji = selectedIcon == nil ? (selectedEmoji.isEmpty ? getRandomEmoji() : selectedEmoji) : nil
        let icon = selectedIcon
        let iconColor = selectedIconColor
        
        if let id = editingPlanId, let idx = savedPlans.firstIndex(where: { $0.id == id }) {
            // 既存プランを上書き（既存の確定情報を保持、新しい値があれば更新）
            let existingScheduleEventId = savedPlans[idx].scheduleEventId
            let existingConfirmedDate = confirmedDate ?? savedPlans[idx].confirmedDate
            let existingConfirmedLocation = confirmedLocation ?? savedPlans[idx].confirmedLocation
            let existingConfirmedParticipants = confirmedParticipants ?? savedPlans[idx].confirmedParticipants
            savedPlans[idx] = Plan(
                id: id,
                name: name,
                date: date,
                participants: participants,
                totalAmount: totalAmount,
                roleMultipliers: roleMultipliers,
                roleNames: roleNames,
                amountItems: amountItems,
                emoji: emoji,
                icon: icon,
                iconColor: iconColor,
                description: description ?? savedPlans[idx].description,
                location: location ?? savedPlans[idx].location,
                scheduleEventId: existingScheduleEventId,
                confirmedDate: existingConfirmedDate,
                confirmedLocation: existingConfirmedLocation,
                confirmedParticipants: existingConfirmedParticipants
            )
        } else {
            // 新規プランとして追加
            let plan = Plan(
                name: name,
                date: date,
                participants: participants,
                totalAmount: totalAmount,
                roleMultipliers: roleMultipliers,
                roleNames: roleNames,
                amountItems: amountItems,
                emoji: emoji,
                icon: icon,
                iconColor: iconColor,
                description: description,
                location: location,
                scheduleEventId: nil,
                confirmedDate: confirmedDate,
                confirmedLocation: confirmedLocation,
                confirmedParticipants: confirmedParticipants
            )
            savedPlans.append(plan)
            editingPlanId = plan.id
        }
        editingPlanName = name
        editingPlanDate = date
        editingPlanEmoji = emoji ?? ""
        if let description = description {
            editingPlanDescription = description
        }
        if let location = location {
            editingPlanLocation = location
        }
        saveData()
    }
    
    // 確定情報を保存
    public func saveConfirmedInfo(confirmedDate: Date?, confirmedLocation: String?, confirmedParticipants: [UUID]?) {
        guard let id = editingPlanId, let idx = savedPlans.firstIndex(where: { $0.id == id }) else { return }
        
        savedPlans[idx].confirmedDate = confirmedDate
        savedPlans[idx].confirmedLocation = confirmedLocation
        savedPlans[idx].confirmedParticipants = confirmedParticipants
        saveData()
    }
    
    // プランの読み込み
    public func loadPlan(_ plan: Plan) {
        participants = plan.participants
        totalAmount = plan.totalAmount
        roleMultipliers = plan.roleMultipliers
        roleNames = plan.roleNames
        editingPlanId = plan.id
        editingPlanName = plan.name
        editingPlanDate = plan.date
        editingPlanDescription = plan.description ?? ""
        editingPlanLocation = plan.location ?? ""
        
        // アイコンと絵文字の読み込みを改良
        if let icon = plan.icon, !icon.isEmpty {
            selectedIcon = icon
            selectedIconColor = plan.iconColor
            selectedEmoji = ""
            print("プランからアイコンを読み込み: \(icon), 色: \(plan.iconColor ?? "nil")")
        } else if let emoji = plan.emoji, !emoji.isEmpty {
            selectedEmoji = emoji
            selectedIcon = nil
            selectedIconColor = nil
            print("プランから絵文字を読み込み: \(emoji)")
        } else {
            selectedEmoji = "🍻"
            selectedIcon = nil
            selectedIconColor = nil
            print("プランに絵文字がないため、デフォルト絵文字を設定: 🍻")
        }
        editingPlanEmoji = selectedEmoji
        
        // プランに内訳項目がある場合は読み込む
        if let items = plan.amountItems {
            amountItems = items
        } else {
            amountItems = []
        }
        
        saveData()
    }
    
    // プランの削除
    public func deletePlan(id: UUID) {
        savedPlans.removeAll { $0.id == id }
        saveData()
    }

    public func quickCreatePlan(name: String, date: Date, emoji: String? = nil) {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else { return }

        let plan = Plan(
            name: normalizedName,
            date: date,
            participants: [],
            totalAmount: "",
            roleMultipliers: [:],
            roleNames: [:],
            amountItems: nil,
            emoji: emoji ?? selectedEmoji,
            icon: selectedIcon,
            iconColor: selectedIconColor,
            scheduleEventId: nil
        )

        savedPlans.append(plan)
        savedPlans.sort(by: { $0.date > $1.date })
        saveData()
    }

    // フォームのリセット
    public func resetForm() {
        participants = []
        roleMultipliers = [:]
        roleNames = [:]
        totalAmount = ""
        amountItems = []
        editingPlanId = nil
        editingPlanName = ""
        editingPlanDate = nil
        selectedIcon = nil
        selectedEmoji = ""
        editingPlanEmoji = ""
        saveData()
    }
    
    // MARK: - Web回答同期機能
    
    /// スケジュール調整の回答から参加者を自動追加
    /// - Parameters:
    ///   - responses: スケジュール調整の回答リスト
    ///   - replaceExisting: 既存の参加者を置き換えるか（デフォルト: false）
    /// - Returns: 追加された参加者の数
    @discardableResult
    public func syncParticipantsFromWebResponses(_ responses: [ScheduleResponse], replaceExisting: Bool = false) -> Int {
        // 重複を除いた回答者名のリストを取得
        let uniqueNames = Set(responses.map { $0.participantName })
        
        var addedCount = 0
        
        for name in uniqueNames {
            // 既に参加者リストにいるかチェック
            let exists = participants.contains(where: { $0.name == name })
            
            if !exists {
                // Web回答から自動追加
                let participant = Participant(
                    id: UUID(),
                    name: name,
                    roleType: .standard(.staff), // デフォルト役職
                    hasCollected: false,
                    hasFixedAmount: false,
                    fixedAmount: 0,
                    source: .webResponse // Web回答から追加されたことを記録
                )
                
                participants.append(participant)
                addedCount += 1
            }
        }
        
        if addedCount > 0 {
            saveData()
        }
        
        return addedCount
    }
    
    /// Web回答から追加された参加者の数を取得
    public var webResponseParticipantsCount: Int {
        participants.filter { $0.source == .webResponse }.count
    }
    
    /// 手動追加された参加者の数を取得
    public var manualParticipantsCount: Int {
        participants.filter { $0.source == .manual }.count
    }
} 
