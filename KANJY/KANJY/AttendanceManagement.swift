import SwiftUI
import Foundation
import Supabase

// MARK: - スケジュール調整用のデータモデル

// 出欠回答を表す列挙型
public enum AttendanceStatus: String, CaseIterable, Codable {
    case attending = "参加"
    case maybe = "微妙"
    case notAttending = "不参加"
    case undecided = "未回答"
    
    var color: Color {
        switch self {
        case .attending: return DesignSystem.Colors.Attendance.attending
        case .maybe: return DesignSystem.Colors.Attendance.maybe
        case .notAttending: return DesignSystem.Colors.Attendance.notAttending
        case .undecided: return DesignSystem.Colors.Attendance.undecided
        }
    }
    
    var icon: String {
        switch self {
        case .attending: return "checkmark.circle.fill"
        case .maybe: return "triangle.circle.fill"
        case .notAttending: return "xmark.circle.fill"
        case .undecided: return "circle"
        }
    }
    

}

// スケジュール回答を表す構造体
public struct ScheduleResponse: Identifiable, Codable {
    public let id: UUID
    public var participantName: String  // 自由入力の参加者名
    public var availableDates: [Date]   // 参加可能な日時
    public var maybeDates: [Date]       // 微妙な日時
    public var status: AttendanceStatus
    public var responseDate: Date
    public var comment: String?
    public var department: String?      // 部署（任意）
    
    public init(id: UUID = UUID(), participantName: String, availableDates: [Date] = [], maybeDates: [Date] = [], status: AttendanceStatus, responseDate: Date = Date(), comment: String? = nil, department: String? = nil) {
        self.id = id
        self.participantName = participantName
        self.availableDates = availableDates
        self.maybeDates = maybeDates
        self.status = status
        self.responseDate = responseDate
        self.comment = comment
        self.department = department
    }
}

// スケジュール調整イベントを表す構造体
public struct ScheduleEvent: Identifiable, Codable {
    public let id: UUID
    public var title: String
    public var description: String?
    public var candidateDates: [Date]  // 候補日時
    public var location: String?
    public var budget: Int?
    public var responses: [ScheduleResponse]
    public var deadline: Date?
    public var isActive: Bool = true
    public var shareUrl: String?
    public var webUrl: String?         // Web URL
    public var createdBy: String       // 作成者
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(id: UUID = UUID(), title: String, description: String? = nil, candidateDates: [Date] = [], location: String? = nil, budget: Int? = nil, responses: [ScheduleResponse] = [], deadline: Date? = nil, isActive: Bool = true, shareUrl: String? = nil, webUrl: String? = nil, createdBy: String = "匿名", createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.description = description
        self.candidateDates = candidateDates
        self.location = location
        self.budget = budget
        self.responses = responses
        self.deadline = deadline
        self.isActive = isActive
        self.shareUrl = shareUrl
        self.webUrl = webUrl
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // 参加者数を取得
    var attendingCount: Int {
        responses.filter { $0.status == .attending }.count
    }
    
    // 微妙な参加者数を取得
    var maybeCount: Int {
        responses.filter { $0.status == .maybe }.count
    }
    
    // 不参加者数を取得
    var notAttendingCount: Int {
        responses.filter { $0.status == .notAttending }.count
    }
    
    // 未定者数を取得
    var undecidedCount: Int {
        responses.filter { $0.status == .undecided }.count
    }
    
    // 回答率を取得
    var responseRate: Double {
        // 回答率は参加者数で計算（自由入力のため）
        return 100.0 // 常に100%として扱う
    }
    
    // 各日時の参加者数を取得
    func attendingCountForDate(_ date: Date) -> Int {
        return responses.filter { response in
            response.availableDates.contains { Calendar.current.isDate($0, inSameDayAs: date) }
        }.count
    }
    
    // 各日時の微妙な参加者数を取得
    func maybeCountForDate(_ date: Date) -> Int {
        return responses.filter { response in
            response.maybeDates.contains { Calendar.current.isDate($0, inSameDayAs: date) }
        }.count
    }
    
    // 最適な日時を取得（参加者数が最多の日時）
    var optimalDate: Date? {
        guard !candidateDates.isEmpty else { return nil }
        
        let dateCounts = candidateDates.map { date in
            (date: date, count: attendingCountForDate(date))
        }
        
        return dateCounts.max { $0.count < $1.count }?.date
    }
}

// MARK: - Supabase DTO (Data Transfer Objects)

// Supabaseから取得するイベントのDTO
private struct EventDTO: Codable {
    let id: String
    let title: String
    let description: String?
    let candidate_dates: [String]
    let location: String?
    let budget: Int?
    let deadline: String?
    let is_active: Bool
    let share_url: String?
    let web_url: String?
    let created_by: String?  // nullの可能性があるためオプショナルに変更
    let created_at: String
    let updated_at: String
}

// Supabaseから取得する回答のDTO
private struct ResponseDTO: Codable {
    let id: String
    let event_id: String
    let participant_name: String
    let available_dates: [String]
    let maybe_dates: [String]?
    let status: String
    let comment: String?
    let department: String?
    let response_date: String
    let created_at: String
}

// MARK: - スケジュール調整ViewModel

public class ScheduleManagementViewModel: ObservableObject {
    @Published public var events: [ScheduleEvent] = []
    @Published public var selectedEvent: ScheduleEvent?
    
