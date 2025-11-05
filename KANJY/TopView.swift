import SwiftUI

struct TopView: View {
    @StateObject private var viewModel = PrePlanViewModel()
    @State private var showingPrePlan = false
    @State private var showingDeleteAlert = false
    @State private var planToDelete: Plan? = nil
    @State private var showingCalendarSheet = false
    @State private var showingQuickCreate = false
    
    // テスト用のサンプルイベント
    private var sampleEvent: ScheduleEvent {
        ScheduleEvent(
            id: UUID(),
            title: "サンプル飲み会",
            description: "テスト用のスケジュール調整です",
            candidateDates: [
                Calendar.current.date(from: DateComponents(year: 2024, month: 12, day: 15, hour: 18, minute: 0))!,
                Calendar.current.date(from: DateComponents(year: 2024, month: 12, day: 16, hour: 18, minute: 0))!,
                Calendar.current.date(from: DateComponents(year: 2024, month: 12, day: 17, hour: 18, minute: 0))!
            ],
            responses: [],
            createdBy: "テストユーザー",
            createdAt: Date()
        )
    }
    
    private var filteredPlans: [Plan] {
        viewModel.savedPlans.sorted(by: { $0.date > $1.date })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    dashboardCard
                }
                .padding(.top, 16)
                .padding(.bottom, 32)
                .padding(.horizontal, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .sheet(isPresented: $showingPrePlan, onDismiss: {
                if !viewModel.editingPlanName.isEmpty {
                    print("シートが閉じられる際に自動保存を実行: \(viewModel.editingPlanName)")
                    viewModel.savePlan(
                        name: viewModel.editingPlanName.isEmpty ? "無題の飲み会" : viewModel.editingPlanName,
                        date: viewModel.editingPlanDate ?? Date()
                    )
                }
            }) {
                NavigationStack {
                    PrePlanView(
                        viewModel: viewModel,
                        planName: viewModel.editingPlanName.isEmpty ? "" : viewModel.editingPlanName,
                        planDate: viewModel.editingPlanDate,
                        onFinish: {
                            showingPrePlan = false
                        }
                    )
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .alert("飲み会の削除", isPresented: $showingDeleteAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {
                    if let plan = planToDelete {
                        viewModel.deletePlan(id: plan.id)
                    }
                }
            } message: {
                Text("この飲み会を削除してもよろしいですか？")
            }
            .sheet(isPresented: $showingCalendarSheet) {
                CalendarSheetView(viewModel: viewModel)
            }
            .navigationDestination(isPresented: $showingQuickCreate) {
                QuickCreateView(
                    availableEmojis: viewModel.partyEmojis,
                    defaultEmoji: viewModel.selectedEmoji,
                    onCancel: {
                        showingQuickCreate = false
                    },
                    onSave: { name, date, emoji in
                        viewModel.quickCreatePlan(name: name, date: date, emoji: emoji)
                        showingQuickCreate = false
                    }
                )
            }
        }
    }
}

// MARK: - Subviews

private extension TopView {
    var headerSection: some View {
        HStack(spacing: 12) {
            Text("今後のイベント")
                .font(.largeTitle.bold())
                .foregroundColor(.primary)

            Spacer()

            Button {
                showingQuickCreate = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("イベントを作成")
        }
    }

    var dashboardCard: some View {
        materialCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("保存したイベント")
                            .font(.headline)
                            .foregroundColor(.primary)
                        if !filteredPlans.isEmpty {
                            Text("\(filteredPlans.count)件 登録済み")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        showingCalendarSheet = true
                    } label: {
                        Label("カレンダー", systemImage: "calendar")
                            .labelStyle(.iconOnly)
                            .frame(width: 36, height: 36)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                }

                if filteredPlans.isEmpty {
                    EmptyStateView {
                        showingQuickCreate = true
                    }
                } else {
                    VStack(spacing: 12) {
                        ForEach(filteredPlans) { plan in
                            PlanListCell(
                                plan: plan,
                                viewModel: viewModel,
                                onTap: {
                                    viewModel.loadPlan(plan)
                                    showingPrePlan = true
                                },
                                onDelete: {
                                    planToDelete = plan
                                    showingDeleteAlert = true
                                }
                            )
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    func materialCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.black.opacity(0.04))
                    )
            )
    }
}

// 空状態表示をシンプルに案内
struct EmptyStateView: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 44))
                .foregroundColor(.accentColor)

            Text("今後のイベントなし")
                .font(.headline)
                .foregroundColor(.primary)

            Text("あなたが主催または参加するイベントがここに表示されます。今すぐ作成して予定を共有しましょう。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Button(action: onCreate) {
                Text("イベントを作成")
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 36)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

