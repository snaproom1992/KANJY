import SwiftUI

struct ScheduleEventDetailView: View {
    let event: ScheduleEvent
    @ObservedObject var viewModel: ScheduleManagementViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingShareSheet = false
    @State private var showingCreateDrinkingParty = false
    @State private var showingEditEvent = false
    @State private var showingDeleteAlert = false
    @State private var showingWebView = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // イベント情報カード
                    EventInfoCard(event: event, viewModel: viewModel)
                    
                    // 統計情報カード
                    StatisticsCard(event: event, viewModel: viewModel)
                    
                    // 日時別参加者数カード
                    DateStatisticsCard(event: event, viewModel: viewModel)
                    
                    // 参加者一覧カード
                    ParticipantsCard(event: event, viewModel: viewModel)
                    
                    // アクションボタン
                    ActionButtonsCard(
                        event: event,
                        viewModel: viewModel,
                        onShare: { showingShareSheet = true },
                        onWebView: { showingWebView = true },
                        onCreateDrinkingParty: { showingCreateDrinkingParty = true },
                        onEdit: { showingEditEvent = true },
                        onDelete: { showingDeleteAlert = true }
                    )
                }
                .padding()
            }
            .navigationTitle("スケジュール調整詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ScheduleShareSheet(event: event, viewModel: viewModel)
            }
            .sheet(isPresented: $showingCreateDrinkingParty) {
                CreateDrinkingPartyView(event: event, viewModel: viewModel)
            }
            .sheet(isPresented: $showingEditEvent) {
                EditScheduleEventView(event: event, viewModel: viewModel)
            }
            .fullScreenCover(isPresented: $showingWebView) {
                ScheduleWebView(event: event, viewModel: viewModel)
            }
            .alert("スケジュール調整の削除", isPresented: $showingDeleteAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {
                    viewModel.deleteEvent(id: event.id)
                    dismiss()
                }
            } message: {
                Text("このスケジュール調整を削除してもよろしいですか？")
            }
        }
    }
}

// MARK: - スケジュール調整情報カード

struct EventInfoCard: View {
    let event: ScheduleEvent
    @ObservedObject var viewModel: ScheduleManagementViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // タイトルとステータス
            HStack {
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
                
                StatusBadge(event: event, viewModel: viewModel)
            }
            