    @AppStorage("scheduleEvents") private var eventsData: Data = Data()
    
    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }
    
    public init() {
        loadData()
    }
    
    // MARK: - データ管理
    
    private func loadData() {
        if let decodedEvents = try? JSONDecoder().decode([ScheduleEvent].self, from: eventsData) {
            events = decodedEvents
        }
    }
    
    private func saveData() {
        if let encodedEvents = try? JSONEncoder().encode(events) {
            eventsData = encodedEvents
        }
    }
    
    // MARK: - イベント管理
    
    // Supabaseに送信するための構造体
    private struct SupabaseEventInsert: Encodable {
        let id: String
        let title: String
        let description: String?
        let candidate_dates: [String]
        let location: String?
        let budget: Int?
        let deadline: String?
        let share_url: String
        let web_url: String
        let created_by: String
        let is_active: Bool
        let created_at: String
        let updated_at: String
    }
    
    // Supabase更新用の構造体
    private struct SupabaseEventUpdate: Encodable {
        let title: String
        let description: String?
        let candidate_dates: [String]
        let location: String?
        let budget: Int?
        let deadline: String?
        let updated_at: String
    }
    
    /// Supabaseにイベントを作成
    public func createEventInSupabase(title: String, description: String?, candidateDates: [Date], location: String?, budget: Int?, deadline: Date?, createdBy: String = "匿名") async throws -> ScheduleEvent {
        do {
        // 統一されたUUIDを生成
        let eventId = UUID()
        let shareUrl = generateShareUrl()
        let webUrl = generateWebUrl(eventId: eventId)
        let now = Date()
        
        // ID未取得の場合はここでログインを試行（遅延ログイン）
        if SupabaseManager.shared.currentUserId == nil {
            print("⚠️ ID未取得のため、強制ログインを試行します")
            try? await SupabaseManager.shared.signInAnonymously()
        }
        
        print("🍙 Supabase保存開始")
        print("🍙 EventID: \(eventId)")
        print("🍙 WebURL: \(webUrl)")
        let eventData = SupabaseEventInsert(
            id: eventId.uuidString.lowercased(),
            title: title,
            description: description,
            candidate_dates: candidateDates.map { ISO8601DateFormatter().string(from: $0) },
            location: location,
            budget: budget,
            deadline: deadline != nil ? ISO8601DateFormatter().string(from: deadline!) : nil,
            share_url: shareUrl,
            web_url: webUrl,
            created_by: SupabaseManager.shared.currentUserId ?? createdBy,
            is_active: true,
            created_at: ISO8601DateFormatter().string(from: now),
            updated_at: ISO8601DateFormatter().string(from: now)
        )
        print("🍙 Supabase insert実行中...")
        _ = try await supabase
            .from("events")
            .insert(eventData)
            .select()
            .execute()
        print("🍙 Supabase insert完了")
        
        // 入力データをそのまま使用してScheduleEventを作成
        let event = ScheduleEvent(
            id: eventId,
            title: title,
            description: description,
            candidateDates: candidateDates,
            location: location,
            budget: budget,
            responses: [],
            deadline: deadline,
            isActive: true,
            shareUrl: shareUrl,
            webUrl: webUrl,
            createdBy: SupabaseManager.shared.currentUserId ?? createdBy,
            createdAt: now,
            updatedAt: now
        )
        print("🍙 作成されたイベント: \(event)")
        
        // ローカルにも追加
        await MainActor.run {
            self.events.append(event)
            self.saveData()
        }
        print("🍙 Supabase保存完了!")
        return event
        } catch {
            print("🍙 Supabase保存エラー: \(error)")
            throw error
        }
    }
    
