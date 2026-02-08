import SwiftUI
import CoreImage.CIFilterBuiltins
import CoreImage.CIFilterBuiltins

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
    @State private var showingCopyToast = false
    @State private var showTicketAnimation = false
    
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
                                    step4CompletedViewNew
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
        .overlay(alignment: .bottom) {
            if showingCopyToast {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                    Text("URLをコピーしました")
                        .font(DesignSystem.Typography.body)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.8))
                .cornerRadius(30)
                .padding(.bottom, 60)
                .transition(.move(edge: .bottom).combined(with: .opacity))
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
                // 選択されたアイコン/絵文字をプレースホルダーに反映
                Group {
                    if let iconName = selectedIcon {
                        Image(systemName: iconName)
                            .foregroundColor(colorFromString(selectedIconColor) ?? DesignSystem.Colors.primary)
                    } else if !selectedEmoji.isEmpty {
                        Text(selectedEmoji)
                    } else {
                        // 未選択の場合はカバアイコン
                        if let appLogo = UIImage(named: "AppLogo") {
                            Image(uiImage: appLogo)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 48, height: 48)
                        } else {
                            Image(systemName: CreateStep.name.icon)
                                .foregroundColor(DesignSystem.Colors.primary)
                        }
                    }
                }
                .font(.system(size: 48))
                
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
            Image(systemName: "envelope.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(DesignSystem.Colors.primary)
                .scaleEffect(1.0)
                .onAppear {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                        // アニメーション効果
                    }
                }
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("インビテーションURLが\n作成されました")
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text("飲み会に招待したい人にインビテーションのURLを共有しましょう。")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.black)
                        .multilineTextAlignment(.center)
                    
                    Text("インビテーションを受け取った人は出席可能な日を回答することができます。")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
            
            // URL表示＆アクション（チケットデザイン）
            if let event = createdEvent {
                ZStack {
                    // チケット背景
                    TicketShape(notchOffset: 0.6)
                        .fill(DesignSystem.Colors.white)
                        .shadow(
                            color: DesignSystem.Colors.primary.opacity(0.15),
                            radius: 15,
                            x: 0,
                            y: 8
                        )
                    
                    VStack(spacing: 0) {
                        // 上部：イベント情報とURL
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(DesignSystem.Colors.primary)
                                Text("INVITATION")
                                    .font(DesignSystem.Typography.subheadline)
                                    .fontWeight(.bold)
                                    .tracking(2)
                                    .foregroundColor(DesignSystem.Colors.primary)
                            }
                            .padding(.top, DesignSystem.Spacing.lg)
                            
                            VStack(spacing: DesignSystem.Spacing.sm) {
                                Text("インビテーションURL")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.secondary)
                                
                                Text(scheduleViewModel.getWebUrl(for: event))
                                    .font(DesignSystem.Typography.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(DesignSystem.Colors.primary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(DesignSystem.Colors.gray1)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(DesignSystem.Spacing.lg)
                        .padding(.bottom, DesignSystem.Spacing.md)
                        
                        // ミシン目
                        HStack {
                            Circle()
                                .fill(Color(.systemGroupedBackground))
                                .frame(width: 20, height: 20)
                                .offset(x: -10)
                            
                            DashedLine()
                                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                .foregroundColor(DesignSystem.Colors.gray3)
                                .frame(height: 1)
                            
                            Circle()
                                .fill(Color(.systemGroupedBackground))
                                .frame(width: 20, height: 20)
                                .offset(x: 10)
                        }
                        
                        // 下部：アクションボタン
                        VStack(spacing: DesignSystem.Spacing.md) {
                            // シェアボタン（Primary）
                            Button(action: {
                                hapticImpact(.medium)
                                shareUrl(scheduleViewModel.getShareUrl(for: event))
                            }) {
                                Label("招待状を送る", systemImage: "square.and.arrow.up")
                                    .font(DesignSystem.Typography.body.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .primaryButtonStyle()
                            .controlSize(DesignSystem.Button.Control.large)
                            
                            // コピーボタン（Secondary）
                            Button(action: {
                                hapticImpact(.light)
                                UIPasteboard.general.string = scheduleViewModel.getWebUrl(for: event)
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                                withAnimation {
                                    showingCopyToast = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation {
                                        showingCopyToast = false
                                    }
                                }
                            }) {
                                Label("URLをコピー", systemImage: "doc.on.doc")
                                    .font(DesignSystem.Typography.body)
                                    .frame(maxWidth: .infinity)
                            }
                            .secondaryButtonStyle()
                            .controlSize(DesignSystem.Button.Control.large)
                            .tint(DesignSystem.Colors.primary)
                        }
                        .padding(DesignSystem.Spacing.lg)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                // アニメーション設定
                .offset(y: showTicketAnimation ? 0 : 200)
                .opacity(showTicketAnimation ? 1 : 0)
                .rotation3DEffect(
                    .degrees(showTicketAnimation ? 0 : 10),
                    axis: (x: 1, y: 0, z: 0)
                )
            }
            Spacer()
            
            // ホームに戻る（Tertiary）
            Button(action: {
                hapticImpact(.medium)
                dismiss()
            }) {
                Text("ホームに戻る")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .padding(.vertical, DesignSystem.Spacing.md)
            }
            .padding(.bottom, DesignSystem.Spacing.lg)
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
                    
                    // ViewModelに保存（空の場合は自動でカバを割り当て）
                    viewModel.selectedEmoji = selectedEmoji.isEmpty ? "KANJY_HIPPO" : selectedEmoji
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
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(50), spacing: 12, alignment: .leading), count: 6), alignment: .leading, spacing: 12) {
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
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        
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
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                        }
                        
                        // アイコンセクション
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("アイコン")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(DesignSystem.Colors.secondary)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(50), spacing: 12, alignment: .leading), count: 6), alignment: .leading, spacing: 12) {
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
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        
                        Divider()
                        
                        // その他部（アプリアイコン）
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("その他")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(DesignSystem.Colors.secondary)
                            
                            HStack(spacing: 12) {
                                Button(action: {
                                    selectedEmoji = "KANJY_HIPPO"
                                    selectedIcon = nil
                                    showIconPicker = false
                                }) {
                                    Group {
                                        if let appLogo = UIImage(named: "AppLogo") {
                                            Image(uiImage: appLogo)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 32, height: 32)
                                                .cornerRadius(4)
                                        } else {
                                            Image(systemName: "face.smiling")
                                                .font(.system(size: 24))
                                        }
                                    }
                                    .frame(width: 50, height: 50)
                                    .background(
                                        Circle()
                                            .fill(selectedEmoji == "KANJY_HIPPO" && selectedIcon == nil ? DesignSystem.Colors.primary.opacity(0.2) : Color.gray.opacity(0.1))
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(selectedEmoji == "KANJY_HIPPO" && selectedIcon == nil ? DesignSystem.Colors.primary : Color.clear, lineWidth: 2)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Spacer()
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    }
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
    // MARK: - New Ticket UI Completion View
    
    private var step4CompletedViewNew: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()
            
            // 成功アイコン（アニメーション付き）
            Image(systemName: "envelope.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(DesignSystem.Colors.primary)
                .scaleEffect(1.0)
                .onAppear {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                        // アニメーション効果が必要な場合はここに記述
                    }
                }
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("インビテーションURLが\n作成されました")
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text("飲み会に招待したい人にインビテーションのURLを共有しましょう。")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.black)
                        .multilineTextAlignment(.center)
                    
                    Text("インビテーションを受け取った人は出席可能な日を回答することができます。")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
            
            // URL表示＆アクション（チケットデザイン V3）
            if let event = createdEvent {
                VStack(spacing: 0) {
                    // 上部：ヘッダーエリア（ブランドカラー）
                    ZStack {
                        Rectangle()
                            .fill(DesignSystem.Colors.primary)
                            .frame(height: 70)
                        
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                            Text("INVITATION")
                                .font(.system(.headline, design: .serif))
                                .fontWeight(.bold)
                                .tracking(4)
                                .foregroundColor(.white)
                        }
                        .padding(.top, 4)
                    }
                    // TicketShapeの上部角丸に合わせてクリッピング
                    .mask(
                        TicketTopShape(cornerRadius: 16)
                    )
                    
                    // イベント情報（Reference Style Refined）
                    VStack(alignment: .leading, spacing: 16) {
                        
                        // 1. ヘッダー: ロゴ & タイトル & 候補日カプセル
                        VStack(alignment: .leading, spacing: 12) {
                            // ロゴアイコン (左上)
                            // ロゴアイコン (ユーザー選択の絵文字/アイコン)
                            ZStack {
                                if let iconName = selectedIcon {
                                    Image(systemName: iconName)
                                        .font(.system(size: 28))
                                        .foregroundColor(
                                            colorFromString(selectedIconColor) ?? DesignSystem.Colors.primary
                                        )
                                } else if !selectedEmoji.isEmpty {
                                    Text(selectedEmoji)
                                        .font(.system(size: 32))
                                } else {
                                    // Fallback Icon
                                    // Fallback Icon (AppLogo)
                                    if let appLogo = UIImage(named: "AppLogo") {
                                        Image(uiImage: appLogo)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 44, height: 44)
                                            .cornerRadius(8)
                                    } else {
                                        // Image fails to load fallback
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(DesignSystem.Colors.primary)
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Image(systemName: "wineglass.fill")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.white)
                                            )
                                    }
                                }
                            }
                            .frame(width: 44, height: 44)
                            
                            // タイトル
                            // タイトル (Gothic)
                            Text(event.title)
                                .font(.system(size: 32, weight: .heavy, design: .default))
                                .foregroundColor(DesignSystem.Colors.black)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            // 候補日カプセル (FlowLayoutで折り返し)
                            FlowLayout(spacing: 8) {
                                ForEach(event.candidateDates.prefix(6), id: \.self) { date in
                                    Text(formatDateForTicket(date))
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(DesignSystem.Colors.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .strokeBorder(DesignSystem.Colors.primary.opacity(0.3), lineWidth: 1)
                                        )
                                }
                                if event.candidateDates.count > 6 {
                                    Text("+\(event.candidateDates.count - 6)")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(DesignSystem.Colors.primary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .strokeBorder(DesignSystem.Colors.primary.opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        
                        Divider()
                            .background(DesignSystem.Colors.gray3)
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                            .padding(.vertical, 4)
                        
                        // 2. 詳細情報 & QRコード (2カラム)
                        HStack(alignment: .top, spacing: 16) {
                            // 左カラム: 詳細情報
                            VStack(alignment: .leading, spacing: 16) {
                                // LOCATION
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("LOCATION")
                                        .font(.system(size: 9, weight: .bold))
                                        .tracking(1.5)
                                        .foregroundColor(DesignSystem.Colors.gray6)
                                    
                                    if let location = event.location, !location.isEmpty {
                                        Text(location)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(DesignSystem.Colors.black)
                                            .fixedSize(horizontal: false, vertical: true)
                                    } else {
                                        Text("場所未定")
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundColor(DesignSystem.Colors.gray4)
                                            .italic()
                                    }
                                }
                                
                                // MEMO
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("MEMO")
                                        .font(.system(size: 9, weight: .bold))
                                        .tracking(1.5)
                                        .foregroundColor(DesignSystem.Colors.gray6)
                                    
                                    if let description = event.description, !description.isEmpty {
                                        Text(description)
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundColor(DesignSystem.Colors.gray6)
                                            .lineLimit(3)
                                            .fixedSize(horizontal: false, vertical: true)
                                    } else {
                                        Text("メモなし")
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundColor(DesignSystem.Colors.gray4)
                                            .italic()
                                    }
                                }
                                
                                // DEADLINE
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("DEADLINE")
                                        .font(.system(size: 9, weight: .bold))
                                        .tracking(1.5)
                                        .foregroundColor(DesignSystem.Colors.gray6)
                                    
                                    if let deadline = event.deadline {
                                        Text(formatDateForTicket(deadline))
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundColor(DesignSystem.Colors.Attendance.notAttending)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule()
                                                    .fill(DesignSystem.Colors.Attendance.notAttending.opacity(0.1))
                                            )
                                    } else {
                                        Text("回答期限なし")
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundColor(DesignSystem.Colors.gray4)
                                            .italic()
                                    }
                                }
                                .padding(.bottom, 8) // 余白追加
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                             // 右カラム: QRコード (小さく配置)
                             VStack(alignment: .center, spacing: 4) {
                                 Spacer() // 上下中央揃え用
                                 Image(uiImage: generateQRCode(from: scheduleViewModel.getWebUrl(for: event)))
                                     .interpolation(.none)
                                     .resizable()
                                     .scaledToFit()
                                     .frame(width: 100, height: 100) // サイズ拡大
                                     .background(Color.white)
                                     .cornerRadius(8)
                                 
                                 Text("SCAN")
                                     .font(.system(size: 8, weight: .bold))
                                     .tracking(1)
                                     .foregroundColor(DesignSystem.Colors.secondary)
                                 Spacer() // 上下中央揃え用
                             }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    }
                    .padding(.top, DesignSystem.Spacing.lg)
                    
                    // ミシン目（位置計測）
                    DashedLine()
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .foregroundColor(DesignSystem.Colors.gray3)
                        .frame(height: 1)
                        .anchorPreference(key: TicketDividerAnchorKey.self, value: .bounds) { $0 }
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.top, DesignSystem.Spacing.lg) // 点線の上に余白追加
                    
                    // 下部：アクションボタンエリア
                    VStack(spacing: DesignSystem.Spacing.md) {
                        // シェアボタン（Primary）
                        Button(action: {
                            hapticImpact(.medium)
                            shareUrl(scheduleViewModel.getShareUrl(for: event))
                        }) {
                            Label("招待状を送る", systemImage: "square.and.arrow.up")
                                .font(DesignSystem.Typography.body.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .primaryButtonStyle()
                        .controlSize(DesignSystem.Button.Control.large)
                        
                        // コピーボタン（Secondary）
                        Button(action: {
                            hapticImpact(.light)
                            UIPasteboard.general.string = scheduleViewModel.getWebUrl(for: event)
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                            withAnimation {
                                showingCopyToast = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    showingCopyToast = false
                                }
                            }
                        }) {
                            Label("URLをコピー", systemImage: "doc.on.doc")
                                .font(DesignSystem.Typography.body)
                                .frame(maxWidth: .infinity)
                        }
                        .secondaryButtonStyle()
                        .controlSize(DesignSystem.Button.Control.large)
                        .tint(DesignSystem.Colors.primary)
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.sm)
                }

                .backgroundPreferenceValue(TicketDividerAnchorKey.self) { anchor in
                    GeometryReader { geo in
                        if let anchor = anchor {
                            let dividerY = geo[anchor].midY
                            TicketShape(notchYPosition: dividerY)
                                .fill(DesignSystem.Colors.white)
                                .shadow(
                                    color: DesignSystem.Colors.primary.opacity(0.2),
                                    radius: 20,
                                    x: 0,
                                    y: 10
                                )
                        } else {
                            // フォールバック（アンカー取得前）
                            TicketShape(notchOffset: 0.75)
                                .fill(DesignSystem.Colors.white)
                                .shadow(
                                    color: DesignSystem.Colors.primary.opacity(0.2),
                                    radius: 20,
                                    x: 0,
                                    y: 10
                                )
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.xxl) // カードの左右の余白をさらに増やす
                // アニメーション設定
                .offset(y: showTicketAnimation ? 0 : 200)
                .opacity(showTicketAnimation ? 1 : 0)
                .rotation3DEffect(
                    .degrees(showTicketAnimation ? 0 : 10),
                    axis: (x: 1, y: 0, z: 0)
                )
            }
            Spacer()
            
            // ホームに戻る（Tertiary）
            Button(action: {
                hapticImpact(.medium)
                dismiss()
            }) {
                Text("ホームに戻る")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .padding(.vertical, DesignSystem.Spacing.md)
            }
            .padding(.bottom, DesignSystem.Spacing.lg)
            .opacity(showTicketAnimation ? 1 : 0) // チケット表示後にフェードイン
            .animation(.easeIn(duration: 0.5).delay(0.6), value: showTicketAnimation)
        }
        .padding(.vertical, DesignSystem.Spacing.xl)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {
                showTicketAnimation = true
            }
        }
    }
    
    // チケット用日付フォーマッター
    private func formatDateForTicket(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d(E) H:mm"
        return formatter.string(from: date)
    }
    
    // QRコード生成
    private func generateQRCode(from string: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "H" // アイコンを載せるため誤り訂正レベルを高く設定
        
        guard let qrImage = filter.outputImage else {
            return UIImage(systemName: "xmark.circle") ?? UIImage()
        }
        
        // 1. まずは正確なサイズ（1セル=1ピクセル）の正規化された画像を取得
        let scale = CGAffineTransform(scaleX: 1, y: 1)
        guard let cgImage = context.createCGImage(qrImage.transformed(by: scale), from: qrImage.extent) else {
            return UIImage(systemName: "xmark.circle") ?? UIImage()
        }
        
        // 2. ピクセルデータの読み取り準備
        let width = cgImage.width
        let height = cgImage.height
        let dataSize = width * height * 4
        var rawData = [UInt8](repeating: 0, count: dataSize)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let bitmapContext = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return UIImage(systemName: "xmark.circle") ?? UIImage()
        }
        
        bitmapContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // 3. ドットによる描画（高解像度化）
        let moduleSize: CGFloat = 20.0
        let finalSize = CGSize(width: CGFloat(width) * moduleSize, height: CGFloat(height) * moduleSize)
        
        UIGraphicsBeginImageContextWithOptions(finalSize, false, 0.0)
        guard let drawContext = UIGraphicsGetCurrentContext() else { return UIImage() }
        
        // 背景を白で塗りつぶし
        UIColor.white.setFill()
        drawContext.fill(CGRect(origin: .zero, size: finalSize))
        
        // ドットの色（プライマリーカラー）を設定
        DesignSystem.Colors.uiPrimary.setFill()
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * 4
                let red = rawData[pixelIndex]
                
                if red < 128 {
                    let dotRect = CGRect(
                        x: CGFloat(x) * moduleSize + 1.0,
                        y: CGFloat(y) * moduleSize + 1.0,
                        width: moduleSize - 2.0,
                        height: moduleSize - 2.0
                    )
                    drawContext.fillEllipse(in: dotRect)
                }
            }
        }
        
        let dotQRImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // 4. アイコンの合成
        guard let baseImage = dotQRImage else { return UIImage() }
        
        UIGraphicsBeginImageContextWithOptions(baseImage.size, false, 0.0)
        baseImage.draw(in: CGRect(origin: .zero, size: baseImage.size))
        
        // アプリアイコンまたはシンボルを使用
        let icon: UIImage?
        if let appIcon = UIImage(named: "AppLogo") {
            icon = appIcon
        } else {
            icon = UIImage(systemName: "wineglass.fill")?.withTintColor(DesignSystem.Colors.uiPrimary, renderingMode: .alwaysOriginal)
        }
        
        if let iconImage = icon {
            let iconSize = baseImage.size.width * 0.22
            
            // アスペクト比を維持してサイズ計算
            let aspectRatio = iconImage.size.width / iconImage.size.height
            var drawSize = CGSize(width: iconSize, height: iconSize)
            
            if aspectRatio > 1 {
                drawSize.height = iconSize / aspectRatio
            } else {
                drawSize.width = iconSize * aspectRatio
            }
            
            let iconOrigin = CGPoint(
                x: (baseImage.size.width - drawSize.width) / 2, 
                y: (baseImage.size.height - drawSize.height) / 2
            )
            let iconRect = CGRect(origin: iconOrigin, size: drawSize)
            
            // アイコンの背景（白）- 丸角四角形
            let bgPadding: CGFloat = 8.0
            let bgSize = CGSize(width: drawSize.width + bgPadding * 2, height: drawSize.height + bgPadding * 2)
            let bgOrigin = CGPoint(
                x: (baseImage.size.width - bgSize.width) / 2,
                y: (baseImage.size.height - bgSize.height) / 2
            )
            let bgRect = CGRect(origin: bgOrigin, size: bgSize)
            let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: 12)
            UIColor.white.setFill()
            bgPath.fill()
            
            iconImage.draw(in: iconRect)
        }
        
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return finalImage ?? baseImage
    }
}

