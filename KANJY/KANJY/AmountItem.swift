import Foundation

// お会計項目を表す構造体（一次会、二次会など独立した支払い単位）
public struct AmountItem: Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String
    public var amount: Int
    public var participantIds: [UUID]?   // 参加する人のID。nil = 全員
    public var useMultiplier: Bool       // true = 役職倍率を適用、false = 均等割り
    
    public init(id: UUID = UUID(), name: String, amount: Int, participantIds: [UUID]? = nil, useMultiplier: Bool = true) {
        self.id = id
        self.name = name
        self.amount = amount
        self.participantIds = participantIds
        self.useMultiplier = useMultiplier
    }
    
    // カスタムデコーダ（旧データとの互換性を保つ）
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        amount = try container.decode(Int.self, forKey: .amount)
        participantIds = try container.decodeIfPresent([UUID].self, forKey: .participantIds)
        useMultiplier = try container.decodeIfPresent(Bool.self, forKey: .useMultiplier) ?? true
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, amount, participantIds, useMultiplier
    }
}
