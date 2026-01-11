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
    @State private var selectedEmoji: String = ""
    @State private var selectedIcon: String? = nil
    @State private var selectedIconColor: String? = nil
    @State private var showColorPicker = false
    @State private var showIconPicker = false
    
    // Step 2: 候補日時
    @State private var candidateDates: [Date] = []
    @State private var candidateDatesWithTime: [Date: Bool] = [:] // 時間指定の有無
    @State private var selectedDate = QuickCreatePlanView.getDefaultDate()
    @State private var selectedDateHasTime = true
    @State private var showDateInput = false
    @State private var newlyAddedDateIndex: Int? = nil // 新しく追加された行を追跡
    @State private var isMovingForward: Bool = true // ステップの進行方向を追跡
    
    // デフォルト日付を取得（次の金曜日19:00）
    private static func getDefaultDate() -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.weekday = 6 // 金曜日
        components.hour = 19
        components.minute = 0
        
        if let nextFriday = calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) {
            return nextFriday
        }
        return Date()
    }
    
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
            case .details: return "その他"
            case .completed: return "完了"
            }
        }
        
        var icon: String {
            switch self {
            case .name: return "text.cursor"
            case .dates: return "calendar"
            case .details: return "ellipsis.circle"
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
                            Group {
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
                            .transition(.asymmetric(
                                insertion: .move(edge: isMovingForward ? .trailing : .leading),
                                removal: .move(edge: isMovingForward ? .leading : .trailing)
                            ))
                            .id(currentStep)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.top, DesignSystem.Spacing.xl)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle(currentStep == .completed ? "" : "飲み会を作成")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
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
            .sheet(isPresented: $showIconPicker) {
                IconPickerSheet()
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
            
            // 飲み会名入力（絵文字ボタン統合）
            VStack(spacing: DesignSystem.Spacing.md) {
                Text("飲み会名 *")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 12) {
                    // 絵文字/アイコンボタン
                    Button(action: {
                        showIconPicker = true
                    }) {
                        ZStack {
                            if let iconName = selectedIcon {
                                Image(systemName: iconName)
                                    .font(.system(size: 24))
                                    .foregroundColor(
                                        colorFromString(selectedIconColor) ?? DesignSystem.Colors.primary
                                    )
                            } else if !selectedEmoji.isEmpty {
                                Text(selectedEmoji)
                                    .font(.system(size: 28))
                            } else {
                                Image(systemName: "face.smiling")
                                    .font(.system(size: 24))
                                    .foregroundColor(DesignSystem.Colors.secondary)
                            }
                        }
                        .frame(width: 48, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(DesignSystem.Colors.secondaryBackground)
                        )
                    }
                    
                    // テキストフィールド
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
            }
            
            Spacer()
            
            // 次へボタン
            Button(action: {
                isMovingForward = true
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
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
            
            // 候補日時セクション（シンプル・直接編集）
            VStack(spacing: DesignSystem.Spacing.md) {
                // ヘッダー（タイトル + 時間指定トグル）
                HStack {
                    Text("候補日時")
                        .font(DesignSystem.Typography.emphasizedSubheadline)
                    Spacer()
                    Toggle(isOn: $selectedDateHasTime) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                            Text("時間を指定")
                                .font(DesignSystem.Typography.caption)
                        }
                        .foregroundColor(DesignSystem.Colors.secondary)
                    }
                    .tint(DesignSystem.Colors.primary)
                    .fixedSize()
                }
                
                // 候補日リスト（各項目がDatePicker）
                if !candidateDates.isEmpty {
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(candidateDates.indices, id: \.self) { index in
                            HStack(spacing: DesignSystem.Spacing.md) {
                                // 日付と曜日を含む表示
                                VStack(alignment: .leading, spacing: 4) {
                                    // DatePicker（直接編集可能）
                                    DatePicker("", selection: Binding(
                                        get: { candidateDates[index] },
                                        set: { candidateDates[index] = $0 }
                                    ), displayedComponents: selectedDateHasTime ? [.date, .hourAndMinute] : [.date])
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                        .environment(\.locale, Locale(identifier: "ja_JP"))
                                        .accentColor(DesignSystem.Colors.primary)
                                    
                                    // 曜日表示
                                    Text(formatWeekday(candidateDates[index]))
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // 削除ボタン（右揃え）
                                Button(action: {
                                    withAnimation(.spring(.bouncy(duration: 0.3))) {
                                        let dateToRemove = candidateDates[index]
                                        candidateDates.remove(at: index)
                                        candidateDatesWithTime.removeValue(forKey: dateToRemove)
                                        // 削除した行がハイライト中だった場合、ハイライトをクリア
                                        if newlyAddedDateIndex == index {
                                            newlyAddedDateIndex = nil
                                        } else if let highlighted = newlyAddedDateIndex, highlighted > index {
                                            newlyAddedDateIndex = highlighted - 1
                                        }
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(DesignSystem.Colors.gray3)
                                }
                            }
                            .padding(DesignSystem.Spacing.md)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(newlyAddedDateIndex == index ? 
                                          DesignSystem.Colors.primary.opacity(0.2) : 
                                          DesignSystem.Colors.secondaryBackground)
                            )
                            .scaleEffect(newlyAddedDateIndex == index ? 1.03 : 1.0)
                            .transition(.scale.combined(with: .opacity))
                            .animation(.spring(.bouncy(duration: 0.4)), value: newlyAddedDateIndex)
                        }
                    }
                }
                
                // 追加ボタン
                Button(action: {
                    // 最後の候補日の1週間後、または次の金曜日をデフォルト値として新しい行を追加
                    let newDate: Date
                    if let lastDate = candidateDates.last {
                        newDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: lastDate) ?? Date()
                    } else {
                        newDate = selectedDate
                    }
                    
                    withAnimation(.spring(.bouncy(duration: 0.4))) {
                        candidateDates.append(newDate)
                        candidateDatesWithTime[newDate] = selectedDateHasTime
                        newlyAddedDateIndex = candidateDates.count - 1
                    }
                    
                    // 触覚フィードバック
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    // ハイライトを1秒後に解除（キレのある動き）
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.spring(.snappy)) {
                            newlyAddedDateIndex = nil
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("候補日を追加")
                    }
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(DesignSystem.Colors.primary, lineWidth: 1.5)
                    )
                }
            }
            
            Spacer()
            
            // ナビゲーションボタン
            HStack(spacing: DesignSystem.Spacing.md) {
                Button(action: {
                    isMovingForward = false
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
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
                    isMovingForward = true
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
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
                
                Text("その他")
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
                    Label("場所（任意）", systemImage: "mappin.circle")
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
                    Label("説明（任意）", systemImage: "text.alignleft")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondary)
                    
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                            .fill(DesignSystem.Colors.secondaryBackground)
                        
                        TextEditor(text: $description)
                            .font(DesignSystem.Typography.body)
                            .scrollContentBackground(.hidden)
                            .padding(4)
                            .background(Color.clear)
                        
                        if description.isEmpty {
                            Text("例：予算は3000〜5000円くらいです")
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(Color(UIColor.placeholderText))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(height: 100)
                }
                
                // 回答期限
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Toggle(isOn: $hasDeadline) {
                        Label("回答期限を設定（任意）", systemImage: "clock")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondary)
                    }
                    .tint(DesignSystem.Colors.primary)
                    
                    if hasDeadline {
                        HStack {
                            Spacer()
                            DatePicker("期限", selection: $deadline, displayedComponents: [.date])
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .environment(\.locale, Locale(identifier: "ja_JP"))
                                .accentColor(DesignSystem.Colors.primary)
                            Spacer()
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.TextField.cornerRadius, style: .continuous)
                                .fill(DesignSystem.Colors.secondaryBackground)
                        )
                    }
                }
            }
            
            Spacer()
            
            // ナビゲーションボタン
            HStack(spacing: DesignSystem.Spacing.md) {
                Button(action: {
                    isMovingForward = false
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
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
            
            // 成功アイコン（アニメーション付き）
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(DesignSystem.Colors.success)
                .scaleEffect(1.0)
                .onAppear {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                        // アニメーション効果
                    }
                }
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("作成完了！")
                    .font(DesignSystem.Typography.largeTitle)
                    .fontWeight(.bold)
                
                Text("このURLを参加者と共有しましょう")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // URL表示（モダンなデザイン）
            if let event = createdEvent {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // URLカード
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Text("スケジュール調整URL")
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.black)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text(scheduleViewModel.getWebUrl(for: event))
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.primary)
                            .padding(DesignSystem.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(DesignSystem.Colors.primary.opacity(0.1))
                            )
                            .lineLimit(3)
                    }
                    
                    // ボタン（共有を強調）
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Button(action: {
                            hapticImpact(.medium)
                            shareUrl(scheduleViewModel.getShareUrl(for: event))
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("共有")
                            }
                            .font(DesignSystem.Typography.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [
                                        DesignSystem.Colors.primary,
                                        DesignSystem.Colors.primary.opacity(0.85)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(
                                color: DesignSystem.Colors.primary.opacity(0.3),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                        }
                        
                        Button(action: {
                            hapticImpact(.light)
                            UIPasteboard.general.string = scheduleViewModel.getWebUrl(for: event)
                            // TODO: コピー完了のトースト表示
                        }) {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("コピー")
                            }
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(DesignSystem.Colors.primary, lineWidth: 1.5)
                            )
                        }
                    }
                }
                .padding(DesignSystem.Spacing.xl)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(DesignSystem.Colors.white)
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
                hapticImpact(.medium)
                dismiss()
            }) {
                Text("ホームに戻る")
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
    
    // ハプティックフィードバック
    private func hapticImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
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
    
    private func formatWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "EEEE"  // 曜日（例：金曜日）
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
                    viewModel.selectedIcon = selectedIcon
                    viewModel.selectedIconColor = selectedIconColor
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
                    
                    isMovingForward = true
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
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
    
    // MARK: - Icon & Color Helper Functions
    
    private func colorFromString(_ colorString: String?) -> Color? {
        guard let colorString = colorString, !colorString.isEmpty else { return nil }
        let components = colorString.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard components.count == 3 else { return nil }
        return Color(red: components[0], green: components[1], blue: components[2])
    }
    
    private let availableIcons: [(name: String, label: String)] = [
        ("wineglass.fill", "ワイン"),
        ("cup.and.saucer.fill", "ビール"),
        ("drop.fill", "カクテル"),
        ("heart.fill", "乾杯"),
        ("fork.knife", "食事"),
        ("building.2.fill", "レストラン"),
        ("takeoutbag.and.cup.and.straw.fill", "テイクアウト"),
        ("party.popper.fill", "パーティー"),
        ("sparkles", "お祝い"),
        ("star.fill", "特別"),
        ("person.3.fill", "会議"),
        ("rectangle.3.group.fill", "グループ"),
        ("briefcase.fill", "ビジネス")
    ]
    
    // MARK: - Icon Picker Sheet
    
    @ViewBuilder
    private func IconPickerSheet() -> some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        // 絵文字セクション
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("絵文字")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(DesignSystem.Colors.secondary)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                                ForEach(["🍻", "🍺", "🥂", "🍷", "🍸", "🍹", "🍾", "🥃", "🍴", "🍖", "🍗", "🍣", "🍕", "🍔", "🥩", "🍙", "🤮", "🤢", "🥴", "😵", "😵‍💫", "💸", "🎊"], id: \.self) { emoji in
                                    Button(action: {
                                        selectedEmoji = emoji
                                        selectedIcon = nil
                                        showIconPicker = false
                                    }) {
                                        Text(emoji)
                                            .font(.system(size: 32))
                                            .frame(width: 50, height: 50)
                                            .background(
                                                Circle()
                                                    .fill(selectedEmoji == emoji && selectedIcon == nil ? DesignSystem.Colors.primary.opacity(0.2) : Color.gray.opacity(0.1))
                                            )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        
                        Divider()
                        
                        // 現在選択されている色を1つだけ表示（補助的な機能）
                        if selectedIcon != nil {
                            HStack {
                                Text("色")
                                    .font(DesignSystem.Typography.subheadline)
                                    .foregroundColor(DesignSystem.Colors.secondary)
                                
                                Spacer()
                                
                                Button(action: {
                                    withAnimation(.spring(.snappy)) {
                                        showColorPicker.toggle()
                                    }
                                }) {
                                    Circle()
                                        .fill(
                                            colorFromString(selectedIconColor) ?? DesignSystem.Colors.primary
                                        )
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        // アイコンセクション
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("アイコン")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(DesignSystem.Colors.secondary)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                                ForEach(availableIcons, id: \.name) { icon in
                                    Button(action: {
                                        selectedIcon = icon.name
                                        selectedEmoji = ""
                                        if selectedIconColor == nil {
                                            selectedIconColor = "0.067,0.094,0.157"
                                        }
                                        showIconPicker = false
                                    }) {
                                        Image(systemName: icon.name)
                                            .font(.system(size: 24))
                                            .foregroundColor(
                                                selectedIcon == icon.name ?
                                                    (colorFromString(selectedIconColor) ?? DesignSystem.Colors.primary) :
                                                    DesignSystem.Colors.black
                                            )
                                            .frame(width: 50, height: 50)
                                            .background(
                                                Circle()
                                                    .fill(selectedIcon == icon.name ? DesignSystem.Colors.primary.opacity(0.2) : Color.gray.opacity(0.1))
                                            )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
                
                // カラーピッカーポップオーバー
                if showColorPicker {
                    Color.black.opacity(0.001)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(.snappy)) {
                                showColorPicker = false
                            }
                        }
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Spacer()
                            ColorPickerPopover()
                                .scaleEffect(showColorPicker ? 1.0 : 0.001, anchor: .bottomTrailing)
                                .opacity(showColorPicker ? 1.0 : 0.0)
                                .padding(.trailing, 24)
                        }
                        .padding(.top, 140)
                        Spacer()
                    }
                }
            }
            .navigationTitle("アイコンを選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        showIconPicker = false
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Color Picker Popover
    
    @ViewBuilder
    private func ColorPickerPopover() -> some View {
        VStack(spacing: 12) {
            // ヘッダー（バツボタン）
            HStack {
                Spacer()
                Button(action: {
                    withAnimation(.spring(.snappy)) {
                        showColorPicker = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(DesignSystem.Colors.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, DesignSystem.Spacing.xs)
            .padding(.horizontal, DesignSystem.Spacing.xs)
            
            // プレビューアイコン（現在選択されているアイコンがある場合）
            if let iconName = selectedIcon {
                Image(systemName: iconName)
                    .font(.system(size: 40))
                    .foregroundColor(
                        colorFromString(selectedIconColor) ?? DesignSystem.Colors.primary
                    )
            }
            
            // 色選択セクション
            ColorPickerSection()
        }
        .padding(DesignSystem.Spacing.md)
        .frame(width: 280)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    @ViewBuilder
    private func ColorPickerSection() -> some View {
        let colors: [(String, Color)] = [
            ("0.067,0.094,0.157", DesignSystem.Colors.primary), // プライマリ
            ("0.937,0.267,0.267", Color(red: 0.937, green: 0.267, blue: 0.267)), // 赤
            ("0.976,0.451,0.086", DesignSystem.Colors.orangeAccent), // オレンジ
            ("0.063,0.725,0.506", Color(red: 0.063, green: 0.725, blue: 0.506)), // 緑
            ("0.259,0.522,0.957", Color(red: 0.259, green: 0.522, blue: 0.957)), // 青
            ("0.647,0.318,0.580", Color(red: 0.647, green: 0.318, blue: 0.580)), // 紫
            ("0.5,0.5,0.5", Color.gray), // グレー
            ("0.0,0.0,0.0", Color.black), // 黒
        ]
        
        VStack(spacing: 16) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
                ForEach(colors, id: \.0) { colorData in
                    Button(action: {
                        selectedIconColor = colorData.0
                        // 色選択時はメニューを閉じない
                    }) {
                        ZStack {
                            Circle()
                                .fill(colorData.1)
                                .frame(width: 36, height: 36)
                            
                            // 選択状態の表示
                            if selectedIconColor == colorData.0 {
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                                    .frame(width: 36, height: 36)
                                Circle()
                                    .stroke(colorData.1, lineWidth: 2)
                                    .frame(width: 40, height: 40)
                            } else {
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    .frame(width: 36, height: 36)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}