// 簡易的なFlowLayout（タグの折り返し表示用）
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        if rows.isEmpty { return .zero }
        
        let width = proposal.width ?? rows.map { $0.width }.max() ?? 0
        let height = rows.last!.maxY
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        
        for row in rows {
            for element in row.elements {
                element.subview.place(
                    at: CGPoint(x: bounds.minX + element.x, y: bounds.minY + row.y),
                    proposal: ProposedViewSize(width: element.width, height: element.height)
                )
            }
        }
    }
    
    struct Row {
        var elements: [Element]
        var y: CGFloat
        var height: CGFloat
        var width: CGFloat { elements.last?.maxX ?? 0 }
        var maxY: CGFloat { y + height }
    }
    
    struct Element {
        var subview: LayoutSubview
        var x: CGFloat
        var width: CGFloat
        var height: CGFloat
        var maxX: CGFloat { x + width }
    }
    
    func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentElements: [Element] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if x + size.width > maxWidth && !currentElements.isEmpty {
                // 次の行へ
                rows.append(Row(elements: currentElements, y: y, height: rowHeight))
                y += rowHeight + spacing
                currentElements = []
                x = 0
                rowHeight = 0
            }
            
            currentElements.append(Element(subview: subview, x: x, width: size.width, height: size.height))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        
        if !currentElements.isEmpty {
            rows.append(Row(elements: currentElements, y: y, height: rowHeight))
        }
        
        return rows
    }
}

