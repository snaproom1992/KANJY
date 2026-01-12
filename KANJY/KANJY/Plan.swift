import Foundation

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
