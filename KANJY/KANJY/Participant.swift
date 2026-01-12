import Foundation

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