// MARK: - Ticket UI Components

struct TicketShape: Shape {
    var cornerRadius: CGFloat = 16
    var notchRadius: CGFloat = 10
    var notchOffset: CGFloat = 0.75 // デフォルト（使用されない場合や初期表示用）
    var notchYPosition: CGFloat? = nil // 絶対座標での位置指定（優先）
    
    var animatableData: CGFloat {
        get { notchYPosition ?? 0 }
        set { notchYPosition = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let w = rect.width
        let h = rect.height
        
        // notchYPosition（絶対座標）があればそれを使用、なければ相対位置を使用
        let notchY: CGFloat
        if let yPos = notchYPosition, yPos > 0 {
            notchY = yPos
        } else {
            notchY = h * notchOffset
        }
        
        // 左上からスタート
        path.move(to: CGPoint(x: 0, y: cornerRadius))
        path.addArc(center: CGPoint(x: cornerRadius, y: cornerRadius), radius: cornerRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        
        // 右上
        path.addLine(to: CGPoint(x: w - cornerRadius, y: 0))
        path.addArc(center: CGPoint(x: w - cornerRadius, y: cornerRadius), radius: cornerRadius, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        
        // 右側のノッチ（半円の切り欠き）
        path.addLine(to: CGPoint(x: w, y: notchY - notchRadius))
        path.addArc(center: CGPoint(x: w, y: notchY), radius: notchRadius, startAngle: .degrees(270), endAngle: .degrees(90), clockwise: true)
        
        // 右下
        path.addLine(to: CGPoint(x: w, y: h - cornerRadius))
        path.addArc(center: CGPoint(x: w - cornerRadius, y: h - cornerRadius), radius: cornerRadius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        
        // 左下
        path.addLine(to: CGPoint(x: cornerRadius, y: h))
        path.addArc(center: CGPoint(x: cornerRadius, y: h - cornerRadius), radius: cornerRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        
        // 左側のノッチ（半円の切り欠き）
        path.addLine(to: CGPoint(x: 0, y: notchY + notchRadius))
        path.addArc(center: CGPoint(x: 0, y: notchY), radius: notchRadius, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: true)
        
        path.closeSubpath()
        return path
    }
}

// 位置計測用キー（Anchor）
struct TicketDividerAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        if let next = nextValue() {
            value = next
        }
    }
}

struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY)) // Y軸の中心に線を引く
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

// ヘッダー用シェイプ（上部の角丸のみ）
struct TicketTopShape: Shape {
    var cornerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: cornerRadius))
        path.addArc(center: CGPoint(x: cornerRadius, y: cornerRadius), radius: cornerRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.addLine(to: CGPoint(x: rect.width - cornerRadius, y: 0))
        path.addArc(center: CGPoint(x: rect.width - cornerRadius, y: cornerRadius), radius: cornerRadius, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}
