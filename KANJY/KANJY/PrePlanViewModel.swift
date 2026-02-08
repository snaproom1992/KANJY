import SwiftUI
import Combine

// Plan and AmountItem moved to their own files


public class PrePlanViewModel: ObservableObject {
    public static let shared = PrePlanViewModel()
    
    @Published public var participants: [Participant] = []
    @Published public var customRoles: [CustomRole] = []
    @Published public var newParticipantName = ""
    @Published public var selectedRoleType: RoleType = .standard(.staff)
    @Published public var savedPlans: [Plan] = []
    @Published public var amountItems: [AmountItem] = []
    @Published public var selectedEmoji: String = "" {
        didSet {
            PlanRepository.shared.saveSelectedEmoji(selectedEmoji)
            print("絵文字を保存: \(selectedEmoji)")
        }
    }
    @Published public var selectedIcon: String? = nil {
        didSet {
            PlanRepository.shared.saveSelectedIcon(selectedIcon ?? "")
            print("アイコンを保存: \(selectedIcon ?? "nil")")
        }
    }
    
    @Published public var selectedIconColor: String? = nil {
        didSet {
            PlanRepository.shared.saveSelectedIconColor(selectedIconColor ?? "")
            print("アイコン色を保存: \(selectedIconColor ?? "nil")")
        }
    }
    
    // @AppStorage properties replaced with PlanRepository

    
    // PlanRepository instances
    private let repository = PlanRepository.shared
    
    private var roleMultipliers: [String: Double] = [:]
    private var roleNames: [String: String] = [:]
    
    // 外部からアクセス可能なプロパティ
    public var currentRoleMultipliers: [String: Double] {
        return roleMultipliers
    }
    
    public var currentRoleNames: [String: String] {
        return roleNames
    }
    
    // MARK: - 合計金額（全カードの合計から算出）
    
    /// 全カードの合計金額（computed）
    public var totalAmount: String {
        get {
            let total = amountItems.reduce(0) { $0 + $1.amount }
            return total > 0 ? formatAmount(String(total)) : ""
        }
        set {
            // 後方互換性のためsetterを残す（マイグレーション時に使用）
            // amountItemsが空の場合のみ、メインカードを作成
            // 通常はamountItemsの操作を通じて合計が変わる
        }
    }
    