extension TopView {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
}

// サブビュー: プランリストのセル
private struct PlanListCell: View {
    let plan: Plan
    let viewModel: PrePlanViewModel
    let onTap: () -> Void
    let onDelete: () -> Void

    // 集金ステータスを計算
    private var collectionStatus: (isComplete: Bool, count: Int, total: Int) {
        let collectedCount = plan.participants.filter { $0.hasCollected }.count
        let totalCount = plan.participants.count
        return (collectedCount == totalCount && totalCount > 0, collectedCount, totalCount)
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // 絵文字表示
                    Text(plan.emoji ?? "🍻")
                        .font(.system(size: 32))
                        .frame(width: 52, height: 52)
                        .background(
                            Circle()
                                .fill(Color(.systemGray5))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(plan.name)
                                .font(.headline)
                                .foregroundColor(.primary)

                            // ステータスバッジ
                            if plan.totalAmount.isEmpty || plan.participants.isEmpty {
                                Text("下書き")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.15)))
                            } else if collectionStatus.isComplete {
                                Text("集金済み")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.green.opacity(0.15)))
                            } else {
                                Text("未集金")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.blue.opacity(0.15)))
                            }

                            Spacer()
                            Text(viewModel.formatDate(plan.date))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            // 参加者数と集金ステータスを表示
                            if !plan.participants.isEmpty && (collectionStatus.count > 0 || collectionStatus.total > 0) {
                                Text("参加者: \(plan.participants.count)人 (\(collectionStatus.count)/\(collectionStatus.total))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("参加者: \(plan.participants.count)人")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("¥\(viewModel.formatAmount(plan.totalAmount))")
                                .font(.subheadline)
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .foregroundColor(.red)
        }
    }
}

private struct QuickCreateView: View {
    @Environment(\.dismiss) private var dismiss
    let availableEmojis: [String]
    let defaultEmoji: String
    let onCancel: () -> Void
    let onSave: (String, Date, String?) -> Void

    @State private var title: String = ""
    @State private var eventDate: Date = Date()
    @State private var selectedEmoji: String
    @State private var showError: Bool = false
    @State private var showingEmojiPicker: Bool = false

