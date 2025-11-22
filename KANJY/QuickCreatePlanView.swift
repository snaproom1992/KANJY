import SwiftUI

// 新規飲み会作成の簡単モード（3ステップ）
struct QuickCreatePlanView: View {
    @ObservedObject var viewModel: PrePlanViewModel
    @StateObject private var scheduleViewModel = ScheduleManagementViewModel()
    @Environment(\.dismiss) var dismiss
    
    // ステップ管理
    @State private var currentStep: CreateStep = .name
    
    // Step 1: 飲み会名
    @State private var planName: String = ""
    @State private var selectedEmoji: String = "🍻"
    
    // Step 2: 候補日時
    @State private var candidateDates: [Date] = []
    @State private var candidateDatesWithTime: [Date: Bool] = [:] // 時間指定の有無
    @State private var showingDatePicker = false
    @State private var selectedDate = Date()
    @State private var selectedDateHasTime = true
    
    // Step 3: 詳細情報
    @State private var location: String = ""
    @State private var description: String = ""
    @State private var hasDeadline: Bool = false
    @State private var deadline: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    
    // 完了後
    @State private var createdEvent: ScheduleEvent?
    @State private var isCreating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    enum CreateStep: Int, CaseIterable {
        case name = 1
        case dates = 2
        case details = 3
        case completed = 4
        
        var title: String {
            switch self {
            case .name: return "飲み会名"
            case .dates: return "候補日時"
            case .details: return "詳細情報"
            case .completed: return "完了"
            }
        }
        
        var icon: String {
            switch self {
            case .name: return "text.cursor"
            case .dates: return "calendar"
            case .details: return "info.circle"
            case .completed: return "checkmark.circle.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // プログレスインジケーター
                    if currentStep != .completed {
                        progressIndicator
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                            .padding(.vertical, DesignSystem.Spacing.md)
                    }
                    
                    // コンテンツ
                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.xl) {
                            switch currentStep {
                            case .name:
                                step1NameView
                            case .dates:
                                step2DatesView
                            case .details:
                                step3DetailsView
                            case .completed:
                                step4CompletedView
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.top, DesignSystem.Spacing.xl)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle(currentStep == .completed ? "" : "飲み会を作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if currentStep != .completed {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("キャンセル") {
                            dismiss()
                        }
                    }
                }
            }
            .alert("エラー", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerSheet(
                    selectedDate: $selectedDate,
                    hasTime: $selectedDateHasTime,
                    isEditing: false,
                    onAdd: {
                        candidateDates.append(selectedDate)
                        candidateDatesWithTime[selectedDate] = selectedDateHasTime
                        showingDatePicker = false
                    },
                    onCancel: {
                        showingDatePicker = false
                    }
                )
            }
        }
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { step in
                HStack(spacing: 4) {
                    Circle()
                        .fill(step <= currentStep.rawValue ? DesignSystem.Colors.primary : DesignSystem.Colors.gray4)
                        .frame(width: 8, height: 8)
                    
                    if step < 3 {
                        Rectangle()
                            .fill(step < currentStep.rawValue ? DesignSystem.Colors.primary : DesignSystem.Colors.gray4)
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
    
    // MARK: - Step 1: 飲み会名
    
    private var step1NameView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // ヘッダー
            VStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: CreateStep.name.icon)
                    .font(.system(size: 48))
                    .foregroundColor(DesignSystem.Colors.primary)
                
                Text("Step 1/3")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondary)
                
                Text("飲み会の名前を決めましょう")
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, DesignSystem.Spacing.xl)
            
            // 絵文字選択
            VStack(spacing: DesignSystem.Spacing.md) {
                Text("アイコン")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: DesignSystem.Spacing.md) {
                    Text(selectedEmoji)
                        .font(.system(size: 48))
                        .frame(width: 80, height: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(DesignSystem.Colors.secondaryBackground)
                        )
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("タップして変更")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                ForEach(["🍻", "🍺", "🥂", "🍷", "🍸", "🍹", "🎉", "🎊"], id: \.self) { emoji in
                                    Text(emoji)
                                        .font(.system(size: 28))
                                        .frame(width: 44, height: 44)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(selectedEmoji == emoji ? DesignSystem.Colors.primary.opacity(0.2) : Color.clear)
                                        )
                                        .onTapGesture {
                                            selectedEmoji = emoji
                                        }
                                }
                            }
                        }
                    }
                }
            }
            
            // 飲み会名入力
            VStack(spacing: DesignSystem.Spacing.md) {
                Text("飲み会名 *")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                TextField("例：忘年会、新年会、歓迎会...", text: $planName)
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .padding(DesignSystem.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                            .fill(DesignSystem.Colors.secondaryBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                            .stroke(DesignSystem.Colors.gray4, lineWidth: 1)
                    )
            }
            
            Spacer()
            
            // 次へボタン
            Button(action: {
                withAnimation {
                    currentStep = .dates
                }
            }) {
                HStack {
                    Text("次へ")
                        .font(DesignSystem.Typography.headline)
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(planName.isEmpty ? DesignSystem.Colors.gray4 : DesignSystem.Colors.primary)
                )
            }
            .disabled(planName.isEmpty)
        }
    }
    
    // MARK: - Step 2: 候補日時
    
    private var step2DatesView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // ヘッダー
            VStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: CreateStep.dates.icon)
                    .font(.system(size: 48))
                    .foregroundColor(DesignSystem.Colors.primary)
                
                Text("Step 2/3")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondary)
                
                Text("候補日を選びましょう")
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("3つ以上の候補日があると参加者が選びやすくなります")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            .padding(.top, DesignSystem.Spacing.xl)
            
            // おすすめ日程
            if candidateDates.isEmpty {
                VStack(spacing: DesignSystem.Spacing.md) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(DesignSystem.Colors.primary)
                        Text("おすすめの日程")
                            .font(DesignSystem.Typography.emphasizedSubheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(suggestedDates(), id: \.self) { date in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(formatDate(date))
                                        .font(DesignSystem.Typography.body)
                                        .fontWeight(.medium)
                                    Text(formatTime(date))
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(DesignSystem.Colors.primary)
                            }
                            .padding(DesignSystem.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(DesignSystem.Colors.secondaryBackground)
                            )
                            .onTapGesture {
                                candidateDates.append(date)
                                candidateDatesWithTime[date] = true
                            }
                        }
                    }
                    
                    Button(action: {
                        // すべて追加
                        for date in suggestedDates() {
                            candidateDates.append(date)
                            candidateDatesWithTime[date] = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("これらをすべて追加")
                        }
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(DesignSystem.Colors.primary, lineWidth: 1.5)
                        )
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(DesignSystem.Colors.primary.opacity(0.05))
                )
            }
            
            // 追加された候補日
            if !candidateDates.isEmpty {
                VStack(spacing: DesignSystem.Spacing.md) {
                    HStack {
                        Text("候補日時 (\(candidateDates.count)件)")
                            .font(DesignSystem.Typography.emphasizedSubheadline)
                        Spacer()
                    }
                    
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(candidateDates.indices, id: \.self) { index in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(formatDate(candidateDates[index]))
                                        .font(DesignSystem.Typography.body)
                                        .fontWeight(.medium)
                                    Text(formatTime(candidateDates[index]))
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.secondary)
                                }
                                Spacer()
                                Button(action: {
                                    candidateDates.remove(at: index)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(DesignSystem.Colors.gray3)
                                }
                            }
                            .padding(DesignSystem.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(DesignSystem.Colors.secondaryBackground)
                            )
                        }
                    }
                }
            }
            
            // 自分で選ぶボタン
            Button(action: {
                showingDatePicker = true
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text(candidateDates.isEmpty ? "自分で日時を選ぶ" : "候補日を追加")
                }
                .font(DesignSystem.Typography.subheadline)
                .fontWeight(.medium)
                .foregroundColor(DesignSystem.Colors.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DesignSystem.Colors.primary, lineWidth: 1.5)
                )
            }
            
            Spacer()
            
            // ナビゲーションボタン
            HStack(spacing: DesignSystem.Spacing.md) {
                Button(action: {
                    withAnimation {
                        currentStep = .name
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("戻る")
                    }
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(DesignSystem.Colors.primary, lineWidth: 1.5)
                    )
                }
                
                Button(action: {
                    withAnimation {
                        currentStep = .details
                    }
                }) {
                    HStack {
                        Text("次へ")
                        Image(systemName: "arrow.right")
                    }
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(candidateDates.isEmpty ? DesignSystem.Colors.gray4 : DesignSystem.Colors.primary)
                    )
                }
                .disabled(candidateDates.isEmpty)
            }
        }
    }
    
    // MARK: - Step 3: 詳細情報
    
    private var step3DetailsView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // ヘッダー
            VStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: CreateStep.details.icon)
                    .font(.system(size: 48))
                    .foregroundColor(DesignSystem.Colors.primary)
                
                Text("Step 3/3")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondary)
                
                Text("詳細情報（任意）")
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("後から追加・変更できます")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondary)
            }
            .padding(.top, DesignSystem.Spacing.xl)
            
            VStack(spacing: DesignSystem.Spacing.lg) {
                // 場所
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Label("場所", systemImage: "mappin.circle.fill")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondary)
                    
                    TextField("例：新橋の居酒屋", text: $location)
                        .font(DesignSystem.Typography.body)
                        .padding(DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                                .fill(DesignSystem.Colors.secondaryBackground)
                        )
                }
                
                // 説明
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Label("説明", systemImage: "text.alignleft")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondary)
                    
                    TextField("例：予算は3000〜5000円くらいです", text: $description, axis: .vertical)
                        .font(DesignSystem.Typography.body)
                        .padding(DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                                .fill(DesignSystem.Colors.secondaryBackground)
                        )
                        .lineLimit(3...6)
                }
                
                // 回答期限
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Toggle(isOn: $hasDeadline) {
                        Label("回答期限を設定", systemImage: "clock.fill")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondary)
                    }
                    .tint(DesignSystem.Colors.primary)
                    
                    if hasDeadline {
                        DatePicker("期限", selection: $deadline, displayedComponents: [.date])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .padding(DesignSystem.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                                    .fill(DesignSystem.Colors.secondaryBackground)
                            )
                    }
                }
            }
            
            // ヒント
            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(DesignSystem.Colors.primary)
                    .font(.system(size: 16))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("参加者はWeb回答から自動追加されます")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondary)
                    Text("手動で参加者を入力する必要はありません")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondary)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DesignSystem.Colors.primary.opacity(0.05))
            )
            
            Spacer()
            
            // ナビゲーションボタン
            HStack(spacing: DesignSystem.Spacing.md) {
                Button(action: {
                    withAnimation {
                        currentStep = .dates
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("戻る")
                    }
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(DesignSystem.Colors.primary, lineWidth: 1.5)
                    )
                }
                
                Button(action: {
                    createPlan()
                }) {
                    HStack {
                        if isCreating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("作成")
                            Image(systemName: "checkmark")
                        }
                    }
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(DesignSystem.Colors.primary)
                    )
                }
                .disabled(isCreating)
            }
        }
    }
    
    // MARK: - Step 4: 完了
    
    private var step4CompletedView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()
            
            // 成功アイコン
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(DesignSystem.Colors.success)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("作成完了！")
                    .font(DesignSystem.Typography.largeTitle)
                    .fontWeight(.bold)
                
                Text("スケジュール調整URLを\n参加者に配布してください")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // URL表示
            if let event = createdEvent {
                VStack(spacing: DesignSystem.Spacing.md) {
                    Text("スケジュール調整URL")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondary)
                    
                    Text(scheduleViewModel.getWebUrl(for: event))
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.primary)
                        .padding(DesignSystem.Spacing.md)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(DesignSystem.Colors.secondaryBackground)
                        )
                        .lineLimit(3)
                    
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Button(action: {
                            UIPasteboard.general.string = scheduleViewModel.getWebUrl(for: event)
                        }) {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("コピー")
                            }
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(DesignSystem.Colors.primary, lineWidth: 1.5)
                            )
                        }
                        
                        Button(action: {
                            shareUrl(scheduleViewModel.getShareUrl(for: event))
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("共有")
                            }
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(DesignSystem.Colors.primary)
                            )
                        }
                    }
                }
                .padding(DesignSystem.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(DesignSystem.Colors.secondaryBackground)
                        .shadow(
                            color: Color.black.opacity(0.05),
                            radius: 10,
                            x: 0,
                            y: 4
                        )
                )
            }
            
            Spacer()
            
            // 閉じるボタン
            Button(action: {
                dismiss()
            }) {
                Text("完了")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(DesignSystem.Colors.primary)
                    )
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }
    
    // MARK: - Helper Functions
    
    private func suggestedDates() -> [Date] {
        let calendar = Calendar.current
        var dates: [Date] = []
        
        // 次の金曜日 19:00から3週間分
        if let nextFriday = getNextWeekday(.friday, from: Date()) {
            for week in 0..<3 {
                if let date = calendar.date(byAdding: .weekOfYear, value: week, to: nextFriday) {
                    dates.append(date)
                }
            }
        }
        
        return dates
    }
    
    private func getNextWeekday(_ weekday: Weekday, from date: Date) -> Date? {
        let calendar = Calendar.current
        var components = DateComponents()
        components.weekday = weekday.rawValue
        components.hour = 19
        components.minute = 0
        
        // 今日が該当曜日で、かつ19:00より前なら今日を返す
        let today = calendar.component(.weekday, from: date)
        let hour = calendar.component(.hour, from: date)
        
        if today == weekday.rawValue && hour < 19 {
            var todayComponents = calendar.dateComponents([.year, .month, .day], from: date)
            todayComponents.hour = 19
            todayComponents.minute = 0
            return calendar.date(from: todayComponents)
        }
        
        // 次の該当曜日を探す
        return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime)
    }
    
    enum Weekday: Int {
        case sunday = 1
        case monday = 2
        case tuesday = 3
        case wednesday = 4
        case thursday = 5
        case friday = 6
        case saturday = 7
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func createPlan() {
        isCreating = true
        
        Task {
            do {
                // スケジュール調整イベントを作成
                let event = try await scheduleViewModel.createEventInSupabase(
                    title: planName,
                    description: description.isEmpty ? nil : description,
                    candidateDates: candidateDates,
                    location: location.isEmpty ? nil : location,
                    budget: nil, // 予算フィールドを削除
                    deadline: hasDeadline ? deadline : nil
                )
                
                await MainActor.run {
                    createdEvent = event
                    isCreating = false
                    
                    // ViewModelに保存
                    viewModel.selectedEmoji = selectedEmoji
                    viewModel.editingPlanDescription = description
                    viewModel.editingPlanLocation = location
                    
                    // 飲み会を保存（参加者なしで作成）
                    viewModel.savePlan(
                        name: planName,
                        date: candidateDates.first ?? Date(),
                        description: description.isEmpty ? nil : description,
                        location: location.isEmpty ? nil : location
                    )
                    
                    // スケジュールイベントIDを設定
                    if let planId = viewModel.editingPlanId,
                       let idx = viewModel.savedPlans.firstIndex(where: { $0.id == planId }) {
                        viewModel.savedPlans[idx].scheduleEventId = event.id
                        viewModel.saveData()
                    }
                    
                    withAnimation {
                        currentStep = .completed
                    }
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = "作成に失敗しました: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    private func shareUrl(_ url: String) {
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