    /// 合計金額の数値（Int）
    public var totalAmountValue: Int {
        return amountItems.reduce(0) { $0 + $1.amount }
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
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // データの読み込み
    public func loadData() {
        participants = repository.loadParticipants()
        customRoles = repository.loadCustomRoles()
        roleMultipliers = repository.loadRoleMultipliers()
        roleNames = repository.loadRoleNames()
        savedPlans = repository.loadSavedPlans()
        amountItems = repository.loadAmountItems()
        selectedEmoji = repository.loadSelectedEmoji()
        selectedIcon = repository.loadSelectedIcon()
        selectedIconColor = repository.loadSelectedIconColor()
        
        // マイグレーション: 旧データ形式からの移行
        migrateFromLegacyTotalAmount()
        
        print("絵文字を読み込み: \(selectedEmoji)")
        print("アイコンを読み込み: \(selectedIcon ?? "nil")")
        print("アイコン色を読み込み: \(selectedIconColor ?? "nil")")
    }
    
    // データの保存
    public func saveData() {
        repository.saveParticipants(participants)
        repository.saveTotalAmount(totalAmount) // 後方互換用に引き続き保存
        repository.saveCustomRoles(customRoles)
        repository.saveRoleMultipliers(roleMultipliers)
        repository.saveRoleNames(roleNames)
        repository.saveSavedPlans(savedPlans)
        repository.saveAmountItems(amountItems)
    }
    
    // MARK: - マイグレーション（旧totalAmountからの移行）
    
    private func migrateFromLegacyTotalAmount() {
        let legacyTotalAmount = repository.loadTotalAmount()
        let legacyAmountString = legacyTotalAmount.filter { $0.isNumber }
        let legacyTotal = Int(legacyAmountString) ?? 0
        
        // 旧totalAmountがあり、amountItemsが空の場合 → メインカードを作成
        if legacyTotal > 0 && amountItems.isEmpty {
            let mainItem = AmountItem(
                name: "メインのお会計",
                amount: legacyTotal,
                participantIds: nil,
                useMultiplier: true
            )
            amountItems = [mainItem]
            saveData()
            return
        }
        
        // 旧totalAmountがあり、amountItemsも存在する場合
        // → 旧amountItemsは「追加分」として totalAmount に加算されていた
        // → 差分をメインカードとして生成
        if legacyTotal > 0 && !amountItems.isEmpty {
            // 既にparticipantIdsフィールドがある（マイグレーション済み）場合はスキップ
            // 旧形式のAmountItemにはparticipantIdsがないが、デコーダでnilになるので
            // メインカードが存在するかチェック
            let hasMainCard = amountItems.contains { $0.name == "メインのお会計" }
            if !hasMainCard {
                let existingItemsTotal = amountItems.reduce(0) { $0 + $1.amount }
                let mainAmount = max(0, legacyTotal - existingItemsTotal)
                if mainAmount > 0 {
                    let mainItem = AmountItem(
                        name: "メインのお会計",
                        amount: mainAmount,
                        participantIds: nil,
                        useMultiplier: true
                    )
                    amountItems.insert(mainItem, at: 0)
                    saveData()
                }
            }
        }
    }
    
    // MARK: - お会計カードの管理
    
    /// お会計カードを追加
    public func addAmountItem(name: String, amount: Int, participantIds: [UUID]? = nil, useMultiplier: Bool = true) {
        let item = AmountItem(name: name, amount: amount, participantIds: participantIds, useMultiplier: useMultiplier)
        amountItems.append(item)
        saveData()
    }
    
    /// お会計カードを削除
    public func removeAmountItem(at index: Int) {
        guard amountItems.indices.contains(index) else { return }
        amountItems.remove(at: index)
        saveData()
    }
    
    /// お会計カードを削除（IndexSet版）
    public func removeAmountItems(at offsets: IndexSet) {
        amountItems.remove(atOffsets: offsets)
        saveData()
    }
    
    /// お会計カードを削除（ID指定）
    public func removeAmountItem(id: UUID) {
        amountItems.removeAll { $0.id == id }
        saveData()
    }
    
    /// お会計カードを更新
    public func updateAmountItem(id: UUID, name: String, amount: Int, participantIds: [UUID]? = nil, useMultiplier: Bool = true) {
        if let index = amountItems.firstIndex(where: { $0.id == id }) {
            amountItems[index] = AmountItem(id: id, name: name, amount: amount, participantIds: participantIds, useMultiplier: useMultiplier)
            saveData()
        }
    }
    
    /// お会計カードの金額のみを更新
    public func updateAmountItemAmount(id: UUID, amount: Int) {
        if let index = amountItems.firstIndex(where: { $0.id == id }) {
            amountItems[index].amount = amount
            saveData()
        }
    }
    
    /// お会計カードの参加者を更新
    public func updateAmountItemParticipants(id: UUID, participantIds: [UUID]?) {
        if let index = amountItems.firstIndex(where: { $0.id == id }) {
            amountItems[index].participantIds = participantIds
            saveData()
        }
    }
    
    /// お会計カードの割り方を更新
    public func updateAmountItemUseMultiplier(id: UUID, useMultiplier: Bool) {
        if let index = amountItems.firstIndex(where: { $0.id == id }) {
            amountItems[index].useMultiplier = useMultiplier
            saveData()
        }
    }
    
    /// メインのお会計カードを確保（なければ作成）
    public func ensureMainAmountItem() {
        if amountItems.isEmpty {
            let mainItem = AmountItem(
                name: "メインのお会計",
                amount: 0,
                participantIds: nil,
                useMultiplier: true
            )
            amountItems = [mainItem]
            saveData()
        }
    }
    
    // MARK: - カード単位の金額計算
    
    /// カードの対象参加者を取得
    func participantsForItem(_ item: AmountItem) -> [Participant] {
        if let ids = item.participantIds {
            return participants.filter { ids.contains($0.id) }
        } else {
            return participants // nil = 全員
        }
    }
    
    /// カード単位の基準金額（倍率1.0の場合の金額）
    func baseAmount(for item: AmountItem) -> Double {
        let itemParticipants = participantsForItem(item)
        guard !itemParticipants.isEmpty, item.amount > 0 else { return 0 }
        
        if item.useMultiplier {
            // 倍率適用モード
            let fixedTotal = itemParticipants.filter { $0.hasFixedAmount }
                .reduce(0) { sum, p in sum + Double(p.fixedAmount) }
            let remainingTotal = max(0, Double(item.amount) - fixedTotal)
            let nonFixedParticipants = itemParticipants.filter { !$0.hasFixedAmount }
            if nonFixedParticipants.isEmpty { return 0 }
            let totalMultiplier = nonFixedParticipants.reduce(into: 0.0) { sum, p in
                sum += p.effectiveMultiplier
            }
            guard totalMultiplier > 0 else { return 0 }
            return remainingTotal / totalMultiplier
        } else {
            // 均等割りモード
            return Double(item.amount) / Double(itemParticipants.count)
        }
    }
    
    /// カード内での参加者の支払金額
    func paymentAmount(for participant: Participant, in item: AmountItem) -> Int {
        let itemParticipants = participantsForItem(item)
        guard itemParticipants.contains(where: { $0.id == participant.id }) else { return 0 }
        
        if item.useMultiplier {
            // 固定金額の場合
            if participant.hasFixedAmount {
                return participant.fixedAmount
            }
            let base = baseAmount(for: item)
            guard base > 0 else { return 0 }
            return Int(round(base * participant.effectiveMultiplier))
        } else {
            // 均等割り
            guard !itemParticipants.isEmpty else { return 0 }
            return Int(round(Double(item.amount) / Double(itemParticipants.count)))
        }
    }
    
    /// 参加者の全カード合計支払額
    func totalPaymentAmount(for participant: Participant) -> Int {
        return amountItems.reduce(0) { sum, item in
            sum + paymentAmount(for: participant, in: item)
        }
    }
    
    // MARK: - 後方互換用プロパティ（既存UIからの参照用）
    
    /// 旧 baseAmount（最初のカードのbaseAmount）
    var baseAmount: Double {
        guard let firstItem = amountItems.first else { return 0 }
        return baseAmount(for: firstItem)
    }
    
    /// 旧 paymentAmount（全カード合計）
    func paymentAmount(for participant: Participant) -> Int {
        return totalPaymentAmount(for: participant)
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
        let targetResponses: [ScheduleResponse]
        
        if let targetDate = date {
            targetResponses = responses.filter { response in
                response.status == .attending && response.availableDates.contains { responseDate in
                    Calendar.current.isDate(responseDate, inSameDayAs: targetDate)
                }
            }
        } else {
            targetResponses = responses
        }
        
        let newParticipants = targetResponses.map { response in
            Participant(
                name: response.participantName,
                roleType: .standard(.staff), 
                source: .webResponse
            )
        }
        
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
        case .male: return 1.2
        case .female: return 0.8
        case .late: return 0.8
        case .nonDrinker: return 0.7
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
    // ランダムな絵文字を取得 (廃止: デフォルトはアプリアイコン)
    public func getRandomEmoji() -> String {
        return "" 
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
            selectedEmoji = ""
            selectedIcon = nil
            selectedIconColor = nil
            print("プランに絵文字がないため、デフォルト（アプリアイコン）を使用")
        }
        editingPlanEmoji = selectedEmoji
        
        // プランに内訳項目がある場合は読み込む
        if let items = plan.amountItems, !items.isEmpty {
            amountItems = items
        } else {
            // 旧形式: totalAmountからマイグレーション
            let legacyAmountString = plan.totalAmount.filter { $0.isNumber }
            if let legacyAmount = Int(legacyAmountString), legacyAmount > 0 {
                amountItems = [AmountItem(name: "メインのお会計", amount: legacyAmount, participantIds: nil, useMultiplier: true)]
            } else {
                amountItems = []
            }
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