    init(availableEmojis: [String], defaultEmoji: String, onCancel: @escaping () -> Void, onSave: @escaping (String, Date, String?) -> Void) {
        self.availableEmojis = availableEmojis
        self.defaultEmoji = defaultEmoji
        self.onCancel = onCancel
        self.onSave = onSave
        _selectedEmoji = State(initialValue: defaultEmoji.isEmpty ? (availableEmojis.first ?? "🍻") : defaultEmoji)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            Text(selectedEmoji)
                                .font(.system(size: 44))
                                .frame(width: 72, height: 72)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                            TextField("イベントタイトル", text: $title)
                                .font(.system(size: 28, weight: .semibold))
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        if showError {
                            Text("タイトルを入力してください")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("開催日")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        DatePicker("日時を選択", selection: $eventDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("テーマ絵文字")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button {
                            showingEmojiPicker = true
                        } label: {
                            HStack {
                                Text("選択中: \(selectedEmoji)")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 20)
            }

            VStack(spacing: 12) {
                Button(action: save) {
                    Text("保存")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button("キャンセル", role: .cancel) {
                    onCancel()
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(Color(.secondarySystemGroupedBackground))
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle("イベント作成")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEmojiPicker) {
            EmojiPickerSheetView(selectedEmoji: $selectedEmoji)
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            withAnimation { showError = true }
            return
        }
        showError = false
        onSave(trimmed, eventDate, selectedEmoji)
        dismiss()
    }
}

// MARK: - 絵文字ピッカーシート

struct EmojiPickerSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedEmoji: String
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // ランダム絵文字ボタン
                    Button(action: {
                        let emojis = ["🍻", "🍺", "🥂", "🍷", "🍸", "🍹", "🍾", "🥃", "🍴", "🍖", "🍗", "🍣", "🍕", "🍔", "🥩", "🍙", "🤮", "🤢", "🥴", "🤪", "😵‍💫", "💸", "🎊"]
                        selectedEmoji = emojis.randomElement() ?? "🍻"
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "dice")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                            Text("ランダムな絵文字を使用")
                                .foregroundColor(.blue)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("ランダム")
                }
                
                // 絵文字キーボードからの入力セクション
                Section {
                    TextField("タップして絵文字を入力", text: $selectedEmoji)
                        .font(.system(size: 36))
                        .multilineTextAlignment(.center)
                        .keyboardType(.default)
                        .submitLabel(.done)
                        .onChange(of: selectedEmoji) { _, newValue in
                            if newValue.count > 1 {
                                if let firstChar = newValue.first {
                                    selectedEmoji = String(firstChar)
                                }
                            }
                        }
                        .onSubmit {
                            if !selectedEmoji.isEmpty {
                                dismiss()
                            }
                        }
                        .padding(.vertical, 8)
                } header: {
                    Text("絵文字キーボードから入力")
                } footer: {
                    Text("キーボードの🌐または😀ボタンをタップして絵文字キーボードに切り替えてください")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    QuickCreateEmojiGridRow(emojis: ["🍻", "🍺", "🥂", "🍷"], selectedEmoji: $selectedEmoji, dismiss: dismiss)
                    QuickCreateEmojiGridRow(emojis: ["🍸", "🍹", "🍾", "🥃"], selectedEmoji: $selectedEmoji, dismiss: dismiss)
                } header: {
                    Text("飲み物")
                }
                
                Section {
                    QuickCreateEmojiGridRow(emojis: ["🍴", "🍖", "🍗", "🍣"], selectedEmoji: $selectedEmoji, dismiss: dismiss)
                    QuickCreateEmojiGridRow(emojis: ["🍕", "🍔", "🍙", "🍱"], selectedEmoji: $selectedEmoji, dismiss: dismiss)
                } header: {
                    Text("食べ物")
                }
                
                Section {
                    QuickCreateEmojiGridRow(emojis: ["🤮", "🤢", "🥴", "🤪"], selectedEmoji: $selectedEmoji, dismiss: dismiss)
                    QuickCreateEmojiGridRow(emojis: ["😵‍💫", "💸", "💰", "💯"], selectedEmoji: $selectedEmoji, dismiss: dismiss)
                    QuickCreateEmojiGridRow(emojis: ["😂", "😆", "😅", "😬"], selectedEmoji: $selectedEmoji, dismiss: dismiss)
                    QuickCreateEmojiGridRow(emojis: ["😇", "😍", "😎", "😤"], selectedEmoji: $selectedEmoji, dismiss: dismiss)
                    QuickCreateEmojiGridRow(emojis: ["😳", "🤭", "😈", "🙈"], selectedEmoji: $selectedEmoji, dismiss: dismiss)
                    QuickCreateEmojiGridRow(emojis: ["💀", "🤡", "🐒", "🦛"], selectedEmoji: $selectedEmoji, dismiss: dismiss)
                    QuickCreateEmojiGridRow(emojis: ["😹", "😵", "🥳", "😶‍🌫️"], selectedEmoji: $selectedEmoji, dismiss: dismiss)
                } header: {
                    Text("エモーション")
                }
                
                Section {
                    QuickCreateEmojiGridRow(emojis: ["🎉", "🎊", "✨", "🎵"], selectedEmoji: $selectedEmoji, dismiss: dismiss)
                    QuickCreateEmojiGridRow(emojis: ["🎤", "🕺", "💃", "👯‍♂️"], selectedEmoji: $selectedEmoji, dismiss: dismiss)
                } header: {
                    Text("パーティー")
                }
            }
            .navigationTitle("絵文字を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

struct QuickCreateEmojiGridRow: View {
    let emojis: [String]
    @Binding var selectedEmoji: String
    let dismiss: DismissAction
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(emojis, id: \.self) { emoji in
                Button(action: {
                    selectedEmoji = emoji
                    dismiss()
                }) {
                    Text(emoji)
                        .font(.system(size: 30))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

#Preview {
    TopView()
}
