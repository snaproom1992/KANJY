import Foundation
import SwiftUI

// データ永続化を担当するリポジトリ
class PlanRepository {
    static let shared = PlanRepository()
    
    // キー定義
    private enum Keys {
        static let participants = "participants"
        static let customRoles = "customRoles"
        static let totalAmount = "totalAmount"
        static let roleMultipliers = "roleMultipliers"
        static let roleNames = "roleNames"
        static let savedPlans = "savedPlans"
        static let amountItems = "amountItems"
        static let selectedEmoji = "selectedEmoji"
        static let selectedIcon = "selectedIcon"
        static let selectedIconColor = "selectedIconColor"
    }
    
    // UserDefaultsへの参照
    private let defaults = UserDefaults.standard
    
    // MARK: - 読み込みメソッド
    
    func loadParticipants() -> [Participant] {
        guard let data = defaults.data(forKey: Keys.participants) else { return [] }
        return (try? JSONDecoder().decode([Participant].self, from: data)) ?? []
    }
    
    func loadCustomRoles() -> [CustomRole] {
        guard let data = defaults.data(forKey: Keys.customRoles) else { return [] }
        return (try? JSONDecoder().decode([CustomRole].self, from: data)) ?? []
    }
    
    func loadTotalAmount() -> String {
        return defaults.string(forKey: Keys.totalAmount) ?? ""
    }
    
    func loadRoleMultipliers() -> [String: Double] {
        guard let data = defaults.data(forKey: Keys.roleMultipliers) else { return [:] }
        return (try? JSONDecoder().decode([String: Double].self, from: data)) ?? [:]
    }
    
    func loadRoleNames() -> [String: String] {
        guard let data = defaults.data(forKey: Keys.roleNames) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }
    
    func loadSavedPlans() -> [Plan] {
        guard let data = defaults.data(forKey: Keys.savedPlans) else { return [] }
        return (try? JSONDecoder().decode([Plan].self, from: data)) ?? []
    }
    
    func loadAmountItems() -> [AmountItem] {
        guard let data = defaults.data(forKey: Keys.amountItems) else { return [] }
        return (try? JSONDecoder().decode([AmountItem].self, from: data)) ?? []
    }
    
    func loadSelectedEmoji() -> String {
        return defaults.string(forKey: Keys.selectedEmoji) ?? "🍻"
    }
    
    func loadSelectedIcon() -> String {
        return defaults.string(forKey: Keys.selectedIcon) ?? ""
    }
    
    func loadSelectedIconColor() -> String {
        return defaults.string(forKey: Keys.selectedIconColor) ?? ""
    }
    
    // MARK: - 保存メソッド
    
    func saveParticipants(_ participants: [Participant]) {
        if let data = try? JSONEncoder().encode(participants) {
            defaults.set(data, forKey: Keys.participants)
        }
    }
    
    func saveCustomRoles(_ roles: [CustomRole]) {
        if let data = try? JSONEncoder().encode(roles) {
            defaults.set(data, forKey: Keys.customRoles)
        }
    }
    
    func saveTotalAmount(_ amount: String) {
        defaults.set(amount, forKey: Keys.totalAmount)
    }
    
    func saveRoleMultipliers(_ multipliers: [String: Double]) {
        if let data = try? JSONEncoder().encode(multipliers) {
            defaults.set(data, forKey: Keys.roleMultipliers)
        }
    }
    
    func saveRoleNames(_ names: [String: String]) {
        if let data = try? JSONEncoder().encode(names) {
            defaults.set(data, forKey: Keys.roleNames)
        }
    }
    
    func saveSavedPlans(_ plans: [Plan]) {
        if let data = try? JSONEncoder().encode(plans) {
            defaults.set(data, forKey: Keys.savedPlans)
        }
    }
    
    func saveAmountItems(_ items: [AmountItem]) {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: Keys.amountItems)
        }
    }
    
    func saveSelectedEmoji(_ emoji: String) {
        defaults.set(emoji, forKey: Keys.selectedEmoji)
    }
    
    func saveSelectedIcon(_ icon: String) {
        defaults.set(icon, forKey: Keys.selectedIcon)
    }
    
    func saveSelectedIconColor(_ color: String) {
        defaults.set(color, forKey: Keys.selectedIconColor)
    }
}