    public func updateEvent(_ event: ScheduleEvent) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            var updatedEvent = event
            updatedEvent.updatedAt = Date()
            events[index] = updatedEvent
            saveData()
        }
    }
    
    /// Supabaseでイベントを更新
    public func updateEventInSupabase(eventId: UUID, title: String, description: String?, candidateDates: [Date], location: String?, budget: Int?, deadline: Date?) async throws {
        do {
            let now = Date()
            let updateData = SupabaseEventUpdate(
                title: title,
                description: description,
                candidate_dates: candidateDates.map { ISO8601DateFormatter().string(from: $0) },
                location: location,
                budget: budget,
                deadline: deadline != nil ? ISO8601DateFormatter().string(from: deadline!) : nil,
                updated_at: ISO8601DateFormatter().string(from: now)
            )
            
            print("🍙 Supabase更新開始 - EventID: \(eventId)")
            _ = try await supabase
                .from("events")
                .update(updateData)
                .eq("id", value: eventId.uuidString.lowercased())
                .select()
                .execute()
            
            print("🍙 Supabase更新完了")
            
            // ローカルデータも更新
            await MainActor.run {
                if let index = self.events.firstIndex(where: { $0.id == eventId }) {
                    var updatedEvent = self.events[index]
                    updatedEvent.title = title
                    updatedEvent.description = description
                    updatedEvent.candidateDates = candidateDates
                    updatedEvent.location = location
                    updatedEvent.budget = budget
                    updatedEvent.deadline = deadline
                    updatedEvent.updatedAt = now
                    self.events[index] = updatedEvent
                    self.saveData()
                }
            }
        } catch {
            print("🍙 Supabase更新エラー: \(error)")
            throw error
        }
    }
    
    public func deleteEvent(id: UUID) async throws {
        // ローカルから削除
        events.removeAll { $0.id == id }
        saveData()
        
        // Supabaseからも削除
        try await deleteEventInSupabase(eventId: id)
    }
    
    private func deleteEventInSupabase(eventId: UUID) async throws {
        print("🍙 Supabase削除開始 - EventID: \(eventId)")
        
        // ID未取得の場合はここで再ログインを試行（作成時と同じロジック）
        if SupabaseManager.shared.currentUserId == nil {
            print("⚠️ 削除前: ID未取得のため、セッション復元を試行します")
            try? await SupabaseManager.shared.signInAnonymously()
        }
        
        print("🍙 現在のUserID: \(SupabaseManager.shared.currentUserId ?? "nil")")
        
        _ = try await supabase
            .from("events")
            .delete()
            .eq("id", value: eventId.uuidString.lowercased())
            .execute()
        
        print("🍙 Supabase削除リクエスト完了")
    }
    
    // MARK: - 回答管理
    
    public func addResponse(eventId: UUID, participantName: String, availableDates: [Date], maybeDates: [Date] = [], status: AttendanceStatus, comment: String?, department: String?) {
        let response = ScheduleResponse(
            participantName: participantName,
            availableDates: availableDates,
            maybeDates: maybeDates,
            status: status,
            comment: comment,
            department: department
        )
        
        if let eventIndex = events.firstIndex(where: { $0.id == eventId }) {
            events[eventIndex].responses.append(response)
            events[eventIndex].updatedAt = Date()
            saveData()
        }
    }
    
    public func getResponse(for eventId: UUID, participantName: String) -> ScheduleResponse? {
        guard let event = events.first(where: { $0.id == eventId }) else { return nil }
        return event.responses.first { $0.participantName == participantName }
    }
    
    // MARK: - URL生成・共有
    
    private func generateShareUrl() -> String {
        let baseUrl = "kanjy://schedule/"
        let uniqueId = UUID().uuidString
        return baseUrl + uniqueId
    }
    
    private func generateWebUrl(eventId: UUID? = nil) -> String {
        // 本番環境のURL（Vercel）
        let baseUrl = "https://kanjy.vercel.app/?id="
        let uniqueId = eventId?.uuidString.lowercased() ?? UUID().uuidString.lowercased()
        return baseUrl + uniqueId
    }
    
    public func getShareUrl(for event: ScheduleEvent) -> String {
        return event.shareUrl ?? generateShareUrl()
    }
    
    public func getWebUrl(for event: ScheduleEvent) -> String {
        // 古いNetlifyのURLが保存されている場合は無視して、常に最新のVercel URLを生成
        if let webUrl = event.webUrl, webUrl.contains("kanjy-web.netlify.app") {
            // 古いNetlify URLの場合は、新しいVercel URLを生成
            return generateWebUrl(eventId: event.id)
        }
        // webUrlがVercelのURLの場合はそれを使用、それ以外は新しく生成
        if let webUrl = event.webUrl, webUrl.contains("kanjy.vercel.app") {
            return webUrl
        }
        // webUrlがnilまたは予期しないURLの場合は新しく生成
        return generateWebUrl(eventId: event.id)
    }
    
    // MARK: - 統計情報
    
    public func getEventStatistics(for event: ScheduleEvent) -> [String: Int] {
        return [
            "attending": event.attendingCount,
            "notAttending": event.notAttendingCount,
            "undecided": event.undecidedCount,
            "total": event.responses.count
        ]
    }
    
    public func getDateStatistics(for event: ScheduleEvent) -> [(date: Date, count: Int)] {
        return event.candidateDates.map { date in
            (date: date, count: event.attendingCountForDate(date))
        }.sorted { $0.count > $1.count }
    }
    
    // MARK: - ユーティリティ
    
    public func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    public func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    public func formatAmount(_ input: String) -> String {
        let numbers = input.filter { $0.isNumber }
        if numbers.isEmpty { return "0" }
        guard let amount = Int(numbers) else { return input }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        
        return formatter.string(from: NSNumber(value: amount)) ?? input
    }
    
    public func isDeadlinePassed(for event: ScheduleEvent) -> Bool {
        guard let deadline = event.deadline else { return false }
        return Date() > deadline
    }
    
    public func isEventPassed(for event: ScheduleEvent) -> Bool {
        guard let optimalDate = event.optimalDate else { return false }
        return Date() > optimalDate
    }
    
    /// Supabaseからイベント一覧を取得
    public func fetchEventsFromSupabase() async {
        do {
            let eventDTOs: [EventDTO] = try await supabase
                .from("events")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            
            let dateFormatter = ISO8601DateFormatter()
            
            // イベントと回答を取得
            let events: [ScheduleEvent] = await withTaskGroup(of: ScheduleEvent?.self) { group in
                for dto in eventDTOs {
                    group.addTask {
                        let eventId = UUID(uuidString: dto.id) ?? UUID()
                        
                        // 各イベントの回答を取得
                        let responses = (try? await AttendanceManager.shared.fetchResponsesFromSupabase(eventId: eventId)) ?? []
                        
                        return ScheduleEvent(
                            id: eventId,
                            title: dto.title,
                            description: dto.description,
                            candidateDates: dto.candidate_dates.compactMap { dateFormatter.date(from: $0) },
                            location: dto.location,
                            budget: dto.budget,
                            responses: responses,
                            deadline: dto.deadline.flatMap { dateFormatter.date(from: $0) },
                            isActive: dto.is_active,
                            shareUrl: dto.share_url,
                            webUrl: dto.web_url,
                            createdBy: dto.created_by ?? "匿名",
                            createdAt: dateFormatter.date(from: dto.created_at) ?? Date(),
                            updatedAt: dateFormatter.date(from: dto.updated_at) ?? Date()
                        )
                    }
                }
                
                var result: [ScheduleEvent] = []
                for await event in group {
                    if let event = event {
                        result.append(event)
                    }
                }
                return result
            }
            
            await MainActor.run {
                self.events = events
                self.saveData()
            }
        } catch {
            print("Supabase取得エラー: \(error)")
        }
    }
}

