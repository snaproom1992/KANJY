import SwiftUI

struct ScheduleResponseView: View {
    @State var event: ScheduleEvent
    @State private var showingResponseForm = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // ヘッダー
                    EventHeaderCard(event: event)
                    
                    // 参加状況サマリー
                    ResponseSummaryCard(event: event)
                    
                    // 日時ごとの詳細状況
                    DateDetailCard(event: event)
                    
                    // 出欠回答ボタン
                    ResponseActionCard(
                        event: event,
                        onResponse: { showingResponseForm = true }
                    )
                    
                    // 参加者一覧（簡易版）
                    ParticipantsListCard(event: event)
                }
                .padding(20)
            }
            .navigationTitle("スケジュール調整")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await refreshEventData()
            }
            .sheet(isPresented: $showingResponseForm) {
                ScheduleResponseFormView(event: event)
            }
        }
    }
    
    // データ更新処理
    private func refreshEventData() async {
        do {
            let responses = try await AttendanceManager.shared.fetchResponsesFromSupabase(eventId: event.id)
            await MainActor.run {
                event.responses = responses
            }
        } catch {
            print("❌ データ更新エラー: \(error)")
        }
    }
}

// MARK: - イベントヘッダーカード

struct EventHeaderCard: View {
    let event: ScheduleEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // タイトルとアイコン
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if let description = event.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // 基本情報
            VStack(spacing: 12) {
                InfoRow(
                    icon: "person.2.fill",
                    text: "現在の回答者: \(event.responses.count)人",
                    color: .blue
                )
                
                if let deadline = event.deadline {
                    InfoRow(
                        icon: "clock.fill",
                        text: "回答期限: \(formatDateTime(deadline))",
                        color: .orange
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d(E) HH:mm"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

struct InfoRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - 参加状況サマリーカード

struct ResponseSummaryCard: View {
    let event: ScheduleEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("現在の参加状況")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                SummaryItem(
                    title: "参加",
                    count: event.responses.filter { $0.status == .attending }.count,
                    color: AttendanceStatus.attending.color,
                    icon: AttendanceStatus.attending.icon
                )
                
                SummaryItem(
                    title: "微妙",
                    count: event.responses.filter { $0.status == .maybe }.count,
                    color: AttendanceStatus.maybe.color,
                    icon: AttendanceStatus.maybe.icon
                )
                
                SummaryItem(
                    title: "不参加",
                    count: event.responses.filter { $0.status == .notAttending }.count,
                    color: AttendanceStatus.notAttending.color,
                    icon: AttendanceStatus.notAttending.icon
                )
                
                SummaryItem(
                    title: "未回答",
                    count: event.responses.filter { $0.status == .undecided }.count,
                    color: AttendanceStatus.undecided.color,
                    icon: AttendanceStatus.undecided.icon
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

struct SummaryItem: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 日時ごとの詳細状況カード

struct DateDetailCard: View {
    let event: ScheduleEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("候補日時の詳細")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ForEach(event.candidateDates.sorted(), id: \.self) { date in
                    DateDetailRow(event: event, date: date)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

struct DateDetailRow: View {
    let event: ScheduleEvent
    let date: Date
    
    var body: some View {
        VStack(spacing: 8) {
            // 日時表示
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatDate(date))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(formatTime(date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 合計人数
                Text("\(totalCount)人")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.1))
                    )
            }
            
            // 参加状況表示
            HStack(spacing: 8) {
                // 参加人数表示
                StatusCount(
                    status: .attending,
                    count: event.attendingCountForDate(date)
                )
                
                Spacer()
                
                // 参加者名表示
                if !attendingParticipants.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.blue)
                            .font(.caption2)
                        Text(attendingParticipants.map { $0.participantName }.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var totalCount: Int {
        event.attendingCountForDate(date)
    }
    
    private var attendingParticipants: [ScheduleResponse] {
        event.responses.filter { response in
            response.availableDates.contains { Calendar.current.isDate($0, inSameDayAs: date) }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日(E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct StatusCount: View {
    let status: AttendanceStatus
    let count: Int
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.icon)
                .font(.caption)
                .fontWeight(.semibold)
            
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.bold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(status.color)
                .shadow(color: status.color.opacity(0.3), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - 出欠回答アクションカード

struct ResponseActionCard: View {
    let event: ScheduleEvent
    let onResponse: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("あなたの出欠を教えてください")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("候補日時から参加可能な日を選んで回答してください")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onResponse) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .font(.title3)
                    
                    Text("出欠を回答する")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - 参加者一覧カード（簡易版）

struct ParticipantsListCard: View {
    let event: ScheduleEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("回答済みの方")
                .font(.headline)
                .foregroundColor(.primary)
            
            if event.responses.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.3.sequence")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    
                    Text("まだ回答がありません")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("最初の回答者になりませんか？")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(event.responses.sorted { $0.responseDate > $1.responseDate }) { response in
                        SimpleParticipantRow(response: response)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

struct SimpleParticipantRow: View {
    let response: ScheduleResponse
    
    var body: some View {
        HStack(spacing: 12) {
            // アバター
            Circle()
                .fill(response.status.color.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(response.participantName.prefix(1)))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(response.status.color)
                )
            
            // 参加者情報
            VStack(alignment: .leading, spacing: 2) {
                Text(response.participantName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if let department = response.department {
                    Text(department)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // ステータス
            HStack(spacing: 4) {
                Image(systemName: response.status.icon)
                    .font(.caption)
                    .foregroundColor(response.status.color)
                
                Text(response.status.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(response.status.color)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(response.status.color.opacity(0.1))
            )
        }
        .padding(.vertical, 4)
    }
}

// MARK: - プレビュー

#Preview {
    NavigationView {
        ScheduleResponseView(event: ScheduleEvent(
            id: UUID(),
            title: "新年会",
            description: "みんなで楽しく新年会をしましょう！",
            candidateDates: [
                Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 15, hour: 18, minute: 0))!,
                Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 16, hour: 18, minute: 0))!,
                Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 17, hour: 18, minute: 0))!
            ],
            responses: [
                ScheduleResponse(
                    participantName: "田中花子",
                    availableDates: [Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 15, hour: 18, minute: 0))!],
                    maybeDates: [Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 16, hour: 18, minute: 0))!],
                    status: .attending,
                    comment: "15日は確実に参加できます！16日は微妙です。"
                ),
                ScheduleResponse(
                    participantName: "佐藤次郎",
                    availableDates: [],
                    maybeDates: [Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 17, hour: 18, minute: 0))!],
                    status: .maybe,
                    comment: "17日は仕事次第です。"
                )
            ],
            createdBy: "山田太郎",
            createdAt: Date()
        ))
    }
} 