            // 候補日時
            VStack(alignment: .leading, spacing: 12) {
                Text("候補日時（\(event.candidateDates.count)件）")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ForEach(event.candidateDates.sorted(), id: \.self) { date in
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        Text(viewModel.formatDateTime(date))
                            .font(.subheadline)
                        Spacer()
                    }
                }
            }
            
            // 基本情報
            VStack(alignment: .leading, spacing: 12) {
                if let location = event.location {
                    EventInfoRow(icon: "location", text: location)
                }
                
                if let budget = event.budget {
                    EventInfoRow(icon: "yensign.circle", text: "予算: ¥\(viewModel.formatAmount(String(budget)))")
                }
                
                if let deadline = event.deadline {
                    EventInfoRow(icon: "clock", text: "回答期限: \(viewModel.formatDateTime(deadline))")
                }
                
                EventInfoRow(icon: "person.2", text: "回答者: \(event.responses.count)人")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

struct EventInfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - 統計情報カード

struct StatisticsCard: View {
    let event: ScheduleEvent
    @ObservedObject var viewModel: ScheduleManagementViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("回答状況")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                StatItem(
                    title: "参加",
                    count: event.responses.filter { $0.status == .attending }.count,
                    color: .green,
                    icon: "checkmark.circle.fill"
                )
                
                StatItem(
                    title: "微妙",
                    count: event.responses.filter { $0.status == .maybe }.count,
                    color: .orange,
                    icon: "triangle.fill"
                )
                
                StatItem(
                    title: "不参加",
                    count: event.responses.filter { $0.status == .notAttending }.count,
                    color: .red,
                    icon: "xmark.circle.fill"
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

struct StatItem: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
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
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - 日時別統計カード

struct DateStatisticsCard: View {
    let event: ScheduleEvent
    @ObservedObject var viewModel: ScheduleManagementViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("日時別参加者数")
                .font(.headline)
                .foregroundColor(.primary)
            
            if let optimalDate = event.optimalDate {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("最適な日時: \(viewModel.formatDateTime(optimalDate))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    Spacer()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.yellow.opacity(0.1))
                )
            }
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.getDateStatistics(for: event), id: \.date) { dateStat in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.formatDateTime(dateStat.date))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if dateStat.date == event.optimalDate {
                                Text("最適")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Spacer()
                        
                        Text("\(dateStat.count)人")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(dateStat.date == event.optimalDate ? Color.green.opacity(0.1) : Color(.systemGray6))
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - 参加者一覧カード

struct ParticipantsCard: View {
    let event: ScheduleEvent
    @ObservedObject var viewModel: ScheduleManagementViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("参加者一覧")
                .font(.headline)
                .foregroundColor(.primary)
            
            if event.responses.isEmpty {
                Text("まだ回答がありません")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(event.responses.sorted { $0.responseDate > $1.responseDate }) { response in
                        ParticipantRow(response: response, event: event, viewModel: viewModel)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

struct ParticipantRow: View {
    let response: ScheduleResponse
    let event: ScheduleEvent
    @ObservedObject var viewModel: ScheduleManagementViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // アバター
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(response.participantName.prefix(1)))
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    )
                
                // 参加者情報
                VStack(alignment: .leading, spacing: 2) {
                    Text(response.participantName)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    if let department = response.department {
                        Text(department)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 回答状況
                HStack(spacing: 4) {
                    Image(systemName: response.status.icon)
                        .foregroundColor(response.status.color)
                    
                    Text(response.status.rawValue)
                        .font(.caption)
                        .foregroundColor(response.status.color)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(response.status.color.opacity(0.1))
                )
            }
            
            // 参加可能日時
            if response.status == .attending && !response.availableDates.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("参加可能日時:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(response.availableDates.sorted(), id: \.self) { date in
                        HStack {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text(viewModel.formatDateTime(date))
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.leading, 44)
            }
            
            // コメント
            if let comment = response.comment, !comment.isEmpty {
                Text(comment)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 44)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - アクションボタンカード

struct ActionButtonsCard: View {
    let event: ScheduleEvent
    @ObservedObject var viewModel: ScheduleManagementViewModel
    let onShare: () -> Void
    let onWebView: () -> Void
    let onCreateDrinkingParty: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Webページ表示ボタン
            Button(action: onWebView) {
                HStack {
                    Image(systemName: "globe")
                    Text("Webページで表示")
                    Spacer()
                }
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            // 共有ボタン
            Button(action: onShare) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("URLを共有")
                    Spacer()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            // 飲み会作成ボタン（参加者がいる場合のみ表示）
            if event.attendingCount > 0 {
                Button(action: onCreateDrinkingParty) {
                    HStack {
                        Image(systemName: "wineglass")
                        Text("飲み会を作成（\(event.attendingCount)人）")
                        Spacer()
                    }
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            
            // 編集・削除ボタン
            HStack(spacing: 12) {
                Button(action: onEdit) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("編集")
                        Spacer()
                    }
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                Button(action: onDelete) {
                    HStack {
                        Image(systemName: "trash")
                        Text("削除")
                        Spacer()
                    }
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - 共有シート

struct ScheduleShareSheet: View {
    let event: ScheduleEvent
    @ObservedObject var viewModel: ScheduleManagementViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var shareUrl: String = ""
    @State private var webUrl: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // イベント情報
                VStack(spacing: 12) {
                    Text(event.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let description = event.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("候補日時: \(event.candidateDates.count)件")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                
                // Web URL表示
                VStack(alignment: .leading, spacing: 8) {
                    Text("共有URL（Web）")
                        .font(.headline)
                    
                    Text(webUrl)
                        .font(.caption)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6))
                        )
                        .textSelection(.enabled)
                }
                
                // 共有ボタン
                Button(action: {
                    let activityVC = UIActivityViewController(
                        activityItems: [webUrl],
                        applicationActivities: nil
                    )
                    
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        window.rootViewController?.present(activityVC, animated: true)
                    }
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("共有")
                        Spacer()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("URL共有")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                shareUrl = viewModel.getShareUrl(for: event)
                webUrl = viewModel.getWebUrl(for: event)
            }
        }
    }
}

// MARK: - 飲み会作成画面

struct CreateDrinkingPartyView: View {
    let event: ScheduleEvent
    @ObservedObject var viewModel: ScheduleManagementViewModel
    @Environment(\.dismiss) private var dismiss
    
    var attendingParticipants: [ScheduleResponse] {
        event.responses.filter { $0.status == .attending }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("飲み会を作成しますか？")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("参加者（\(attendingParticipants.count)人）を飲み会の参加者として設定します")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // 参加者一覧
                VStack(alignment: .leading, spacing: 12) {
                    Text("参加者一覧")
                        .font(.headline)
                    
                    ForEach(attendingParticipants) { response in
                        HStack {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Text(String(response.participantName.prefix(1)))
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                )
                            
                            Text(response.participantName)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            if let department = response.department {
                                Text(department)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                
                Spacer()
                
                // アクションボタン
                HStack(spacing: 12) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    
                    Button("作成") {
                        createDrinkingParty()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .padding()
            .navigationTitle("飲み会作成")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func createDrinkingParty() {
        // ここで飲み会作成のロジックを実装
        // PrePlanViewModelとの連携
        dismiss()
    }
}

// MARK: - イベント編集画面

struct EditScheduleEventView: View {
    let event: ScheduleEvent
    @ObservedObject var viewModel: ScheduleManagementViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var description: String
    @State private var candidateDates: [Date]
    @State private var location: String
    @State private var budget: String
    @State private var deadline: Date?
    @State private var hasDeadline: Bool
    @State private var showingDatePicker = false
    @State private var selectedDate = Date()
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case title, description, location, budget
    }
    
    init(event: ScheduleEvent, viewModel: ScheduleManagementViewModel) {
        self.event = event
        self.viewModel = viewModel
        self._title = State(initialValue: event.title)
        self._description = State(initialValue: event.description ?? "")
        self._candidateDates = State(initialValue: event.candidateDates)
        self._location = State(initialValue: event.location ?? "")
        self._budget = State(initialValue: event.budget.map(String.init) ?? "")
        self._deadline = State(initialValue: event.deadline)
        self._hasDeadline = State(initialValue: event.deadline != nil)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("基本情報")) {
                    TextField("スケジュール調整タイトル", text: $title)
                        .focused($focusedField, equals: .title)
                    TextField("説明（任意）", text: $description, axis: .vertical)
                        .focused($focusedField, equals: .description)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("候補日時")) {
                    if candidateDates.isEmpty {
                        Text("候補日時が設定されていません")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(candidateDates.sorted(), id: \.self) { date in
                            HStack {
                                Text(viewModel.formatDateTime(date))
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                Button(action: {
                                    candidateDates.removeAll { $0 == date }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    
                    Button(action: {
                        selectedDate = Date()
                        showingDatePicker = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("候補日時を追加")
                        }
                    }
                }
                
                Section(header: Text("詳細情報")) {
                    TextField("場所（任意）", text: $location)
                        .focused($focusedField, equals: .location)
                    TextField("予算（任意）", text: $budget)
                        .focused($focusedField, equals: .budget)
                        .keyboardType(.numberPad)
                }
                
                Section(header: Text("回答期限")) {
                    Toggle("回答期限を設定", isOn: $hasDeadline)
                    
                    if hasDeadline {
                        DatePicker("期限", selection: Binding(
                            get: { deadline ?? Date() },
                            set: { deadline = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                    }
                }
            }
            .navigationTitle("スケジュール調整編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveEvent()
                    }
                    .disabled(title.isEmpty || candidateDates.isEmpty)
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerSheet(
                    selectedDate: $selectedDate,
                    onAdd: {
                        candidateDates.append(selectedDate)
                        showingDatePicker = false
                    },
                    onCancel: {
                        showingDatePicker = false
                    }
                )
            }
        }
    }
    
    private func saveEvent() {
        var updatedEvent = event
        updatedEvent.title = title
        updatedEvent.description = description.isEmpty ? nil : description
        updatedEvent.candidateDates = candidateDates
        updatedEvent.location = location.isEmpty ? nil : location
        updatedEvent.budget = budget.isEmpty ? nil : Int(budget)
        updatedEvent.deadline = hasDeadline ? deadline : nil
        
        viewModel.updateEvent(updatedEvent)
        dismiss()
    }
}

// MARK: - プレビュー

#Preview {
    let sampleEvent = ScheduleEvent(
        title: "忘年会",
        description: "今年一年お疲れ様でした！",
        candidateDates: [
            Date().addingTimeInterval(7 * 24 * 60 * 60),
            Date().addingTimeInterval(14 * 24 * 60 * 60),
            Date().addingTimeInterval(21 * 24 * 60 * 60)
        ],
        location: "居酒屋 〇〇",
        budget: 5000,
        responses: [
            ScheduleResponse(
                participantName: "田中太郎",
                availableDates: [Date().addingTimeInterval(7 * 24 * 60 * 60)],
                maybeDates: [Date().addingTimeInterval(14 * 24 * 60 * 60)],
                status: .attending,
                department: "営業部"
            ),
            ScheduleResponse(
                participantName: "佐藤花子",
                availableDates: [Date().addingTimeInterval(21 * 24 * 60 * 60)],
                maybeDates: [],
                status: .attending,
                department: "総務部"
            )
        ],
        deadline: Date().addingTimeInterval(5 * 24 * 60 * 60)
    )
    
    ScheduleEventDetailView(event: sampleEvent, viewModel: ScheduleManagementViewModel())
} 