// MARK: - AttendanceManager

public class AttendanceManager: ObservableObject {
    public static let shared = AttendanceManager()
    

    
    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }
    
    private init() {}
    
    // Supabaseに送信するための構造体（回答用）
    private struct SupabaseResponseInsert: Encodable {
        let event_id: String
        let participant_name: String
        let available_dates: [String]
        let maybe_dates: [String]
        let status: String
        let comment: String?
        let department: String?
        let response_date: String
        let created_at: String
    }
    
    // ScheduleResponseオブジェクトを受け取るバージョン
    public func addResponseToSupabase(eventId: UUID, response: ScheduleResponse) async throws {
        let now = Date()
        
        let responseData = SupabaseResponseInsert(
            event_id: eventId.uuidString,
            participant_name: response.participantName,
            available_dates: response.availableDates.map { ISO8601DateFormatter().string(from: $0) },
            maybe_dates: response.maybeDates.map { ISO8601DateFormatter().string(from: $0) },
            status: response.status.rawValue,
            comment: response.comment,
            department: response.department,
            response_date: ISO8601DateFormatter().string(from: now),
            created_at: ISO8601DateFormatter().string(from: now)
        )
        _ = try await supabase
            .from("responses")
            .insert(responseData)
            .execute()
    }
    
    /// Supabaseから特定イベントの回答一覧を取得
    public func fetchResponsesFromSupabase(eventId: UUID) async throws -> [ScheduleResponse] {
        do {
            let responseDTOs: [ResponseDTO] = try await supabase
                .from("responses")
                .select()
                .eq("event_id", value: eventId.uuidString.lowercased())
                .order("created_at", ascending: false)
                .execute()
                .value
            
            let dateFormatter = ISO8601DateFormatter()
            let responses: [ScheduleResponse] = responseDTOs.compactMap { dto in
                // 削除済みレコードをスキップ
                if dto.participant_name.hasPrefix("[削除済み]") {
                    return nil
                }
                
                // available_datesをDate配列に変換
                let availableDates = dto.available_dates.compactMap { dateFormatter.date(from: $0) }
                
                // statusをAttendanceStatusに変換
                let status: AttendanceStatus
                switch dto.status {
                case "attending":
                    status = .attending
                case "not_attending":
                    status = .notAttending
                case "maybe":
                    status = .maybe
                default:
                    status = .undecided
                }
                
                return ScheduleResponse(
                    id: UUID(uuidString: dto.id) ?? UUID(),
                    participantName: dto.participant_name,
                    availableDates: availableDates,
                    maybeDates: [], // WebフォームではmaybeDatesは使用していない
                    status: status,
                    responseDate: dateFormatter.date(from: dto.response_date) ?? Date(),
                    comment: dto.comment,
                    department: dto.department
                )
            }
            
            return responses
        } catch {
            print("🍙 回答取得エラー: \(error)")
            throw error
        }
    }
}

