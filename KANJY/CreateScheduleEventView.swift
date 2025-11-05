import SwiftUI

struct CreateScheduleEventView: View {
    @ObservedObject var viewModel: ScheduleManagementViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var candidateDates: [Date] = []
    @State private var location = ""
    @State private var budget = ""
    @State private var deadline: Date?
    @State private var hasDeadline = false
    @State private var showingDatePicker = false
    @State private var selectedDate = Date()
    @State private var showingUrlSheet = false
    @State private var createdEvent: ScheduleEvent?
    
    // 親Viewへの通知用クロージャ
    var onEventCreated: ((ScheduleEvent) -> Void)?
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case title, description, location, budget
    }
    
    init(viewModel: ScheduleManagementViewModel, onEventCreated: ((ScheduleEvent) -> Void)? = nil) {
        self.viewModel = viewModel
        self.onEventCreated = onEventCreated
    }
    
    // 飲み会計画（Plan）からスケジュール調整を作成するための初期化子
    init(viewModel: ScheduleManagementViewModel, plan: Plan, onEventCreated: ((ScheduleEvent) -> Void)? = nil) {
        self.viewModel = viewModel
        self.onEventCreated = onEventCreated
        
        // Planから情報を引き継ぐ
        _title = State(initialValue: plan.name)
        _candidateDates = State(initialValue: [plan.date])
        if let totalAmountString = plan.totalAmount.filter({ $0.isNumber }).isEmpty ? nil : plan.totalAmount.filter({ $0.isNumber }),
           let totalAmountInt = Int(totalAmountString) {
            _budget = State(initialValue: String(totalAmountInt))
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 基本情報セクション
                Section(header: Text("基本情報")) {
                    TextField("イベントタイトル", text: $title)
                        .focused($focusedField, equals: .title)
                    
                    TextField("説明（任意）", text: $description, axis: .vertical)
                        .focused($focusedField, equals: .description)
                        .lineLimit(3...6)
                }
                
                // 候補日時セクション
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
                
                // 詳細情報セクション
                Section(header: Text("詳細情報")) {
                    TextField("場所（任意）", text: $location)
                        .focused($focusedField, equals: .location)
                    
                    TextField("予算（任意）", text: $budget)
                        .focused($focusedField, equals: .budget)
                        .keyboardType(.numberPad)
                }
                
                // 期限設定セクション
                Section(header: Text("回答期限")) {
                    Toggle("回答期限を設定", isOn: $hasDeadline)
                    
                    if hasDeadline {
                        DatePicker("期限", selection: Binding(
                            get: { deadline ?? Date() },
                            set: { deadline = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                    }
                }
                
                // プレビューセクション
                if !title.isEmpty {
                    Section(header: Text("プレビュー")) {
                        EventPreviewCard(
                            title: title,
                            description: description.isEmpty ? nil : description,
                            candidateDates: candidateDates,
                            location: location.isEmpty ? nil : location,
                            budget: budget.isEmpty ? nil : Int(budget),
                            deadline: deadline,
                            viewModel: viewModel
                        )
                    }
                }
            }
            .navigationTitle("スケジュール調整作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("作成") {
                        createEvent()
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
            .sheet(isPresented: $showingUrlSheet) {
                if let event = createdEvent {
                    EventUrlSheet(event: event, viewModel: viewModel) {
                        showingUrlSheet = false
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func createEvent() {
        print("🍕 createEvent() 開始")
        let budgetInt = budget.isEmpty ? nil : Int(budget)
        let finalDeadline = hasDeadline ? deadline : nil
        print("🍕 Supabase保存開始 - タイトル: \(title)")
        Task {
            do {
                let event = try await viewModel.createEventInSupabase(
                    title: title,
                    description: description.isEmpty ? nil : description,
                    candidateDates: candidateDates,
                    location: location.isEmpty ? nil : location,
                    budget: budgetInt,
                    deadline: finalDeadline
                )
                print("🍕 Supabase保存成功!")
                await MainActor.run {
                    createdEvent = event
                    showingUrlSheet = true
                    onEventCreated?(event)
                }
            } catch {
                print("🍕🍕🍕 Supabase作成エラー: \(error)")
                print("🍕🍕🍕 エラー詳細: \(error.localizedDescription)")
                // 必要に応じてエラーハンドリング
            }
        }
    }
}

// MARK: - 日時選択シート

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    let onAdd: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("候補日時を選択")
                    .font(.headline)
                    .padding(.top)
                
                DatePicker("日時", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                
                HStack(spacing: 16) {
                    Button("キャンセル", action: onCancel)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    
                    Button("追加", action: onAdd)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - イベントプレビューカード

struct EventPreviewCard: View {
    let title: String
    let description: String?
    let candidateDates: [Date]
    let location: String?
    let budget: Int?
    let deadline: Date?
    @ObservedObject var viewModel: ScheduleManagementViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // タイトル
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            // 説明
            if let description = description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 候補日時
            VStack(alignment: .leading, spacing: 8) {
                Text("候補日時（\(candidateDates.count)件）")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ForEach(candidateDates.sorted(), id: \.self) { date in
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        Text(viewModel.formatDateTime(date))
                            .font(.subheadline)
                    }
                }
            }
            
            // 基本情報
            VStack(alignment: .leading, spacing: 8) {
                if let location = location {
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.green)
                            .frame(width: 20)
                        Text(location)
                            .font(.subheadline)
                    }
                }
                
                if let budget = budget {
                    HStack {
                        Image(systemName: "yensign.circle")
                            .foregroundColor(.orange)
                            .frame(width: 20)
                        Text("予算: ¥\(viewModel.formatAmount(String(budget)))")
                            .font(.subheadline)
                    }
                }
                
                if let deadline = deadline {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.red)
                            .frame(width: 20)
                        Text("回答期限: \(viewModel.formatDateTime(deadline))")
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - プレビュー

#Preview {
    CreateScheduleEventView(viewModel: ScheduleManagementViewModel())
} 