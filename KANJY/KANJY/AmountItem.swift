import Foundation

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