// MARK: - 共通コンポーネント

// 共有シート
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - URL表示シート

struct EventUrlSheet: View {
    let event: ScheduleEvent
    let viewModel: ScheduleManagementViewModel
    let onDismiss: () -> Void
    
    @State private var showingShareSheet = false
    @State private var showingCopyAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 成功メッセージ
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(DesignSystem.Colors.success)
                    
                    Text("スケジュール調整が作成されました！")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(event.title)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // URL表示エリア
                VStack(spacing: 16) {
                    Text("共有URL")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 8) {
                        // Web URL
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Webページ")
                                .font(.caption)
                                .foregroundColor(.secondary)
                
                            HStack {
                                Text(viewModel.getWebUrl(for: event))
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                
                                Button(action: {
                                    UIPasteboard.general.string = viewModel.getWebUrl(for: event)
                                    showingCopyAlert = true
                                }) {
                                    Image(systemName: "doc.on.clipboard")
                                        .foregroundColor(DesignSystem.Colors.primary)
                                        .padding(.leading, 8)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        
                        // アプリURL
                        VStack(alignment: .leading, spacing: 4) {
                            Text("アプリ内リンク")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(viewModel.getShareUrl(for: event))
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                }
                
                // アクションボタン
                VStack(spacing: 12) {
                    // ワンクリックコピーボタン
                    Button(action: {
                        UIPasteboard.general.string = viewModel.getWebUrl(for: event)
                        showingCopyAlert = true
                    }) {
                        HStack {
                            Image(systemName: "doc.on.clipboard.fill")
                            Text("WebURLをコピー")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(DesignSystem.Colors.success)
                        .foregroundColor(DesignSystem.Colors.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        showingShareSheet = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("URLを共有")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(DesignSystem.Colors.primary)
                        .foregroundColor(DesignSystem.Colors.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: onDismiss) {
                        Text("完了")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("共有URL")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [viewModel.getWebUrl(for: event)])
        }
        .alert("コピー完了", isPresented: $showingCopyAlert) {
            Button("OK") { }
        } message: {
            Text("WebURLがクリップボードにコピーされました")
        }
    }
} 