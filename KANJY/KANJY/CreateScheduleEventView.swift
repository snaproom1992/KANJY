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
                Section(header: Text("基本情報").font(DesignSystem.Typography.headline)) {
                    TextField("スケジュール調整タイトル", text: $title)
                        .standardTextFieldStyle()
                        .focused($focusedField, equals: .title)
                        .submitLabel(.done)
                    
                    TextField("説明（任意）", text: $description, axis: .vertical)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.black)
                        .padding(DesignSystem.TextField.Padding.horizontal)
                        .frame(minHeight: DesignSystem.TextField.Height.medium)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                                .fill(focusedField == .description ? DesignSystem.TextField.focusedBackgroundColor : DesignSystem.TextField.backgroundColor)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                                .stroke(focusedField == .description ? DesignSystem.TextField.focusedBorderColor : DesignSystem.TextField.borderColor, lineWidth: DesignSystem.TextField.borderWidth)
                        )
                        .focused($focusedField, equals: .description)
                        .lineLimit(3...6)
                }
                
                // 候補日時セクション
                Section(header: Text("候補日時").font(DesignSystem.Typography.headline)) {
                    if candidateDates.isEmpty {
                        Text("候補日時が設定されていません")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondary)
                            .italic()
                    } else {
                        ForEach(candidateDates.sorted(), id: \.self) { date in
                            HStack {
                                Text(viewModel.formatDateTime(date))
                                    .font(DesignSystem.Typography.subheadline)
                                    .foregroundColor(DesignSystem.Colors.black)
                                
                                Spacer()
                                
                                Button(action: {
                                    candidateDates.removeAll { $0 == date }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(DesignSystem.Colors.alert)
                                }
                            }
                        }
                    }
                    
                    Button(action: {
                        selectedDate = Date()
                        showingDatePicker = true
                    }) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(DesignSystem.Colors.primary)
                            Text("候補日時を追加")
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.primary)
                        }
                    }
                }
                
                // 詳細情報セクション
                Section(header: Text("詳細情報").font(DesignSystem.Typography.headline)) {
                    TextField("場所（任意）", text: $location)
                        .standardTextFieldStyle()
                        .focused($focusedField, equals: .location)
                        .submitLabel(.done)
                    
                    TextField("予算（任意）", text: $budget)
                        .standardTextFieldStyle()
                        .focused($focusedField, equals: .budget)
                        .keyboardType(.numberPad)
                }
                
                // 期限設定セクション
                Section(header: Text("回答期限").font(DesignSystem.Typography.headline)) {
                    Toggle("回答期限を設定", isOn: $hasDeadline)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.black)
                    
                    if hasDeadline {
                        DatePicker("期限", selection: Binding(
                            get: { deadline ?? Date() },
                            set: { deadline = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.black)
                    }
                }
                
                // プレビューセクション
                if !title.isEmpty {
                    Section(header: Text("プレビュー").font(DesignSystem.Typography.headline)) {
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
    @Binding var hasTime: Bool
    var isEditing: Bool = false
    let onAdd: () -> Void
    let onCancel: () -> Void
    
    init(selectedDate: Binding<Date>, hasTime: Binding<Bool> = .constant(true), isEditing: Bool = false, onAdd: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self._selectedDate = selectedDate
        self._hasTime = hasTime
        self.isEditing = isEditing
        self.onAdd = onAdd
        self.onCancel = onCancel
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.xl) {
                Text(isEditing ? "候補日時を編集" : "候補日時を選択")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.black)
                    .padding(.top)
                
                if hasTime {
                    // 時間ありの場合はカレンダーと時間選択を分けて表示
                    DatePicker("日付", selection: $selectedDate, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                    
                    DatePicker("時間", selection: $selectedDate, displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                        .frame(height: 120)
                } else {
                    // 時間なしの場合はカレンダーのみ
                    DatePicker("日付", selection: $selectedDate, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                }
                
                Toggle("時間を設定", isOn: $hasTime)
                    .font(DesignSystem.Typography.body)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                
                HStack(spacing: DesignSystem.Spacing.lg) {
                    Button("キャンセル", action: onCancel)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.white)
                        .padding(DesignSystem.Button.Padding.vertical)
                        .frame(maxWidth: .infinity)
                        .background(DesignSystem.Colors.gray4)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous))
                    
                    Button(isEditing ? "更新" : "追加", action: onAdd)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.white)
                        .padding(DesignSystem.Button.Padding.vertical)
                        .frame(maxWidth: .infinity)
                        .background(DesignSystem.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous))
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
        .presentationDetents([.large])
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
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // タイトル
            Text(title)
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.black)
            
            // 説明
            if let description = description {
                Text(description)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondary)
            }
            
            // 候補日時
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("候補日時（\(candidateDates.count)件）")
                    .font(DesignSystem.Typography.emphasizedSubheadline)
                    .foregroundColor(DesignSystem.Colors.black)
                
                ForEach(candidateDates.sorted(), id: \.self) { date in
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "calendar")
                            .foregroundColor(DesignSystem.Colors.primary)
                            .frame(width: DesignSystem.Icon.Size.medium)
                        Text(viewModel.formatDateTime(date))
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(DesignSystem.Colors.black)
                    }
                }
            }
            
            // 基本情報
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                if let location = location {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "location")
                            .foregroundColor(DesignSystem.Colors.success)
                            .frame(width: DesignSystem.Icon.Size.medium)
                        Text(location)
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(DesignSystem.Colors.black)
                    }
                }
                
                if let budget = budget {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "yensign.circle")
                            .foregroundColor(DesignSystem.Colors.warning)
                            .frame(width: DesignSystem.Icon.Size.medium)
                        Text("予算: ¥\(viewModel.formatAmount(String(budget)))")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(DesignSystem.Colors.black)
                    }
                }
                
                if let deadline = deadline {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "clock")
                            .foregroundColor(DesignSystem.Colors.alert)
                            .frame(width: DesignSystem.Icon.Size.medium)
                        Text("回答期限: \(viewModel.formatDateTime(deadline))")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(DesignSystem.Colors.black)
                    }
                }
            }
        }
        .padding(DesignSystem.Card.Padding.medium)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Card.cornerRadiusSmall, style: .continuous)
                .fill(DesignSystem.Colors.gray1)
        )
    }
}

// MARK: - プレビュー

#Preview {
    CreateScheduleEventView(viewModel: ScheduleManagementViewModel())
} 