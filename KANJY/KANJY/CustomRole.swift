import Foundation

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
